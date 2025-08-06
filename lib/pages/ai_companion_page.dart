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
  bool _isLoading = false;

  final List<String> _fixedPrompts = ['幫助我回憶', '提醒我今天要做的事'];

  @override
  void initState() {
    super.initState();
    _loadPreviousMessages();
  }

Future<void> _sendMessage(String input) async {
  if (input.isEmpty) return;

  setState(() {
    _messages.add({'role': 'user', 'text': input});
    _isLoading = true;
  });
  _controller.clear();
  await _scrollToBottom();

  // 🔍 提取最近 3 則 user 訊息當作上下文
  final history = _messages
      .where((m) => m['role'] == 'user')
      .map((m) => m['text']!)
      .toList();
  final last3 = history.length > 3 ? history.sublist(history.length - 3) : history;
  final recentContext = [...last3, input].join('\n');

  final reply = await _service.processUserMessage(recentContext);
  if (reply != null) {
    setState(() {
      _messages.add({'role': 'ai', 'text': reply});
    });

    // ✅ 若 AI 回覆中含 [播放回憶錄]，才撥放記憶音檔
    if (reply.contains('[播放回憶錄]')) {
      await _service.playMemoryAudioIfMatch(recentContext);
    }

    await _service.remindIfUpcomingTask();
    await _service.speak(reply.replaceAll('[播放回憶錄]', ''));
    await _service.saveToFirestore(input, reply);
  }

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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.lightBlue[100] : const Color(0xFFDFF5E1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message['text'] ?? '',
          style: const TextStyle(color: Colors.black),
        ),
      ),
    );
  }

  List<Widget> _buildPromptButtonsRow() {
      final lastUserMessages = _messages.where((m) => m['role'] == 'user').map((m) => m['text']!).toList();
  final buttons = <Widget>[];

  for (var fixed in _fixedPrompts) {
    buttons.add(Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _buildPromptButton(fixed),
    ));
  }

  // 🧠 只在已有 AI 回覆後才產生推薦話題
  final aiMessages = _messages.where((m) => m['role'] == 'ai').toList();
  if (aiMessages.isNotEmpty && lastUserMessages.length >= 3) {
    String dynamicSuggestion = '你還記得那次的事嗎？';
    final last = lastUserMessages.last;
    if (last.contains('家人')) {
      dynamicSuggestion = '聊聊家人';
    } else if (last.contains('旅行')) {
      dynamicSuggestion = '說說旅行的事';
    }

    // 避免與固定提示重複
    if (!_fixedPrompts.contains(dynamicSuggestion)) {
      buttons.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _buildPromptButton(dynamicSuggestion),
      ));
    }
  }

  return buttons;
}  

  Widget _buildPromptButton(String text) {
    final isPrimary = text == '提醒我今天要做的事';
    return ElevatedButton(
      onPressed: () => _sendMessage(text),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: isPrimary ? const Color(0xFFE3F2FD) : Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
            color: isPrimary ? Colors.blueAccent : Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('AI 陪伴'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _buildMessageBubble(_messages[index]),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildPromptButtonsRow()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      hintText: '輸入訊息...',
                      counterText: '',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(_controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('送出'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
