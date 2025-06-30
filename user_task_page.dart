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

  Future<void> _listen(Function(String task, String? startTime, String? endTime, String? date, String? type) onResult) async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) async {
          try {
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              _speech.stop();
              setState(() => _isListening = false);


              final parsed = await _parseGeminiAI(result.recognizedWords);

              if (parsed != null) {
                debugPrint("✅ Gemini 分析成功：$parsed");

                final now = DateTime.now();
                final parsedDateStr = parsed['date'];
                final parsedStartStr = parsed['start'];
                if (parsedDateStr != null && parsedStartStr != null) {
                  try {
                    final parsedDate = DateFormat('yyyy-MM-dd').parse(parsedDateStr);
                    final parsedTime = DateFormat('HH:mm').parse(parsedStartStr);
                    final combined = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);

                    if (combined.isBefore(now)) {
                      final nextDay = parsedDate.add(const Duration(days: 1));
                      parsed['date'] = DateFormat('yyyy-MM-dd').format(nextDay);
                      debugPrint("🕒 時間已過，自動調整為隔天：${parsed['date']}");
                    }
                  } catch (e) {
                    debugPrint("⚠️ 時間修正失敗：$e");
                  }
                }
                
                onResult(
                  parsed['task'] ?? '',
                  parsed['start'],
                  parsed['end'],
                  parsed['date'],
                  parsed['type'],
                );
              } else {
                debugPrint("❌ Gemini 回傳為 null");
              }
            }
          } catch (e) {
            debugPrint("⚠️ 語音處理錯誤：$e");
            setState(() => _isListening = false);
          }
        });
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<Map<String, String>?> _parseGeminiAI(String input) async {
    final today = DateFormat('yyyy-MM-dd').format(selectedDate);
    final prompt = """
今天是 $today，請從這句話中分析出任務內容與時間，輸出 JSON 格式如下：
{
  "task": "吃藥",
  "start": "14:00",
  "end": "14:30",
  "date": "2025-07-01",
  "type": "醫療"
}

請根據以下規則判斷任務類型 type：
- 若語句中提到吃藥、服藥、藥、看醫生，type 請設為 "醫療"
- 若語句中提到運動、健身、慢跑、散步、伸展，type 請設為 "運動"
- 若語句中提到吃飯、喝水、喝飲料、吃午餐、吃早餐、吃晚餐，type 請設為 "飲食"
- 若語句中沒有明確類型，type 請設為 "提醒"
語句：「$input」
請直接給我 JSON 回應。
""";

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyDlBNZE4HcGwkQTJOUwXuN2i2xw67Egf_U",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "contents": [
          {"parts": [{"text": prompt}]}
        ]
      }),
    );

    if (response.statusCode == 200) {
      try {
        final raw = json.decode(response.body);
        final text = raw['candidates'][0]['content']['parts'][0]['text'];


        final cleanJson = _extractJsonFromText(text);
        final decoded = json.decode(cleanJson);

        final safeMap = <String, String>{};
        decoded.forEach((key, value) {
          if (value != null) {
            safeMap[key] = value.toString();
          }
        });

        return safeMap;
      } catch (e) {
        debugPrint("❌ Gemini 解析失敗：$e");
      }
    } else {
      debugPrint("❌ Gemini API 錯誤：${response.statusCode}");
    }

    return null;
  }


  String _extractJsonFromText(String text) {
    final regex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = regex.firstMatch(text);
    return match != null ? match.group(1)!.trim() : text.trim();
  }

  Future<void> _addTask() async {
    Map<String, String>? aiResult;

    // 預先建立對話框，避免 context 跨 async
    final dialog = TaskDialog(
      listenFunction: _listen,
      initialData: aiResult,
    );

    // 使用 builder: (dialogContext) => dialog 解掉 warning
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => dialog,
    );

    if (!mounted) return;

    if (result != null && result['task']!.isNotEmpty) {
      String start = result['start'] ?? '';
      String end = result['end'] ?? '';

      if (start.isEmpty && end.isNotEmpty) {
        final endTime = DateFormat("HH:mm").parse(end);
        start = DateFormat("HH:mm").format(endTime.subtract(const Duration(minutes: 30)));
      } else if (end.isEmpty && start.isNotEmpty) {
        final startTime = DateFormat("HH:mm").parse(start);
        end = DateFormat("HH:mm").format(startTime.add(const Duration(minutes: 30)));
      }

      final dateKey = result['date'] ?? DateFormat('yyyy-MM-dd').format(selectedDate);
      final type = result['type'] ?? '提醒'; // 如果沒傳回 type，預設為「提醒」
      setState(() {
        taskMap.putIfAbsent(dateKey, () => []);
        taskMap[dateKey]!.add({'task': result['task']!, 'time': start, 'end': end, 'type': type});
        taskMap[dateKey]!.sort((a, b) => a['time']!.compareTo(b['time']!));
      });
    }
  }
  void _deleteTask(int index) {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    setState(() => taskMap[key]!.removeAt(index));
  }

  void _pickDateWithCalendar(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }


  void _jumpToToday() {
    setState(() => selectedDate = DateTime.now());
  }

  Color _getColorByType(String? type) {
    switch (type) {
      case '醫療':
        return Colors.teal.shade100;
      case '運動':
        return Colors.orange.shade100;
      case '提醒':
        return Colors.yellow.shade100;
      case '飲食':
        return Colors.pink.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Icon _getIconByType(String? type) {
    switch (type) {
      case '醫療':
        return const Icon(Icons.medication, color: Colors.teal);
      case '運動':
        return const Icon(Icons.fitness_center, color: Colors.orange);
      case '提醒':
        return const Icon(Icons.alarm, color: Colors.amber);
      case '飲食':
        return const Icon(Icons.restaurant, color: Colors.pink);
      default:
        return const Icon(Icons.task, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final tasks = taskMap[key] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.black87),
                  onPressed: () => _pickDateWithCalendar(context),
                ),
                const Text(
                  '語音任務清單',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton(
                  onPressed: _jumpToToday,
                  child: const Text("今日", style: TextStyle(color: Colors.blueGrey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildDateSelector(),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 24),
                itemCount: 24,
                itemBuilder: (context, hour) {
                  final paddedHour = hour.toString().padLeft(2, '0');
                  final hourStr = "$paddedHour:00";
                  final taskForHour = tasks
                      .where((t) => t['time']?.startsWith(paddedHour) ?? false)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hourStr,
                          style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        if (taskForHour.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('— 無任務 —', style: TextStyle(color: Colors.grey)),
                          ),
                        ...taskForHour.map((t) => Card(
                          color: _getColorByType(t['type']),
                          elevation: 3,
                          margin: const EdgeInsets.only(top: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => flutterTts.speak("${t['task']}，從 ${t['time']} 到 ${t['end']}"),
                            leading: _getIconByType(t['type']),
                            title: Text(
                              t['task'] ?? '',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            subtitle: Text(
                              '${t['time']} ~ ${t['end']}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteTask(tasks.indexOf(t)),
                            ),
                          ),
                        )),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _addTask,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDateSelector() {
    final weekday = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final dayStr = DateFormat('dd').format(selectedDate);
    final monthStr = DateFormat('MM').format(selectedDate);
    final weekStr = weekday[selectedDate.weekday % 7];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$monthStr 月', style: const TextStyle(fontSize: 22, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(dayStr, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 4),
                Text(weekStr, style: const TextStyle(fontSize: 22, color: Colors.black87)),
              ],
            ),
          ),
          Positioned(
            left: 10,
            child: Column(
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
                  onPressed: () => setState(() => selectedDate = selectedDate.subtract(const Duration(days: 1))),
                ),
                const Text('上', style: TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ),
          Positioned(
            right: 10,
            child: Column(
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black87),
                  onPressed: () => setState(() => selectedDate = selectedDate.add(const Duration(days: 1))),
                ),
                const Text('下', style: TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }


}

class TaskDialog extends StatefulWidget {
  final Future<void> Function(Function(String, String?, String?, String?, String?)) listenFunction;
  final Map<String, String>? initialData;

  const TaskDialog({
    required this.listenFunction,
    this.initialData,
    super.key,
  });

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final TextEditingController _controller = TextEditingController();
  String? startTime;
  String? endTime;
  String? taskType;
  DateTime taskDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _controller.text = data['task'] ?? '';
      startTime = data['start'];
      endTime = data['end'];
      taskType = data['type'];
      if (data['date'] != null && data['date']!.isNotEmpty) {
        try {
          taskDate = DateFormat('yyyy-MM-dd').parse(data['date']!);
        } catch (_) {}
      }
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final selected = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final formatted = DateFormat('HH:mm').format(selected);
      setState(() {
        if (isStart) {
          startTime = formatted;
        } else {
          endTime = formatted;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: taskDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => taskDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增任務'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: '任務內容'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _pickTime(true),
                  child: Text(startTime != null ? '開始: $startTime' : '選擇開始時間'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => _pickTime(false),
                  child: Text(endTime != null ? '結束: $endTime' : '選擇結束時間'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _pickDate,
                child: Text(DateFormat('yyyy-MM-dd').format(taskDate)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.mic),
          onPressed: () async {
            await widget.listenFunction((task, start, end, date, type) async {
              String? finalStart = start?.trim();
              String? finalEnd = end?.trim();

              // 自動補結束時間
              if ((finalEnd == null || finalEnd.isEmpty) && finalStart != null && finalStart.isNotEmpty) {
                try {
                  final startDt = DateFormat("HH:mm").parse(finalStart);
                  finalEnd = DateFormat("HH:mm").format(startDt.add(const Duration(minutes: 30)));
                } catch (e) {
                  debugPrint('⚠️ 時間解析失敗: $e');
                  finalStart = null;
                  finalEnd = null;
                }
              }

              // 若無 start → 不進行填寫，避免錯誤
              if (finalStart == null || finalStart.isEmpty) {
                await FlutterTts().speak("任務內容不完整，請再說一次");
                return;
              }

              await FlutterTts().speak("已幫你新增 $task，從 $finalStart 到 $finalEnd");

              setState(() {
                _controller.text = task;
                startTime = finalStart;
                endTime = finalEnd;
                taskType = type;
                if (date != null && date.isNotEmpty) {
                  try {
                    taskDate = DateFormat('yyyy-MM-dd').parse(date);
                  } catch (_) {}
                }
              });
            });
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'task': _controller.text,
              'start': startTime ?? '',
              'end': endTime ?? '',
              'date': DateFormat('yyyy-MM-dd').format(taskDate),
              'type': taskType ?? '提醒',
            });
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}

