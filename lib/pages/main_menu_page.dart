// ================================
// file: pages/main_menu_page.dart
// Uber-style Home overview with 2×2 tools grid + horizontal overview cards
// Keeps your: LocationUploader, Exact Alarm prompt, Mood check-in flow
// Depends on: widgets/home_overview_cards.dart
// Routes used: '/ai', '/profile' and MemoryPage/UserTaskPage as before
// =================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../memoirs/memory_page.dart';
import 'user_task_page.dart';

import 'package:memory/services/notification_service.dart';
import 'package:memory/services/location_uploader.dart';
import 'package:memory/services/mood_service.dart';
import 'package:memory/pages/mood_checkin_sheet.dart';

import '../widgets/home_overview_cards.dart';

class MainMenuPage extends StatefulWidget {
  final String userRole;
  const MainMenuPage({super.key, this.userRole = '被照顧者'});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _askedToday = false;
  bool _askedExactAlarmPrompt = false;

  @override
  void initState() {
    super.initState();
    LocationUploader().start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybePromptExactAlarm();
      await _maybeAskMood();
    });
  }

  @override
  void dispose() {
    LocationUploader().stop();
    super.dispose();
  }

  Future<void> _maybePromptExactAlarm() async {
    if (!mounted) return;
    if (!Platform.isAndroid) return;
    if (_askedExactAlarmPrompt) return;
    _askedExactAlarmPrompt = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ExactAlarmPromptSheet(),
    );
  }

  Future<void> _maybeAskMood() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final moodService = MoodService(user.uid);
    final already = await moodService.hasCheckedInToday();
    if (!already && !_askedToday) {
      _askedToday = true;
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.transparent,
        builder: (_) => MoodCheckinSheet(
          onSubmit: (mood, note) async {
            await moodService.saveMood(mood, note: note);
            if (!mounted) return;
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已記錄今天的心情')),
            );
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
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('你今天的心情：$mood $emoji',
                          style: const TextStyle(
                              fontSize: 18,
                              color: deepBlue,
                              fontWeight: FontWeight.w700)),
                      if (hasNote) ...[
                        const SizedBox(height: 10),
                        const Text('發生了什麼：',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: deepBlue)),
                        const SizedBox(height: 6),
                        Text(note!,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black87)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: deepBlue),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('不用，謝謝',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: deepBlue,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            child: const SizedBox(
                              height: 48,
                              child: Center(
                                child: Text('好，現在聊',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
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
          await moodService.saveMood(mood, note: note);
          if (!mounted) return;
          if (context.mounted) Navigator.pop(context);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('（測試）已記錄今天的心情')),
            );
          }
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
            colors: [Color(0xFFEAF3FF), Color(0xFFE0F7F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildQuickChips(context),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    _buildToolsGrid(context),
                    const SizedBox(height: 12),
                    // Overview Cards (Uber 廣告區 → 速覽)
                    OverviewCards(
                      onOpenAI: () => Navigator.pushNamed(context, '/ai'),
                      onOpenCalendar: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserTaskPage()),
                      ),
                      onOpenMemories: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MemoryPage()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionsBar(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              Image.asset('assets/images/memory_icon.png', height: 48),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '您好，$name',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nextSoonTaskHint(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3D5A80),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _nextSoonTaskHint() {
    // 若要接後端，這裡可查最近的任務時間並格式化。
    // 先給一行友善提示作為空狀態。
    return '祝你有美好的一天～';
  }

  Widget _buildQuickChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _chip(
            icon: Icons.mic_rounded,
            label: '語音輸入',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserTaskPage()),
            ),
          ),
          const SizedBox(width: 10),
          _chip(
            icon: Icons.notifications_active,
            label: '今日提醒',
            onTap: () async {
              await NotificationService.showNow(
                id: 1000,
                title: '今日提醒',
                body: '我會在任務時間提醒你喔',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    final items = [
      _ToolItem(
        icon: Icons.calendar_today,
        color: const Color(0xFF4FC3F7),
        label: '行事曆',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserTaskPage()),
        ),
      ),
      _ToolItem(
        icon: Icons.photo_album,
        color: const Color(0xFFBA68C8),
        label: '回憶錄',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryPage()),
        ),
      ),
      _ToolItem(
        icon: Icons.person,
        color: const Color(0xFF7986CB),
        label: '個人檔案',
        onTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      _ToolItem(
        icon: Icons.chat_bubble_outline,
        color: const Color(0xFF4DD0E1),
        label: 'AI陪伴',
        onTap: () => Navigator.pushNamed(context, '/ai'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ToolCard(item: items[i]),
    );
  }

  Widget _buildQuickActionsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          _quickBtn(
            icon: Icons.add,
            label: '新增任務',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserTaskPage()),
            ),
          ),
          _divider(),
          _quickBtn(
            icon: Icons.today,
            label: '今天',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserTaskPage()),
            ),
          ),
          _divider(),
          _quickBtn(
            icon: Icons.volume_up,
            label: '播放提醒',
            onTap: () async {
              await NotificationService.showNow(
                id: 2000,
                title: '今日提醒播報',
                body: '將為你朗讀接下來的事項',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: const Color(0x1F000000));

  Widget _quickBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: Colors.blue.shade700),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  _ToolItem({required this.icon, required this.color, required this.label, required this.onTap});
}

class _ToolCard extends StatelessWidget {
  final _ToolItem item;
  const _ToolCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withOpacity(.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 36, color: item.color),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            )
          ],
        ),
      ),
    );
  }
}

class _ExactAlarmPromptSheet extends StatelessWidget {
  const _ExactAlarmPromptSheet();

  @override
  Widget build(BuildContext context) {
    const title = '需要允許「精準鬧鐘」';
    const msg = '為了讓背景提醒準時且能在背景產生 AI 回覆並通知你，請在系統中開啟「精準鬧鐘」。';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('之後再說'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await NotificationService.requestNotificationPermission();
                    await NotificationService.openExactAlarmSettings();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('前往設定'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

