import 'package:flutter/material.dart';
import 'package:memory/memoirs/memory_page.dart';
import '../pages/user_task_page.dart';
import 'task_statistics_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'caregiver_session.dart';  // ✅ 使用全域 Session

class CaregiverHomePage extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const CaregiverHomePage({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    final routeData = ModalRoute.of(context)?.settings.arguments;

    // ✅ 1. 如果 arguments 有傳進來 → 更新 Session
    if (routeData != null && routeData is Map<String, dynamic>) {
      if (routeData['selectedCareReceiverUid'] != null) {
        CaregiverSession.selectedCareReceiverUid = routeData['selectedCareReceiverUid'];
      }
      if (routeData['selectedCareReceiverName'] != null) {
        CaregiverSession.selectedCareReceiverName = routeData['selectedCareReceiverName'];
      }
      if (routeData['selectedCareReceiverIdentityCode'] != null) {
        CaregiverSession.selectedCareReceiverIdentityCode = routeData['selectedCareReceiverIdentityCode'];
      }
    }

    // ✅ 2. 如果 userData 也有（第一次登入進來時用） → 更新 Session
    if (userData != null) {
      if (userData!['uid'] != null) {
        CaregiverSession.selectedCareReceiverUid = userData!['uid'];
      }
      if (userData!['name'] != null) {
        CaregiverSession.selectedCareReceiverName = userData!['name'];
      }
      if (userData!['identityCode'] != null) {
        CaregiverSession.selectedCareReceiverIdentityCode = userData!['identityCode'];
      }
    }

    // ✅ 3. 從 Session 讀取目前查看對象
    final String name = CaregiverSession.selectedCareReceiverName ?? '未命名';
    final String identityCode = CaregiverSession.selectedCareReceiverIdentityCode ?? '無代碼';

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
              // ✅ 切換時清掉 Session
              CaregiverSession.selectedCareReceiverUid = null;
              CaregiverSession.selectedCareReceiverName = null;
              CaregiverSession.selectedCareReceiverIdentityCode = null;

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

            // ✅ 查看行事曆
            _buildMenuCard(
              context,
              icon: Icons.calendar_today,
              label: '查看任務行事曆',
              color: Colors.teal,
              onTap: () {
                debugPrint('目前查看對象代碼: ${CaregiverSession.selectedCareReceiverIdentityCode}');
                final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                final caregiverName = '照顧者';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserTaskPage(
                      targetUid: CaregiverSession.selectedCareReceiverUid!, // ✅ 直接用 Session
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

            // ✅ 查看回憶錄
            _buildMenuCard(
              context,
              icon: Icons.photo_library,
              label: '查看回憶錄',
              color: Colors.deepPurple,
              onTap: () {
                final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                final caregiverName = '照顧者';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemoryPage(
                      targetUid: CaregiverSession.selectedCareReceiverUid!,
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

            // ✅ 查看任務完成率
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
                      targetUid: CaregiverSession.selectedCareReceiverUid!,
                      targetName: CaregiverSession.selectedCareReceiverName ?? '未命名',
                    ),
                  ),
                );
              },
            ),

            // ✅ 個人檔案
            _buildMenuCard(
              context,
              icon: Icons.person,
              label: '個人檔案',
              color: Colors.indigo,
              onTap: () {
                Navigator.pushReplacementNamed(context, '/careProfile');
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.location_on,
              label: '查看定位地圖',
              color: Colors.green,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/map',
                  arguments: {
                    'selectedCareReceiverUid': CaregiverSession.selectedCareReceiverUid,
                    'selectedCareReceiverName': CaregiverSession.selectedCareReceiverName,
                    'selectedCareReceiverIdentityCode': CaregiverSession.selectedCareReceiverIdentityCode,
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ 被照顧者資訊卡片
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

  /// ✅ 功能選單按鈕
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
