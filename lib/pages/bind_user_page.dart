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
  bool _isLoading = false;

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
      appBar: AppBar(title: const Text('綁定被照顧者')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('請輸入被照顧者識別碼以綁定'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '識別碼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _bindUser,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('綁定對象'),
            ),
          ],
        ),
      ),
    );
  }
}