import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BindUserPage extends StatefulWidget {
  const BindUserPage({super.key});

  @override
  State<BindUserPage> createState() => _BindUserPageState();
}

class _BindUserPageState extends State<BindUserPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _hasBoundUser = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfHasBoundUser();
  }

  Future<void> _checkIfHasBoundUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(currentUser.uid)
          .get();

    final data = doc.data();
    if (data != null && data['boundUsers'] != null && (data['boundUsers'] as List).isNotEmpty) {
      setState(() => _hasBoundUser = true);
    }
  }

  Future<void> _bindUser() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('identityCode', isEqualTo: code)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到該識別碼')),
      );
      return;
    }

    // 將此 user 的 uid 加入照顧者的 boundUsers 陣列
    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(currentUser.uid)
        .set({
      'boundUsers': FieldValue.arrayUnion([snapshot.docs.first.id])
    }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/selectUser');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('綁定被照顧者'),
        backgroundColor: Colors.teal, // 主色
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '請輸入被照顧者識別碼以綁定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '識別碼',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal.shade600),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              onPressed: _isLoading ? null : _bindUser,
              label: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('綁定對象'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            if (_hasBoundUser) const SizedBox(height: 32),
            if (_hasBoundUser)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/selectUser');
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回選擇對象'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  side: BorderSide(color: Colors.teal.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }


}