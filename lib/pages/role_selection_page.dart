import 'package:flutter/material.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('身分選擇')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/caregiver'),
                child: const Text('我是照顧者')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/user'),
                child: const Text('我是被照顧者')
            ),
          ],
        ),
      ),
    );
  }
}