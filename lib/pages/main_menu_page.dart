import 'package:flutter/material.dart';
import '../memoirs/memory_page.dart';
import 'user_task_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memory/services/notification_service.dart';
import 'package:memory/services/location_uploader.dart';
import 'package:memory/services/mood_service.dart';            // ✅ 新增
import 'package:memory/pages/mood_checkin_sheet.dart';       // ✅ 新增

// 可選：若要語音提示，打開下面這行並在 _maybeAskMood() 說話
// import 'package:flutter_tts/flutter_tts.dart';

class MainMenuPage extends StatefulWidget {
  final String userRole;
  const MainMenuPage({super.key, this.userRole = '被照顧者'});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _askedToday = false;
  // final flutterTts = FlutterTts(); // 可選：若要語音提示

  @override
  void initState() {
    super.initState();
    LocationUploader().start(); // ✅ 啟動位置上傳
    // 等第一幀 build 完成後再檢查，避免 context 尚未就緒
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskMood());
  }

  @override
  void dispose() {
    LocationUploader().stop(); // ✅ 停止監聽位置
    super.dispose();
  }

  Future<void> _maybeAskMood() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final moodService = MoodService(user.uid);
    final already = await moodService.hasCheckedInToday();
    if (!already && !_askedToday) {
      _askedToday = true;

      // 可選：語音提示
      // await flutterTts.speak("今天的心情是？請選擇：喜、怒、哀、樂");

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.transparent,
        builder: (_) => MoodCheckinSheet(
          // ✅ 這裡接「心情 + 可選的 note」
          onSubmit: (mood, note) async {
            await moodService.saveMood(mood, note: note);
            if (!mounted) return;

            if (!context.mounted) return;
            Navigator.pop(context); // 先關掉底部面板

            // （可選）小小的提示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已記錄今天的心情')),
            );

            // ✅ 存完再問要不要聊聊
            _askToChat(mood, note);
          },
        ),
      );
    }
  }

  void _goToAIWithMood(String mood, [String? note]) {
    final prompt = _promptForMood(mood, note);
    Navigator.pushNamed(context, '/ai', arguments: {
      'initialPrompt': prompt,
      'fromMoodCheckin': true,
      'mood': mood,
      'note': note,
    });
  }


  // 小工具：顯示表情
  static const Map<String, String> _moodEmoji = {
    '喜': '😊',
    '怒': '😠',
    '哀': '😢',
    '樂': '😄',
  };

  Future<void> _askToChat(String mood, String? note) async {
    const deepBlue = Color(0xFF0D47A1);
    const brandBlue = Color(0xFF5B8EFF);
    const brandGreen = Color(0xFF49E3D4);

    final emoji = _moodEmoji[mood] ?? '';
    final hasNote = note != null && note.trim().isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 漸層標頭
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [brandBlue, brandGreen],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: const Text(
                    '需要聊聊嗎？',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),

                // 內容
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('你今天的心情：$mood $emoji',
                          style: const TextStyle(fontSize: 18, color: deepBlue, fontWeight: FontWeight.w700)),
                      if (hasNote) ...[
                        const SizedBox(height: 10),
                        const Text('發生了什麼：',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: deepBlue)),
                        const SizedBox(height: 6),
                        Text(note, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // 底部按鈕列
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      // 左側：次要按鈕
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: deepBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('不用，謝謝',
                              style: TextStyle(fontSize: 16, color: deepBlue, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 右側：主按鈕（漸層）
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [brandBlue, brandGreen],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: const SizedBox(
                              height: 48,
                              child: Center(
                                child: Text('好，現在聊',
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      _goToAIWithMood(mood, note);
    }
  }



  String _promptForMood(String mood, [String? note]) {
    final extra = (note == null || note.trim().isEmpty) ? '' : '（補充：$note）';
    switch (mood) {
      case '怒':
        return '我今天有些生氣（怒）$extra。請先幫我釐清觸發點，再用三步驟：1)命名情緒、2)找需求、3)提出一個可行的小行動。語氣溫柔簡短。';
      case '哀':
        return '我今天比較悲傷（哀）$extra。請用同理的語氣，先讓我描述發生什麼，再提供兩個能在10分鐘內完成的自我照顧建議。';
      case '喜':
        return '我今天很開心（喜）$extra！請幫我把好事具體化：發生了什麼、我做了什麼、可以感謝誰？最後提醒我用一句話記錄今天。';
      case '樂':
      default:
        return '我今天心情愉悅（樂）$extra。請跟我聊聊今天最放鬆的時刻，並提供一個能維持好心情的小習慣。';
    }
  }


  Future<void> _openMoodTester() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未登入，無法測試心情打卡')),
        );
      }
      return;
    }

    final moodService = MoodService(user.uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoodCheckinSheet(
        onSubmit: (mood, note) async {
          await moodService.saveMood(mood, note: note); // 一樣寫入今天的紀錄
          if (!mounted) return;
          if (context.mounted) Navigator.pop(context);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('（測試）已記錄今天的心情')),
            );
          }

          // 跟正式流程一樣：先問要不要聊聊
          _askToChat(mood, note);
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFE0F2F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildMenuCard(
                      context,
                      icon: Icons.calendar_today,
                      label: '行事曆',
                      color: const Color(0xFF4FC3F7),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserTaskPage()),
                      ),
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.photo_album,
                      label: '回憶錄',
                      color: const Color(0xFFBA68C8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MemoryPage()),
                      ),
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.person,
                      label: '個人檔案',
                      color: const Color(0xFF7986CB),
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.chat_bubble_outline,
                      label: 'AI陪伴',
                      color: const Color(0xFF4DD0E1),
                      onTap: () => Navigator.pushNamed(context, '/ai'),
                    ),
                    const SizedBox(height: 20),
                    _buildGradientButton(
                      context,
                      text: '10 秒後提醒',
                      onPressed: () async {
                        // 立刻一則，確認通知權限/頻道 OK
                        await NotificationService.showNow(
                          id: 999,
                          title: '✅ 測試通知',
                          body: '立刻跳出的通知',
                        );

                        // 10 秒後：保底排程（先 exact，必要時自動補 AlarmClock）
                        await NotificationService.scheduleWithFallback(
                          id: 1,
                          title: '吃藥提醒',
                          body: 'Sensei 該吃藥囉！',
                          when: DateTime.now().add(const Duration(seconds: 180)),
                        );

                        // 如要引導開啟精準鬧鐘授權（可放在「通知異常」按鈕上）
                        // await NotificationService.openExactAlarmSettings();
                      },
                    ),
                    _buildGradientButton(
                      context,
                      text: '測試：打開心情打卡',
                      onPressed: _openMoodTester,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? '使用者';
          final avatarUrl = data['avatarUrl'];

          return Row(
            children: [
              Image.asset('assets/images/memory_icon.png', height: 55),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '您好，$name',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/default_avatar.png')
                  as ImageProvider,
                  onBackgroundImageError: (e, s) {
                    debugPrint('頭像載入失敗: $e');
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.15).toInt()),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton(
      BuildContext context, {
        required String text,
        required VoidCallback onPressed,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 3,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

