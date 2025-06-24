import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
   final TextEditingController _usernameController = TextEditingController();
   final TextEditingController _passwordController = TextEditingController();

   void _login() {
     // 模擬帳號驗證
     if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
       Navigator.pushReplacementNamed(context, '/role');
     } else {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('請輸入帳號與密碼')),
       );
     }
   }

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(title: Text('登入')),
       body: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Column(
             children: [
               TextField(
                 controller: _usernameController,
                 decoration: const InputDecoration(labelText: '帳號'),
               ),
               TextField(
                 controller: _passwordController,
                 obscureText: true,
                 decoration: const InputDecoration(labelText: '密碼'),
               ),
               const SizedBox(height: 20.0),
               ElevatedButton(onPressed: _login, child: const Text('登入'))
             ],
           ),
       ),
     );
   }
}