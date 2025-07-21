import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectUserPage extends StatefulWidget {
  const SelectUserPage({super.key});

  @override
  State<SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<SelectUserPage> {
  List<Map<String, dynamic>> _linkedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinkedUsers();
  }

  Future<void> _loadLinkedUsers() async {
    try {
      // 取得當前照顧者 UID
      final caregiver = FirebaseAuth.instance.currentUser;
      if (caregiver == null) return;
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(caregiver.uid)
          .get();

      final boundUserUids = caregiverDoc.data()?['boundUsers'] as List<dynamic>? ?? [];

      if (boundUserUids.isEmpty) {
        setState(() {
          _linkedUsers = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> users = [];

      for (final uid in boundUserUids) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = userDoc.data();
        if (data != null) {
          users.add({
            'name': data['name'] ?? '未命名',
            'identityCode': data['identityCode'] ?? '',
            'uid': uid,
          });
        }
      }

      setState(() {
        _linkedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('讀取錯誤: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('讀取失敗，請稍後再試')),
      );
    }
  }




  void _selectUser(Map<String, dynamic> userData) {
    // TODO: 儲存選擇對象狀態，可寫入本地或 Firebase
    Navigator.pushNamed(context, '/caregiver', arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('選擇查看對象')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _linkedUsers.length,
        itemBuilder: (context, index) {
          final user = _linkedUsers[index];
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text(user['name']),
            subtitle: Text('識別碼：${user['identityCode']}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _selectUser(user),
          );
        },
      ),
    );
  }
}
