import 'package:flutter/material.dart';
import '../memoirs/memory_page.dart';
import 'user_task_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memory/services/notification_service.dart';
import 'package:memory/services/location_uploader.dart'; // ✅ 加入這行

class MainMenuPage extends StatefulWidget {
  final String userRole;

  const MainMenuPage({super.key, this.userRole = '被照顧者'});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  @override
  void initState() {
    super.initState();
    LocationUploader().start(); // ✅ 啟動位置上傳
  }

  @override
  void dispose() {
    LocationUploader().stop(); // ✅ 停止監聽位置
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFE0F2F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildMenuCard(
                      context,
                      icon: Icons.calendar_today,
                      label: '行事曆',
                      color: const Color(0xFF4FC3F7),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserTaskPage())),
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.photo_album,
                      label: '回憶錄',
                      color: const Color(0xFFBA68C8),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryPage())),
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.person,
                      label: '個人檔案',
                      color: const Color(0xFF7986CB ),
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.chat_bubble_outline,
                      label: 'AI陪伴',
                      color: const Color(0xFF4DD0E1),
                      onTap: () => Navigator.pushNamed(context, '/ai'),
                    ),
                    const SizedBox(height: 20),
                    _buildGradientButton(
                      context,
                      text: '10 秒後提醒',
                      onPressed: () async {
                        // 立刻一則，確認通知權限/頻道 OK
                        await NotificationService.showNow(
                          id: 999,
                          title: '✅ 測試通知',
                          body: '立刻跳出的通知',
                        );

                        // 10 秒後：保底排程（先 exact，必要時自動補 AlarmClock）
                        await NotificationService.scheduleWithFallback(
                          id: 1,
                          title: '吃藥提醒',
                          body: 'Sensei 該吃藥囉！',
                          when: DateTime.now().add(const Duration(seconds: 180)),
                        );

                        // 如要引導開啟精準鬧鐘授權（可放在「通知異常」按鈕上）
                        // await NotificationService.openExactAlarmSettings();
                      },
                    )

                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? '使用者';
          final avatarUrl = data['avatarUrl'];

          return Row(
            children: [
              Image.asset('assets/images/memory_icon.png', height: 55), // LOGO 小一點更協調
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '您好，$name',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                  onBackgroundImageError: (e, s) {
                    debugPrint('頭像載入失敗: $e');
                  },
                ),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100, // 微降高度
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.15).toInt()),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildGradientButton(BuildContext context,
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 3,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
