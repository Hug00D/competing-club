import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final FlutterTts flutterTts = FlutterTts();
  String? _selectedRole; // 'caregiver' or 'user'

  Future<void> _handleSelection(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await flutterTts.speak("尚未登入，無法選擇角色");
      return;
    }

    if (_selectedRole == role) {
      final uid = user.uid;
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

      final dataToSave = {
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (role == 'user') {
        final uniqueId = const Uuid().v4();
        dataToSave['identityCode'] = uniqueId;
      }

      await userDoc.set(dataToSave, SetOptions(merge: true));
      await flutterTts.speak("角色已確認並儲存");

      if (!mounted) return; // ✅ 確保 context 還有效
      final route = role == 'caregiver' ? '/caregiver' : '/mainMenu';
      Navigator.pushReplacementNamed(context, route);
    } else {
      setState(() {
        _selectedRole = role;
      });
      final roleText = role == 'caregiver' ? '照顧者' : '被照顧者';
      await flutterTts.speak("你已選擇 $roleText，請再點擊一次確認選擇");
    }
  }


  Color transparentColor(Color color, int alpha) {
    return Color.fromARGB(
      alpha,
      (color.r * 255.0).round() & 0xff,
      (color.g * 255.0).round() & 0xff,
      (color.b * 255.0).round() & 0xff,
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () => _handleSelection(role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? transparentColor(color, 51) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: transparentColor(color, 25),
              radius: 32,
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('請選擇您的身分'),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRoleCard(
              role: 'caregiver',
              icon: Icons.medical_services,
              title: '我是照顧者',
              subtitle: '我負責協助照顧他人',
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            _buildRoleCard(
              role: 'user',
              icon: Icons.person,
              title: '我是被照顧者',
              subtitle: '我需要協助與提醒',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
