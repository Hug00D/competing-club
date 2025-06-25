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
  final Map<String, List<String>> taskMap = {};
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
            await _parseWitAi(result.recognizedWords);
          }
        });
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _parseWitAi(String input) async {
    const token = "XBXOUHMJNTS52AG6OWBLV6GQVAT2DPHD";
    final response = await http.get(
      Uri.parse("https://api.wit.ai/message?v=20230601&q=${Uri.encodeComponent(input)}"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final entities = data['entities'] ?? {};
      debugPrint(jsonEncode(entities));

      String? task = data['text'];
      String key = DateFormat('yyyy-MM-dd').format(selectedDate);
      const datetimeKey = r'wit$datetime:datetime';

      if (entities.containsKey(datetimeKey)) {
        final datetimeEntity = entities[datetimeKey][0];
        final rawVal = datetimeEntity['value'] ?? datetimeEntity['from']?['value'];
        if (rawVal is String && rawVal.length >= 10) {
          key = rawVal.substring(0, 10); // ✅ 忽略時區，取字面日期
        }
      }

      if (task != null && task.isNotEmpty) {
        setState(() {
          taskMap.putIfAbsent(key, () => []);
          taskMap[key]!.add(task);
        });

        await _speak("已幫你新增「$task」，在 $key。");
      } else {
        await _speak("抱歉，我沒聽清楚要做什麼事。");
      }
    } else {
      debugPrint("Wit.ai 回傳錯誤: ${response.body}");
      await _speak("語音辨識發生錯誤。");
    }
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
    final result = await showDialog<String>(
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
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('新增'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final key = DateFormat('yyyy-MM-dd').format(selectedDate);
      setState(() {
        taskMap.putIfAbsent(key, () => []);
        taskMap[key]!.add(result);
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
          return Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Text(tasks[index]),
              onTap: () => _speak(tasks[index]),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteTask(index),
              ),
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
