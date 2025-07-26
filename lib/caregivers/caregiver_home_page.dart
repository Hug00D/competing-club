import 'package:flutter/material.dart';
import 'package:memory/memoirs/memory_page.dart';
import '../pages/user_task_page.dart';
import 'task_statistics_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaregiverHomePage extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const CaregiverHomePage({super.key, this.userData});


  @override
  Widget build(BuildContext context) {
    final routeData = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> data;

    if (userData != null) {
      data = userData!;
    } else if (routeData != null && routeData is Map<String, dynamic>) {
      data = routeData;
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('錯誤')),
        body: const Center(child: Text('找不到使用者資料，請重新登入')),
      );
    }
    final String name = data['name'] ?? '未命名';
    final String identityCode = data['identityCode'] ?? '無代碼';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('照顧者後台', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account),
            tooltip: '切換查看對象',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/selectUser');
            },
          ),
        ],
        elevation: 3,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(name, identityCode),
            const SizedBox(height: 24),
            const Text('功能選單',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.calendar_today,
              label: '查看任務行事曆',
              color: Colors.teal,
              onTap: () {
                final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                final caregiverName = '照顧者'; // 或使用 Firebase 資料裡的名稱
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserTaskPage(
                      targetUid: data['uid'], // 被照顧者 UID
                    ),
                    settings: RouteSettings(
                      arguments: {
                        'fromCaregiver': true,
                        'caregiverUid': caregiverUid,
                        'caregiverName': caregiverName,
                      },
                    ),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.photo_library,
              label: '查看回憶錄',
              color: Colors.deepPurple,
              onTap: () {
                final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                final caregiverName = '照顧者'; // 或使用 Firebase 資料裡的名稱
                debugPrint('✅ data: $data');
                debugPrint('✅ data uid: ${data['uid']}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemoryPage(
                      targetUid: data['uid'], // 被照顧者 UID
                    ),
                    settings: RouteSettings(
                      arguments: {
                        'fromCaregiver': true,
                        'caregiverUid': caregiverUid,
                        'caregiverName': caregiverName,
                      },
                    ),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.bar_chart,
              label: '查看任務完成率',
              color: Colors.deepOrangeAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskStatisticsPage(
                      targetUid: data['uid'],
                      targetName: data['name'],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String name, String identityCode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('當前查看對象：',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          Text('姓名：$name', style: const TextStyle(fontSize: 16, color: Colors.black)),
          Text('識別碼：$identityCode',
              style: TextStyle(fontSize: 16, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(38),
                radius: 22,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
