import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/role_selection_page.dart';
import 'pages/user_task_page.dart';
import 'pages/caregiver_home_page.dart';
import 'pages/main_menu_page.dart';
import 'pages/memory_page.dart';


void main() {
  runApp(const MemoryAssistantApp());
}

class MemoryAssistantApp extends StatelessWidget {
  const MemoryAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記憶助理',
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/role': (context) => const RoleSelectionPage(),
        '/user': (context) => const UserTaskPage(),
        '/caregiver': (context) => const CaregiverHomePage(),
        '/mainMenu': (context) => const MainMenuPage(),
        '/memory': (context) => const MemoryPage()
      },
    );
  }
}