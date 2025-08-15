import 'package:flutter/material.dart';
import 'package:memory/services/ai_companion_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AICompanionPage extends StatefulWidget {
  const AICompanionPage({super.key});

  @override
  State<AICompanionPage> createState() => _AICompanionPageState();
}

class _AICompanionPageState extends State<AICompanionPage> {
  final AICompanionService _service = AICompanionService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final List<String> _fixedPrompts = ['幫助我回憶', '提醒我今天要做的事'];

  bool _isLoading = false;
  bool _bootstrapped = false; // ✅ 避免重複觸發開場訊息

  @override
  void initState() {
    super.initState();
    _loadPreviousMessages();
  }

  // ✅ 讀取路由參數：若是從心情打卡過來，主動發送「關懷開場」
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final fromMood = args?['fromMoodCheckin'] == true;
    final mood = args?['mood'] as String?;
    final note = args?['note'] as String?;
    final initialPrompt = args?['initialPrompt'] as String?;

    if (fromMood && (mood != null || (note != null && note.trim().isNotEmpty))) {
      _sendCaringStarterFromMood(mood: mood, note: note);
    } else if (initialPrompt != null && initialPrompt.trim().isNotEmpty) {
      // 如果不是從心情來、但外部仍有 initialPrompt，就照舊發送
      _sendMessage(initialPrompt);
    }
  }

  /// ✅ 給 AI 的關懷開場（不顯示使用者泡泡，只顯示 AI 關心）
  Future<void> _sendCaringStarterFromMood({String? mood, String? note}) async {
    final starter = _buildCaringStarterPrompt(mood, note);

    if (!mounted) return;
    setState(() => _isLoading = true);

    final reply = await _service.processUserMessage(starter);
    if (!mounted) return;

    if (reply != null) {
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });
      await _service.remindIfUpcomingTask();
      await _service.speak(reply.trim());
      await _service.saveToFirestore('（系統）心情打卡開場：$mood｜${note ?? ''}', reply);
    }

    setState(() => _isLoading = false);
    await _scrollToBottom();
  }

  String _buildCaringStarterPrompt(String? mood, String? note) {
    final moodPart = (mood == null || mood.isEmpty) ? '' : '使用者今天標記的心情是「$mood」。';
    final notePart = (note == null || note.trim().isEmpty)
        ? '請先用溫柔、簡短的語氣表達理解，並詢問「發生了什麼讓你有這樣的感受呢？」'
        : '他補充了一句：「$note」。請用溫柔、簡短的語氣先同理，並基於這句話，追問一個開放式問題，例如「願意多說一點細節嗎？」';
    const guide =
        '回覆規則：1) 先同理 1 句；2) 問 1 個開放式問題；3) 提供 1 個10分鐘內能做到的小建議（如深呼吸、喝水、短暫散步）。用自然中文、句子短。';
    return '$moodPart$notePart\n$guide';
  }

  Future<void> _sendMessage(String input) async {
    if (input.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'user', 'text': input});
      _isLoading = true;
    });
    _controller.clear();
    await _scrollToBottom();

    // 🔍 取最近 3 則 user 對話當作上下文
    final history = _messages.where((m) => m['role'] == 'user').map((m) => m['text']!).toList();
    final last3 = history.length > 3 ? history.sublist(history.length - 3) : history;
    final recentContext = [...last3, input].join('\n');

    final reply = await _service.processUserMessage(recentContext);
    if (reply != null) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });

      // ✅ 解析 [播放回憶] 區塊（若存在）
      if (reply.contains('[播放回憶]')) {
        final regex = RegExp(r'標題:\s*(.+)\s+描述:\s*(.+)\s+音檔:\s*(.+)');
        final match = regex.firstMatch(reply);
        if (match != null) {
          final audioUrl = match.group(3);
          if (audioUrl != null && audioUrl.isNotEmpty) {
            await _service.playMemoryAudioFromUrl(audioUrl);
          } else {
            debugPrint('⚠️ 無效音檔網址');
          }
        } else {
          debugPrint('⚠️ 無法解析播放回憶資訊');
        }
      }

      await _service.remindIfUpcomingTask();
      await _service.speak(reply.replaceAll('[播放回憶]', '').replaceAll('[播放回憶錄]', '').trim());
      await _service.saveToFirestore(input, reply);
    }

    if (!mounted) return;

    setState(() => _isLoading = false);
    await _scrollToBottom();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadPreviousMessages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('ai_companion')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt')
        .get();

    if (!mounted) return;

    setState(() {
      _messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userText = data['userText'];
        final aiResponse = data['aiResponse'];
        if (userText is String && aiResponse is String) {
          _messages.add({'role': 'user', 'text': userText});
          _messages.add({'role': 'ai', 'text': aiResponse});
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 200));
    _scrollToBottom();
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final text = message['text'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image.asset(
                'assets/images/ai_icon.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const SizedBox(width: 36),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFDAECFF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1), // ✅ 修正 withValues
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 18, color: Colors.black87), // ✅ 放大字體
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Widget>> _buildPromptButtonsRow() async {
    final userMessages = _messages.where((m) => m['role'] == 'user').map((m) => m['text']!).toList();
    final aiMessages = _messages.where((m) => m['role'] == 'ai').toList();

    final buttons = _fixedPrompts.map(_buildPromptButton).toList();

    if (userMessages.length >= 5 && userMessages.length % 5 == 0 && aiMessages.isNotEmpty) {
      final last3 = userMessages.sublist(userMessages.length - 3);
      final smart = await _service.generateSmartSuggestion(last3);

      if (smart != null && !_fixedPrompts.contains(smart)) {
        buttons.add(_buildPromptButton(smart));
      }
    }

    return buttons;
  }

  Widget _buildPromptButton(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => _sendMessage(text),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: Colors.blue.shade100),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15)), // ✅ 微放大
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FB),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: screenHeight / 9,
              child: Stack(
                children: [
                  // 左上返回鍵
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.home_rounded, color: Color(0xFF5B8EFF), size: 30),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),

                  // 中間 LOGO + 標題
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/memory_icon.png', width: 60),
                        const SizedBox(height: 4),
                        const Text(
                          'AI 陪伴',
                          style: TextStyle(
                            fontSize: 27, // ✅ 放大
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B8EFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFDFEFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: FutureBuilder<List<Widget>>(
                future: _buildPromptButtonsRow(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: snapshot.data!),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: '輸入訊息...',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                      style: const TextStyle(fontSize: 18), // ✅ 放大
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _sendMessage(_controller.text.trim()),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
