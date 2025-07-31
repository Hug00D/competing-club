import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'caregivers/role_selection_page.dart';
import 'pages/user_task_page.dart';
import 'caregivers/caregiver_home_page.dart';
import 'pages/main_menu_page.dart';
import 'memoirs/memory_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'caregivers/bind_user_page.dart';
import 'caregivers/select_user_page.dart';
import 'caregivers/caregiver_profile_page.dart';
import 'pages/ai_companion_page.dart';
import 'firebase_options.dart'; // 用 FlutterFire CLI 產生
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.requestExactAlarmPermission();
  await Firebase.initializeApp(

    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        '/memory': (context) => const MemoryPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/bindUser': (context) => const BindUserPage(),
        '/selectUser': (context) => const SelectUserPage(),
        '/ai': (context) => const AICompanionPage(),
        '/careProfile': (context) => CaregiverProfilePage(),
      },
    );
  }
}