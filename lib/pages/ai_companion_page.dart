import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // ✅ DateFormat
import 'package:just_audio/just_audio.dart'; // ✅ 播放回憶錄語音
import 'package:memory/memoirs/memory_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AICompanionPage extends StatefulWidget {
  const AICompanionPage({super.key});

  @override
  State<AICompanionPage> createState() => _AICompanionPageState();
}

class _AICompanionPageState extends State<AICompanionPage> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer(); // ✅ 加入音頻播放器

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousMessages();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ✅ Firestore 讀取舊聊天紀錄
  Future<void> _loadPreviousMessages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ai_companion')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt')
          .get();

      final previousMessages = <Map<String, String>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userText = data['userText'];
        final aiResponse = data['aiResponse'];
        if (userText is String && aiResponse is String) {
          previousMessages.add({'role': 'user', 'text': userText});
          previousMessages.add({'role': 'ai', 'text': aiResponse});
        }
      }

      setState(() {
        _messages.addAll(previousMessages);
      });

      await Future.delayed(const Duration(milliseconds: 300));
      _scrollToBottom();
    } catch (e) {
      debugPrint('⚠️ 讀取對話紀錄失敗：$e');
    }
  }

  // ✅ 讀取今日任務
  Future<List<Map<String, String>>> _fetchTodayTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('date', isEqualTo: todayKey)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'task': (data['task'] ?? '').toString(),
        'time': (data['time'] ?? '').toString(),
        'end': (data['end'] ?? '').toString(),
        'type': (data['type'] ?? '').toString(),
      };
    }).toList();
  }

  // ✅ 傳送訊息 & 處理回應
  Future<void> _sendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty || input.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入 1 到 100 字之間的訊息')),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': input});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    final response = await _callGeminiAPI(input);
    if (response != null) {
      setState(() {
        _messages.add({'role': 'ai', 'text': response});
      });

      // ✅ 播放回憶語音（如果有）
      await _maybePlayMemoryAudio(input);

      // ✅ 提醒任務（如果有 1 小時內的任務）
      await _checkUpcomingTasks();

      // ✅ AI 朗讀
      await _speak(response);

      // ✅ 存 Firestore
      await _saveToFirestore(input, response);
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  // ✅ 自動滾到最新訊息
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

  // ✅ 呼叫 Gemini API
  Future<String?> _callGeminiAPI(String prompt) async {
    const apiKey = 'YOUR_API_KEY';
    const url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final uid = FirebaseAuth.instance.currentUser?.uid;
    String memorySummary = '（尚無回憶紀錄）';
    if (uid != null) {
      final memoryService = MemoryService();
      final memories = await memoryService.fetchMemories(uid);
      memorySummary = memoryService.summarizeMemories(memories);
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''
你是一位溫柔且簡潔的 AI 陪伴者，幫助使用者回憶過去的重要記憶。

⚠️ 規則：
1. 用語簡單、溫暖，不要冗詞或假設「你一定很幸福」。
2. 如果能找到對應回憶，請說「要不要聽聽那段錄音？」。
3. 如果提到時間/藥，請提醒相關任務。

回憶紀錄摘要：
$memorySummary

使用者說：「$prompt」
'''
            }
          ]
        }
      ]
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    } else {
      debugPrint('Gemini 錯誤: ${response.body}');
      return null;
    }
  }

  // ✅ 語音播放（TTS）
  Future<void> _speak(String text) async {
    await _flutterTts.setPitch(1.2);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setLanguage('zh-TW');
    await _flutterTts.speak(text);
  }

  // ✅ 存聊天紀錄到 Firestore
  Future<void> _saveToFirestore(String userText, String aiResponse) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('ai_companion').add({
      'uid': uid,
      'userText': userText,
      'aiResponse': aiResponse,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _maybePlayMemoryAudio(String userInput) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final memoryService = MemoryService();
  final memories = await memoryService.fetchMemories(uid);

  final keywords = userInput.split(RegExp(r'\s+'));
  final match = memories.firstWhere(
    (m) => keywords.any((kw) =>
        (m['title'] ?? '').toString().contains(kw) ||
        (m['description'] ?? '').toString().contains(kw)),
    orElse: () => {},
  );

  final audioUrl = match['audioPath'];
  debugPrint('🎧 Firestore audioPath: $audioUrl');

  if (audioUrl == null || audioUrl.isEmpty) {
    debugPrint('⚠️ 沒有找到回憶語音');
    return;
  }

  try {
    await _flutterTts.stop(); // 停止 TTS
    await _audioPlayer.stop(); // 停止任何正在播的音檔

    if (audioUrl.startsWith('http')) {
      debugPrint('▶️ 播放 HTTP 音訊: $audioUrl');
      await _audioPlayer.setUrl(audioUrl);
    } else if (audioUrl.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(audioUrl);
      final downloadUrl = await ref.getDownloadURL();
      await _audioPlayer.setUrl(downloadUrl);
    } else {
      debugPrint('▶️ 播放本地音檔: $audioUrl');
      await _audioPlayer.setFilePath(audioUrl);
    }

    await _audioPlayer.play();
    debugPrint('✅ 播放開始');
  } catch (e) {
    debugPrint('❌ 回憶語音播放失敗: $e');
  }
}


  // ✅ 檢查 1 小時內的任務並提醒
  Future<void> _checkUpcomingTasks() async {
    final tasks = await _fetchTodayTasks();
    final now = DateTime.now();

    for (final task in tasks) {
      final taskTime = DateFormat('HH:mm').parse(task['time']!);
      final taskDateTime =
          DateTime(now.year, now.month, now.day, taskTime.hour, taskTime.minute);

      if (taskDateTime.isAfter(now) &&
          taskDateTime.difference(now).inMinutes <= 60) {
        await _flutterTts.speak("提醒您，一個小時後有任務：${task['task']}");
        break;
      }
    }
  }

  // ✅ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 陪伴')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['text'] ?? '',
                        style: const TextStyle(color: Colors.black)),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
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
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
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
