import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String _role = '';
  String? _uid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _role = data['role'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('讀取個人資料失敗')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(_uid).set({
      'name': _nameController.text.trim(),
      'role': _role,
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 資料已儲存')),
      );
    }
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _role.isNotEmpty ? _role : null,
      style: const TextStyle(color: Colors.black),
      dropdownColor: Colors.white,
      decoration: const InputDecoration(
        labelText: '身分',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'caregiver', child: Text('照顧者')),
        DropdownMenuItem(value: 'user', child: Text('被照顧者')),
      ],
      onChanged: (value) => setState(() => _role = value!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('個人檔案'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: const AssetImage('assets/images/default_avatar.png'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: '名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _buildRoleDropdown(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('儲存變更', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
