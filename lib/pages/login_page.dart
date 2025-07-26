import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _login() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();
    final email = '$account@test.com';

    if (account.isEmpty || password.isEmpty) {
      _showMessage('請輸入帳號與密碼');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()?['role'] != null) {
          final role = doc['role'];
          if (!mounted) return;
          if (role == 'caregiver') {
            Navigator.pushReplacementNamed(context, '/selectUser');
          } else if (role == 'user') {
            Navigator.pushReplacementNamed(context, '/mainMenu');
          }
        } else {
          // 若沒有 role 資料，轉到角色選擇頁
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/role');
        }
      }
    } on FirebaseAuthException catch (e) {
      _showMessage('登入失敗: ${e.message}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E8FF), Color(0xFFE9D5FF)], // 淺紫 → 更淺紫
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // 🟣 預留 Logo 位置
                  Container(
                    height: 100,
                    width: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.lock_outline, size: 60, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '歡迎回來',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '請登入以繼續使用',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  // 🟣 登入卡片（淺色）
                  Card(
                    color: Colors.white, // ✅ 讓底變成白色
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _accountController,
                            style: const TextStyle(color: Colors.black87), // ✅ 文字顏色更深
                            decoration: InputDecoration(
                              labelText: '帳號',
                              labelStyle: const TextStyle(color: Colors.black87), // ✅ Label 也加深
                              prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
                              filled: true,
                              fillColor: Colors.grey[300], // ✅ 原本的 100 → 300，背景更深
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.black87), // ✅ 文字顏色更深
                            decoration: InputDecoration(
                              labelText: '密碼',
                              labelStyle: const TextStyle(color: Colors.black87), // ✅ Label 也加深
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                              filled: true,
                              fillColor: Colors.grey[300], // ✅ 背景變深灰
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),

                          // ✅ 登入按鈕（顏色和 Logo 一致）
                          _isLoading
                              ? const CircularProgressIndicator()
                              : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '登入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              '還沒有帳號？前往註冊',
                              style: TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


}
