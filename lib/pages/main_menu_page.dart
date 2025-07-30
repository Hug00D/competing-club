import 'package:flutter/material.dart';
import '../memoirs/memory_page.dart';
import 'user_task_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memory/services/notification_service.dart';

class MainMenuPage extends StatelessWidget {
  final String userRole; // 由 Firebase 抓取傳入

  const MainMenuPage({super.key, this.userRole = '被照顧者'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('安心生活小幫手'),
        centerTitle: true,
        backgroundColor: Colors.black54,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              // 🔄 讀取中
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/images/default_avatar.png'),
                  ),
                );
              }

              // 📦 拿到 Firestore 資料
              final data = snapshot.data!.data() as Map<String, dynamic>?;

              // 🔗 角色顯示
              final name = data?['name'] ?? '';
              final avatarUrl = data?['avatarUrl'];

              return Row(
                children: [
                  // 🔵 角色名稱 (照顧者 / 被照顧者)
                  Text(
                    name ?? '被照顧者',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),

                  // 🖼 頭像按鈕
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.transparent,
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl) // ✅ Firestore 頭像
                            : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            _buildMenuCard(
              context,
              icon: Icons.calendar_today,
              label: '行事曆',
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserTaskPage()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.photo_album,
              label: '回憶錄',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemoryPage()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.person,
              label: '個人檔案',
              color: Colors.indigo,
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              label: 'AI陪伴',
              color: Colors.grey,
              onTap: () {
                Navigator.pushNamed(context, '/ai');
              },
            ),
            ElevatedButton(
              onPressed: () {
                NotificationService.scheduleNotification(
                  id: 1,
                  title: '吃藥提醒',
                  body: '該吃藥囉！',
                  scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
                );
              },
              child: const Text('10 秒後提醒'),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 80,
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 👈 垂直置中
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
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
}
