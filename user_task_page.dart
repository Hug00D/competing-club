// Dart Flutter: Gemini 1.5 Flash 語音任務解析版本
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';

class UserTaskPage extends StatefulWidget {
  const UserTaskPage({super.key});

  @override
  State<UserTaskPage> createState() => _UserTaskPageState();
}

class _UserTaskPageState extends State<UserTaskPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts flutterTts = FlutterTts();

  final Map<String, List<Map<String, String>>> taskMap = {};
  DateTime selectedDate = DateTime.now();
  bool _isListening = false;

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) async {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
            await _parseGeminiAI(result.recognizedWords);
          }
        });
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _parseGeminiAI(String input) async {
    const apiKey = "AIzaSyAHwbl6rDrK243UPkF0ENiOPF9b_A_TB1w";
    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prompt = """
今天是 $today，請從這句話中分析出任務內容與時間，輸出 JSON 格式如下：
{
  "task": "去洗澡",
  "date": "2025-06-27",
  "time": "21:00"
}

語句：「$input」
請直接給我 JSON 回應。
""";

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      try {
        final raw = jsonDecode(response.body);
        final text = raw['candidates'][0]['content']['parts'][0]['text'];
        final cleanJson = _extractJsonFromText(text);
        final parsed = jsonDecode(cleanJson);

        final task = parsed['task'] ?? input;
        final dateStr = parsed['date'];
        final timeStr = parsed['time'] ?? "";

        if (task != null && dateStr != null) {
          final key = dateStr;
          setState(() {
            taskMap.putIfAbsent(key, () => []);
            taskMap[key]!.add({
              'task': task,
              'time': timeStr,
            });
            taskMap[key]!.sort((a, b) => (a['time'] ?? '').compareTo(b['time'] ?? ''));
          });
          await _speak("已幫你新增「$task」，在 $key。");
        } else {
          await _speak("我沒能解析出任務內容。");
        }
      } catch (e) {
        debugPrint("解析 Gemini 回傳失敗：$e");
        await _speak("AI 回應解析失敗。");
      }
    } else {
      debugPrint("Gemini 回傳錯誤: ${response.body}");
      await _speak("AI 回應發生錯誤。");
    }
  }

  String _extractJsonFromText(String text) {
    final regex = RegExp(r'```json\s*([\s\S]*?)\s*```', multiLine: true);
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return text.trim();
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("zh-TW");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  void _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _addTask() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新增任務'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '輸入任務內容'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'task': controller.text,
                'time': '',
              }),
              child: const Text('新增'),
            ),
          ],
        );
      },
    );

    if (result != null && result['task']!.isNotEmpty) {
      final key = DateFormat('yyyy-MM-dd').format(selectedDate);
      setState(() {
        taskMap.putIfAbsent(key, () => []);
        taskMap[key]!.add(result);
        taskMap[key]!.sort((a, b) => (a['time'] ?? '').compareTo(b['time'] ?? ''));
      });
    }
  }

  void _deleteTask(int index) {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    setState(() {
      taskMap[key]!.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final tasks = taskMap[key] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('任務 (${DateFormat('yyyy/MM/dd').format(selectedDate)})'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('尚無任務'))
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final taskObj = tasks[index];
          final taskText = taskObj['task'] ?? '';
          final timeText = taskObj['time'] ?? '';

          return Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(taskText)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timeText.isNotEmpty)
                        Text(timeText, style: const TextStyle(color: Colors.grey)),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTask(index),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () => _speak(taskText),
            ),
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1))))
            FloatingActionButton(
              heroTag: 'mic',
              onPressed: _listen,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none),
            ),
          const SizedBox(width: 12),
          if (!selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1))))
            FloatingActionButton(
              heroTag: 'add',
              onPressed: _addTask,
              child: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}
