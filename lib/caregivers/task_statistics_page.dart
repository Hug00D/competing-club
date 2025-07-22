import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TaskStatisticsPage extends StatefulWidget {
  final String targetUid;
  final String targetName;

  const TaskStatisticsPage({
    super.key,
    required this.targetUid,
    required this.targetName,
  });

  @override
  State<TaskStatisticsPage> createState() => _TaskStatisticsPageState();
}

class _TaskStatisticsPageState extends State<TaskStatisticsPage> {
  double _completionRate = 0.0;
  List<Map<String, dynamic>> _incompleteTasks = [];
  bool _isLoading = true;
  String _selectedType = '全部';

  final List<String> _types = ['全部', '提醒', '飲食', '運動', '醫療', '生活'];

  @override
  void initState() {
    super.initState();
    _loadTaskStatistics();
  }

  Future<void> _loadTaskStatistics() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final currentTimeStr = DateFormat('HH:mm').format(now);

    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.targetUid)
        .collection('tasks')
        .get();

    int total = 0;
    int completed = 0;
    List<Map<String, dynamic>> incomplete = [];

    for (final doc in tasksSnapshot.docs) {
      final data = doc.data();
      final date = data['date'] ?? '';
      final time = data['time'] ?? '00:00';
      final isCompleted = data['completed'] == true;
      final type = data['type'] ?? '提醒';

      final isPastTask = date.compareTo(todayKey) < 0 ||
          (date == todayKey && time.compareTo(currentTimeStr) <= 0);

      final matchType = _selectedType == '全部' || type == _selectedType;

      if (isPastTask && matchType) {
        total++;
        if (isCompleted) {
          completed++;
        } else {
          incomplete.add({
            'task': data['task'] ?? '未命名任務',
            'date': date,
            'time': time,
            'type': type,
          });
        }
      }
    }

    setState(() {
      _completionRate = total > 0 ? (completed / total) : 0.0;
      _incompleteTasks = incomplete;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.targetName} 的任務統計')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedType,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                  _loadTaskStatistics();
                }
              },
              items: _types
                  .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '✅ 完成率：${(_completionRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '❌ 未完成任務',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _incompleteTasks.isEmpty
                  ? const Text('太棒了，目前沒有未完成的任務！')
                  : ListView.builder(
                itemCount: _incompleteTasks.length,
                itemBuilder: (context, index) {
                  final task = _incompleteTasks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(task['task']),
                      subtitle:
                      Text('${task['date']} ${task['time']}'),
                      leading: const Icon(Icons.warning,
                          color: Colors.redAccent),
                      trailing: Text(task['type']),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
