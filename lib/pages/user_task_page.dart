import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class UserTaskPage extends StatefulWidget {
  const UserTaskPage({super.key});

  @override
  State<UserTaskPage> createState() => _UserTaskPageState();
}

class _UserTaskPageState extends State<UserTaskPage> {
  final FlutterTts flutterTts = FlutterTts();
  final Map<String, List<String>> taskMap = {};
  DateTime selectedDate = DateTime.now();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _spokenText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('狀態: $val'),
        onError: (val) => print('錯誤: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'zh_TW',
          onResult: (val) {
            setState(() {
              _spokenText = val.recognizedWords;
            });

            if (val.finalResult && _spokenText.isNotEmpty) {
              final key = DateFormat('yyyy-MM-dd').format(selectedDate);
              setState(() {
                taskMap.putIfAbsent(key, () => []);
                taskMap[key]!.add(_spokenText);
                _spokenText = '';
                _isListening = false;
                _speech.stop();
              });
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
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
    if (selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('過去日期無法新增任務')),
      );
      return;
    }
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
