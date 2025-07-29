import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'monthly_overview_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memory/caregivers/caregiver_session.dart';


Future<void> uploadTasksToFirebase(Map<String, List<Map<String, String>>> taskMap, String uid) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }


  final tasksRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('tasks');

  // 清除舊資料（選擇性）
  final snapshot = await tasksRef.get();
  for (final doc in snapshot.docs) {
    await doc.reference.delete();
  }

  for (final dateKey in taskMap.keys) {
    final tasks = taskMap[dateKey]!;
    for (final task in tasks) {
      final docRef = await tasksRef.add({
        'task': task['task'],
        'time': task['time'],
        'end': task['end'],
        'type': task['type'],
        'completed': task['completed'] == 'true',
        'date': dateKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 把 docId 存進本地 taskMap（可選擇要不要更新本地）
      task['docId'] = docRef.id;
    }
  }
}



class UserTaskPage extends StatefulWidget {
  final String? targetUid;
  const UserTaskPage({super.key, this.targetUid});

  @override
  State<UserTaskPage> createState() => _UserTaskPageState();
}

class _UserTaskPageState extends State<UserTaskPage> {
  Map<String, List<Map<String, String>>> taskMap = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();
  //final Map<String, List<Map<String, String>>> taskMap = {};
  DateTime selectedDate = DateTime.now();
  bool _isListening = false;

  late final String uid;
  bool fromCaregiver = false;
  String? caregiverUid;
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = widget.targetUid ?? user?.uid ?? '';
    loadTasksFromFirebase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        fromCaregiver = args['fromCaregiver'] == true;
        caregiverUid = args['caregiverUid'];
      }

      _scrollIfToday();
    });
  }

  Future<void> loadTasksFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');

    final snapshot = await tasksRef.get();

    final Map<String, List<Map<String, String>>> loadedTaskMap = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = data['date'] ?? '未知日期';
      loadedTaskMap.putIfAbsent(date, () => []);
      loadedTaskMap[date]!.add({
        'task': data['task'] ?? '',
        'time': data['time'] ?? '',
        'end': data['end'] ?? '',
        'type': data['type'] ?? '提醒',
        'completed': data['completed']?.toString() ?? 'false',
        'docId': doc.id,
      });
    }

    // 填回你的 taskMap 並更新畫面
    setState(() {
      taskMap = loadedTaskMap;
    });

  }

  Future<void> deleteTaskFromFirebase(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final taskRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(docId);

    await taskRef.delete();
  }

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
    - 若語句中提到吃飯、喝水、喝飲料、吃午餐、吃早餐、吃晚餐、吃宵夜，type 請設為 "飲食"
    - 若語句中沒有明確類型，type 請設為 "提醒"
    語句：「$input」
    請直接給我 JSON 回應。
  """;

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyCSiUQBqYBaWgpxHr37RcuKoaiiUOUfQhs",
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

        // 🛠 智能日期修正邏輯
        if (safeMap.containsKey('date') && safeMap.containsKey('start')) {
          final now = DateTime.now();
          final parsedDate = DateTime.tryParse(safeMap['date']!);

          try {
            final parsedTime = DateFormat('HH:mm').parse(safeMap['start']!);
            final combined = DateTime(
              parsedDate!.year,
              parsedDate.month,
              parsedDate.day,
              parsedTime.hour,
              parsedTime.minute,
            );

            if (combined.isBefore(now)) {
              final isUserSpecified = safeMap['date'] != DateFormat('yyyy-MM-dd').format(selectedDate);
              DateTime newDate;

              if (isUserSpecified) {
                // 明確指定日期 → 跳下週
                newDate = parsedDate.add(const Duration(days: 7));
              } else {
                // 沒指定 → 跳明天
                final tomorrow = now.add(const Duration(days: 1));
                newDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
              }

              safeMap['date'] = DateFormat('yyyy-MM-dd').format(newDate);
              debugPrint("🛠 時間已過，自動跳轉日期 → ${safeMap['date']}");
            }
          } catch (_) {
            debugPrint("⚠️ 時間格式解析失敗");
          }
        }

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
      initialDate: selectedDate,
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
        taskMap[dateKey]!.add({'task': result['task']!, 'time': start, 'end': end, 'type': type, 'completed': 'false',});
        taskMap[dateKey]!.sort((a, b) => a['time']!.compareTo(b['time']!));
      });

      await uploadTasksToFirebase(taskMap, uid);
    }
  }
  Future<void> _deleteTask(int index) async {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final task = taskMap[key]![index];

    final docId = task['docId'];
    if (docId != null) {
      await deleteTaskFromFirebase(docId); // ⬅️ 刪 Firebase 上的資料
    }

    setState(() {
      taskMap[key]!.removeAt(index); // ⬅️ 同時從本地移除
    });
  }


  void _jumpToToday() {
    setState(() {
      selectedDate = DateTime.now();
    });

    // 延遲等畫面更新後再捲動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }

  void _scrollIfToday() {
    final now = DateTime.now();
    final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) ==
        DateFormat('yyyy-MM-dd').format(now);

    if (isToday) {
      _scrollToCurrentHour();
    }
  }

  void _scrollToCurrentHour() {
    final now = DateTime.now();
    final currentHour = now.hour;

    const double estimatedHourHeight = 78;
    final offset = estimatedHourHeight * currentHour ;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }


  void _openMonthlyCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyOverviewPage(
          taskMap: taskMap,
          onSelectDate: (DateTime selected) {
            setState(() {
              selectedDate = selected;
            });
          },
        ),
      ),
    );
  }

  void _toggleTaskCompletion(Map<String, String> task, bool isCompleted) async {
    setState(() {
      task['completed'] = isCompleted.toString();
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = widget.targetUid ?? user.uid;
    final docId = task['docId'];
    if (docId == null) return;

    final taskRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(docId);

    await taskRef.update({'completed': isCompleted}); // ← ✅ 這裡是 bool
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

  void _showCustomMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              bottom: 100,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildFloatingMenuButton('主畫面', Icons.home, () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    if (!context.mounted) return; // ✅ 確保 context 還活著

                    Navigator.pop(context);

                    if (fromCaregiver && caregiverUid != null) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/caregiver',
                            (route) => false,
                        arguments: {
                          'uid': caregiverUid,
                          'selectedCareReceiverUid': CaregiverSession.selectedCareReceiverUid,
                          'selectedCareReceiverName': CaregiverSession.selectedCareReceiverName,
                          'selectedCareReceiverIdentityCode': CaregiverSession.selectedCareReceiverIdentityCode,
                        },
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, '/mainMenu');
                    }
                  }),

                  const SizedBox(height: 12),
                  _buildFloatingMenuButton('回憶錄', Icons.photo_album, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/memory');
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingMenuButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    final tasks = taskMap[key] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.black87),
                  onPressed: _openMonthlyCalendar,
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
          const SizedBox(height: 6),

          Stack(
            alignment: Alignment.bottomRight, // 改成右下角
            children: [
              Center(child: _buildDateSelector()),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FloatingActionButton(
                    heroTag: 'addBtn',
                    backgroundColor: Colors.black,
                    onPressed: _addTask,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 24),
                itemCount: 24,
                itemBuilder: (context, hour) {
                  final paddedHour = hour.toString().padLeft(2, '0');
                  final hourStr = "$paddedHour:00";
                  final now = DateTime.now();
                  final selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);
                  final todayString = DateFormat('yyyy-MM-dd').format(now);
                  final isBeforeToday = selectedDate.isBefore(DateTime(now.year, now.month, now.day));
                  final isToday = selectedDateString == todayString;
                  final hourStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour);
                  final hourEnd = hourStart.add(const Duration(hours: 1));
                  final isHourPast = isBeforeToday || (isToday && now.isAfter(hourEnd));

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
                          style: TextStyle(
                            color: isHourPast ? Colors.grey : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (taskForHour.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '— 無任務 —',
                              style: TextStyle(color: isHourPast ? Colors.grey : Colors.black54),
                            ),
                          ),
                        ...taskForHour.map((t) {
                          final now = TimeOfDay.now();
                          final taskTime = TimeOfDay(
                            hour: int.tryParse(t['time']?.split(':')[0] ?? '0') ?? 0,
                            minute: int.tryParse(t['time']?.split(':')[1] ?? '0') ?? 0,
                          );
                          final isPast = taskTime.hour < now.hour || (taskTime.hour == now.hour && taskTime.minute < now.minute);
                          final isCompleted = t['completed'] == 'true';

                          Color titleColor;
                          if (isPast && !isCompleted) {
                            titleColor = Colors.redAccent;
                          } else if (isPast && isCompleted) {
                            titleColor = Colors.green;
                          } else {
                            titleColor = Colors.black87;
                          }

                          return Card(
                            color: _getColorByType(t['type']),
                            elevation: 3,
                            margin: const EdgeInsets.only(top: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () => flutterTts.speak("${t['task']}，從 ${t['time']} 到 ${t['end']}"),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _getIconByType(t['type']),
                                  Checkbox(
                                    value: isCompleted,
                                    onChanged: (value) {
                                      if (value != null) {
                                        _toggleTaskCompletion(t, value);
                                      }
                                    },
                                    side: WidgetStateBorderSide.resolveWith((states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return const BorderSide(color: Colors.green, width: 2);
                                      }
                                      return const BorderSide(color: Colors.black54, width: 2);
                                    }),
                                    fillColor: WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return Colors.blue;
                                      }
                                      return Colors.transparent;
                                    }),
                                    checkColor: Colors.white,
                                  ),

                                ],
                              ),
                              title: Text(
                                t['task'] ?? '',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleColor),
                              ),
                              subtitle: Text('${t['time']} ~ ${t['end']}', style: const TextStyle(color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  final index = tasks.indexOf(t);
                                  await _deleteTask(index);
                                },
                              ),
                            ),
                          );
                        }),
                        if (hour == 23)
                          const SizedBox(height: 50),
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
        heroTag: 'menuBtn',
        backgroundColor: Colors.black,
        onPressed: _showCustomMenu,
        child: const Icon(Icons.menu, color: Colors.white),
      ),
    );
  }

  Widget _buildDateSelector() {
    final weekday = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    final dayStr = DateFormat('dd').format(selectedDate);
    final monthStr = DateFormat('MM').format(selectedDate);
    final weekStr = weekday[selectedDate.weekday % 7];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 245,
            height: 245,
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
  final DateTime initialDate;

  const TaskDialog({
    required this.listenFunction,
    this.initialData,
    super.key,
    required this.initialDate,
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
    taskDate = widget.initialDate;
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
      final selected = DateTime(
          now.year, now.month, now.day, picked.hour, picked.minute);
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
    final List<String> taskTypes = ['提醒', '醫療', '運動', '飲食'];

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '新增任務',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: '任務內容',
                  labelStyle: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickTime(true),
                      child: Text(
                        startTime != null ? '開始: $startTime' : '選擇開始時間',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickTime(false),
                      child: Text(
                        endTime != null ? '結束: $endTime' : '選擇結束時間',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(taskDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '任務分類',
                  labelStyle: TextStyle(fontSize: 16),
                ),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                value: taskType ?? '提醒',
                items: taskTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type, style: const TextStyle(fontSize: 16)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    taskType = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mic, size: 28),
                    onPressed: () async {
                      await widget.listenFunction((task, start, end, date, type) async {
                        String? finalStart = start?.trim();
                        String? finalEnd = end?.trim();

                        if ((finalEnd == null || finalEnd.isEmpty) &&
                            finalStart != null && finalStart.isNotEmpty) {
                          try {
                            final startDt = DateFormat("HH:mm").parse(finalStart);
                            finalEnd = DateFormat("HH:mm").format(startDt.add(const Duration(minutes: 30)));
                          } catch (e) {
                            debugPrint('⚠️ 時間解析失敗: $e');
                            finalStart = null;
                            finalEnd = null;
                          }
                        }

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
                    child: const Text('取消', style: TextStyle(fontSize: 18)),
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
                    child: const Text('新增', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}