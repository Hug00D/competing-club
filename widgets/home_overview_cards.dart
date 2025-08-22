// ==========================================
// file: widgets/home_overview_cards.dart
// Horizontal scrollable overview cards replacing "Uber banner"
// Safe Firestore reads (try/catch) with graceful fallbacks
// ==========================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OverviewCards extends StatelessWidget {
  final VoidCallback onOpenAI;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenMemories;
  const OverviewCards({
    super.key,
    required this.onOpenAI,
    required this.onOpenCalendar,
    required this.onOpenMemories,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 4),
          AiLatestCard(onOpenAI: onOpenAI),
          const SizedBox(width: 12),
          TodayAgendaCard(onOpenCalendar: onOpenCalendar),
          const SizedBox(width: 12),
          MemorySpotlightCard(onOpenMemories: onOpenMemories),
          const SizedBox(width: 12),
          const WeekStatsCard(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class AiLatestCard extends StatelessWidget {
  final VoidCallback onOpenAI;
  const AiLatestCard({super.key, required this.onOpenAI});

  Future<String?> _fetchLatestSnippet() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('ai_chats')
          .orderBy('createdAt', descending: true)
          .limit(1);
      final snap = await col.get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      // 支援不同欄位命名：text / content / message
      return (data['text'] ?? data['content'] ?? data['message']) as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: 'AI 最新回應', icon: Icons.smart_toy_outlined),
          const SizedBox(height: 8),
          FutureBuilder<String?>(
            future: _fetchLatestSnippet(),
            builder: (context, snap) {
              final text = snap.data;
              final display =
                  (text == null || text.trim().isEmpty)
                      ? '和我聊聊吧，我可以提醒你今天的安排～'
                      : '“${text.trim().replaceAll('\n', ' ')}”';
              return Text(
                display,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, height: 1.4),
              );
            },
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              onPressed: onOpenAI,
              icon: const Icon(Icons.chat),
              label: const Text('繼續對話'),
            ),
          )
        ],
      ),
    );
  }
}

class TodayAgendaCard extends StatelessWidget {
  final VoidCallback onOpenCalendar;
  const TodayAgendaCard({super.key, required this.onOpenCalendar});

  Future<List<Map<String, dynamic>>> _fetchToday() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];
      final today = DateTime.now();
      final yyyyMmDd =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .where('date', isEqualTo: yyyyMmDd)
          .orderBy('time')
          .limit(3)
          .get();
      return qs.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '今日行事曆', icon: Icons.event_note),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchToday(),
            builder: (context, snap) {
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const Text('今天還沒有安排，點右下角快速新增。');
              }
              return Column(
                children: [
                  for (final m in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text((m['time'] ?? '--:--').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          Expanded(child: Text((m['task'] ?? '').toString())),
                          const SizedBox(width: 8),
                          _TypePill(type: (m['type'] ?? '').toString()),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              onPressed: onOpenCalendar,
              icon: const Icon(Icons.chevron_right),
              label: const Text('查看全部'),
            ),
          )
        ],
      ),
    );
  }
}

class MemorySpotlightCard extends StatelessWidget {
  final VoidCallback onOpenMemories;
  const MemorySpotlightCard({super.key, required this.onOpenMemories});

  Future<Map<String, dynamic>?> _fetchOne() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('memories')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) return null;
      return qs.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '回憶錄焦點', icon: Icons.photo_library_outlined),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchOne(),
            builder: (context, snap) {
              final data = snap.data;
              final title = (data?['title'] ?? '新增第一則回憶').toString();
              final desc = (data?['description'] ?? '用照片與語音記下重要時刻').toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              onPressed: onOpenMemories,
              icon: const Icon(Icons.open_in_new),
              label: const Text('開啟回憶錄'),
            ),
          )
        ],
      ),
    );
  }
}

class WeekStatsCard extends StatelessWidget {
  const WeekStatsCard({super.key});

  Future<Map<String, dynamic>> _fetchStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return {'rate': 0, 'pending': 0};
      // 簡化：實務可依據 date 範圍拉資料，這裡先顯示空狀態避免報錯
      return {'rate': 0, 'pending': 0};
    } catch (_) {
      return {'rate': 0, 'pending': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '本週完成率', icon: Icons.insights_outlined),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchStats(),
            builder: (context, snap) {
              final rate = (snap.data?['rate'] ?? 0) as num;
              final pending = (snap.data?['pending'] ?? 0) as num;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${rate.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  Text('未完成 $pending 則',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              );
            },
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('去補做'),
            ),
          )
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _CardHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
        const Spacer(),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final String type;
  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    if (type.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}
