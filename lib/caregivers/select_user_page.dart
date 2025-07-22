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
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('選擇查看對象'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/bindUser');
            },
            tooltip: '新增綁定對象',
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _linkedUsers.isEmpty
          ? const Center(
        child: Text(
          '尚未綁定任何對象',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _linkedUsers.length,
        itemBuilder: (context, index) {
          final user = _linkedUsers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(13, 0, 0, 0),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              leading: CircleAvatar(
                backgroundColor: Colors.teal.shade100,
                radius: 24,
                child: const Icon(Icons.person, color: Colors.teal),
              ),
              title: Text(
                user['name'],
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                '識別碼：${user['identityCode']}',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.black54,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  size: 26, color: Colors.teal),
              onTap: () => _selectUser(user),
            ),
          );
        },
      ),
    );
  }

}
