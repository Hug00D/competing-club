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
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/images/default_avatar.png'),
                  ),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final name = data?['name'] ?? '被照顧者';
              final avatarUrl = data?['avatarUrl'];

              return Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
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
                            ? NetworkImage(avatarUrl)
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserTaskPage()));
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.photo_album,
              label: '回憶錄',
              color: Colors.purple,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryPage()));
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
                NotificationService.showTestNotification();
                NotificationService.scheduleExactNotification(
                  id: 1,
                  title: '吃藥提醒',
                  body: 'Sensei 該吃藥囉！',
                  scheduledTime: DateTime.now().add(Duration(seconds: 10)),
                );
                NotificationService.scheduleAlarmClockNotification(
                  id: 2,
                  title: '吃藥提醒',
                  body: 'Sensei 該吃藥囉！',
                  scheduledTime: DateTime.now().add(Duration(seconds: 10)),
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
