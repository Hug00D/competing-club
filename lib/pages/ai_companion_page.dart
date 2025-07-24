import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:memory/memoirs/memory_service.dart';

class AICompanionPage extends StatefulWidget {
  const AICompanionPage({super.key});

  @override
  State<AICompanionPage> createState() => _AICompanionPageState();
}

class _AICompanionPageState extends State<AICompanionPage> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousMessages();
  }

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
      await _speak(response);
      await _saveToFirestore(input, response);
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
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

  Future<String?> _callGeminiAPI(String prompt) async {
    const apiKey = 'AIzaSyCSiUQBqYBaWgpxHr37RcuKoaiiUOUfQhs';
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
  你是一位溫柔且簡潔的 AI 陪伴者，幫助使用者回憶過去的重要記憶。請根據使用者最近的回憶紀錄，協助他們找回具體的人事物。

  語氣要溫暖、簡潔，不要太多冗詞或主觀推論。避免像「你一定很幸福」這類假設。請多給予實際記憶提示，例如：「你提過和兒子一起去台中」、「要不要聽聽那段錄音？」

  使用者的部分回憶紀錄摘要如下：
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



  Future<void> _speak(String text) async {
    await _flutterTts.setPitch(1.2);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setLanguage('zh-TW');
    await _flutterTts.speak(text);
  }

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
                    child: Text(msg['text'] ?? '', style: TextStyle(color: Colors.black),),
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
