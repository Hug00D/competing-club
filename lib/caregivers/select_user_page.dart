import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'caregiver_session.dart';

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
      // 1️⃣ 取得當前照顧者 UID
      final caregiver = FirebaseAuth.instance.currentUser;
      if (caregiver == null) return;

      // 2️⃣ 讀取 caregivers 文件
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(caregiver.uid)
          .get();

      // 3️⃣ 轉換 boundUsers 為 List<Map>
      final boundUsers = (caregiverDoc.data()?['boundUsers'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // 4️⃣ 如果沒有綁定任何被照顧者 → 清空 UI
      if (boundUsers.isEmpty) {
        setState(() {
          _linkedUsers = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> users = [];

      // 5️⃣ 讀取每個被照顧者的詳細資料
      for (final user in boundUsers) {
        final uid = user['uid'] as String;
        final nickname = user['nickname'] as String? ?? '';

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = userDoc.data();

        if (data != null) {
          users.add({
            'name': data['name'] ?? '未命名',
            'identityCode': data['identityCode'] ?? '',
            'uid': uid,
            'nickname': nickname, // ✅ 保留 nickname，UI 可以直接顯示
          });
        }
      }

      // 6️⃣ 更新 UI 狀態
      if (!mounted) return;
      setState(() {
        _linkedUsers = users;  // ⚠️ _linkedUsers 要改成 List<Map<String, dynamic>>
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
                user['nickname'] != null && user['nickname'].toString().isNotEmpty
                    ? '${user['name']}（${user['nickname']}）'
                    : user['name'], // 沒暱稱就只顯示名字
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
              onTap: () {
                CaregiverSession.selectedCareReceiverUid = user['uid'];
                CaregiverSession.selectedCareReceiverName = user['name'];
                CaregiverSession.selectedCareReceiverIdentityCode = user['identityCode'];
                debugPrint(CaregiverSession.selectedCareReceiverIdentityCode);
                _selectUser(user);
              },
            ),
          );
        },
      ),
    );
  }

}
