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

    final String name = CaregiverSession.selectedCareReceiverName ?? '未命名';
    final String identityCode = CaregiverSession.selectedCareReceiverIdentityCode ?? '無代碼';

    return Scaffold(
      // ✅ 背景改為漸層綠
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ AppBar 改為自訂樣式
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '照顧者後台',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.switch_account, color: Color(0xFF2E7D32)),
                      tooltip: '切換查看對象',
                      onPressed: () {
                        Navigator.pushNamed(context, '/selectUser');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(name, identityCode),
                _buildMenuCard(
                  context,
                  icon: Icons.person,
                  label: '個人檔案',
                  color: const Color(0xFF81D4FA),
                  onTap: () {
                    Navigator.pushNamed(context, '/careProfile');
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  '功能選單',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 12),

                // ✅ 功能卡片們（綠為主，藍為輔）
                _buildMenuCard(
                  context,
                  icon: Icons.calendar_today,
                  label: '查看任務行事曆',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                    final caregiverName = '照顧者';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserTaskPage(
                          targetUid: CaregiverSession.selectedCareReceiverUid!,
                        ),
                        settings: RouteSettings(arguments: {
                          'fromCaregiver': true,
                          'caregiverUid': caregiverUid,
                          'caregiverName': caregiverName,
                        }),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.photo_library,
                  label: '查看回憶錄',
                  color: const Color(0xFF64B5F6),
                  onTap: () {
                    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                    final caregiverName = '照顧者';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemoryPage(
                          targetUid: CaregiverSession.selectedCareReceiverUid!,
                        ),
                        settings: RouteSettings(arguments: {
                          'fromCaregiver': true,
                          'caregiverUid': caregiverUid,
                          'caregiverName': caregiverName,
                        }),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.bar_chart,
                  label: '查看任務完成率',
                  color: const Color(0xFF81C784),
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
                _buildMenuCard(
                  context,
                  icon: Icons.location_on,
                  label: '查看定位地圖',
                  color: const Color(0xFF1976D2),
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
              style: const TextStyle(fontSize: 16, color: Colors.black)),
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
