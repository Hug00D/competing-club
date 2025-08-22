// ==========================================
// file: widgets/home_overview_cards.dart
// PageView 分頁卡 + Firestore 查詢（依你的結構）
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
    final pages = <Widget>[
      AiLatestCard(onOpenAI: onOpenAI),
      TodayAgendaCard(onOpenCalendar: onOpenCalendar),
      MemorySpotlightCard(onOpenMemories: onOpenMemories),
      const WeekStatsCard(),
    ];

    final controller = PageController(viewportFraction: 0.92);

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: controller,
        physics: const PageScrollPhysics(),
        itemCount: pages.length,
        itemBuilder: (context, i) {
          final left = i == 0 ? 8.0 : 6.0;
          final right = i == pages.length - 1 ? 8.0 : 6.0;
          return Padding(
            padding: EdgeInsets.only(left: left, right: right),
            child: pages[i],
          );
        },
      ),
    );
  }
}

/* ---------------- Base Card ---------------- */
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

/* ======================== AI 最新回應 ======================== */
class AiLatestCard extends StatelessWidget {
  final VoidCallback onOpenAI;
  const AiLatestCard({super.key, required this.onOpenAI});

  DateTime _toDate(dynamic v) {
    // Firestore Timestamp or ISO string；其餘給個極小時間
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      // 盡量 parse（若是 ISO 字串可吃，中文格式則回退極小時間）
      final dt = DateTime.tryParse(v);
      if (dt != null) return dt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<String?> _fetchLatestSnippet() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      // 1) 根集合 ai_companion（首選）
      try {
        final q = await FirebaseFirestore.instance
            .collection('ai_companion')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final m = q.docs.first.data();
          final txt = (m['aiResponse'] ?? m['text'] ?? m['content'] ?? m['message']) as String?;
          if (txt != null && txt.trim().isNotEmpty) return txt;
        }
      } catch (_) {
        // 若因索引/排序失敗，用 client 端排序
        final q = await FirebaseFirestore.instance
            .collection('ai_companion')
            .where('uid', isEqualTo: uid)
            .limit(10)
            .get();
        if (q.docs.isNotEmpty) {
          q.docs.sort((a, b) =>
              _toDate(b.data()['createdAt']).compareTo(_toDate(a.data()['createdAt'])));
          final m = q.docs.first.data();
          final txt = (m['aiResponse'] ?? m['text'] ?? m['content'] ?? m['message']) as String?;
          if (txt != null && txt.trim().isNotEmpty) return txt;
        }
      }

      // 2) 退回 users/{uid}/ai_chats（舊結構）
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('ai_chats')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final m = snap.docs.first.data();
        final txt = (m['text'] ?? m['content'] ?? m['message']) as String?;
        if (txt != null && txt.trim().isNotEmpty) return txt;
      }

      return null;
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
              final display = (text == null || text.trim().isEmpty)
                  ? '和我聊聊吧，我可以提醒你今天的安排～'
                  : '“${text.trim().replaceAll('\n', ' ')}”';
              return Text(
                display,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF111827)),
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

/* ======================== 今日行事曆（只顯示今天 + 未完成） ======================== */
class TodayAgendaCard extends StatelessWidget {
  final VoidCallback onOpenCalendar;
  const TodayAgendaCard({super.key, required this.onOpenCalendar});

  String _todayStr() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<List<Map<String, dynamic>>> _fetchToday() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];
      final today = _todayStr();

      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks');

      // 只抓「今天」且「未完成」
      try {
        final qs = await col
            .where('date', isEqualTo: today)
            .where('completed', isEqualTo: false)
            .orderBy('time')
            .limit(5)
            .get();

        // 保險：再過濾一次 date == today
        final list = qs.docs.map((d) => d.data())
            .where((m) => (m['date'] ?? '') == today)
            .toList();

        return list;
      } catch (_) {
        // 若沒索引或 time 欄位，改為只用等值查詢，回來後在記憶體排序與過濾
        final qs = await col
            .where('date', isEqualTo: today)
            .where('completed', isEqualTo: false)
            .get();

        final list = qs.docs.map((d) => d.data()).toList();

        list.sort((a, b) {
          final ta = (a['time'] ?? '') as String;
          final tb = (b['time'] ?? '') as String;
          return ta.compareTo(tb);
        });

        return list;
      }
    } catch (e) {
      debugPrint('fetchToday error: $e');
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
                return const Text(
                  '今天還沒有未完成的安排 🎉',
                  style: TextStyle(color: Color(0xFF4B5563)), // 灰但清晰
                );
              }
              return Column(
                children: [
                  for (final m in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            (m['time'] ?? '--:--').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF374151), // 深灰藍
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              (m['task'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black, // 黑色明顯
                              ),
                            ),
                          ),
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

/* ======================== 回憶錄焦點（根集合 memories） ======================== */
class MemorySpotlightCard extends StatelessWidget {
  final VoidCallback onOpenMemories;
  const MemorySpotlightCard({super.key, required this.onOpenMemories});

  Future<Map<String, dynamic>?> _fetchOne() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      // 根集合 memories，帶 uid
      final root = await FirebaseFirestore.instance
          .collection('memories')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (root.docs.isNotEmpty) return root.docs.first.data();

      // 退回 users/{uid}/memories（若有）
      final sub = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('memories')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (sub.docs.isNotEmpty) return sub.docs.first.data();

      return null;
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
              final desc  = (data?['description'] ?? '用照片與語音記下重要時刻').toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF374151)),
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

/* ======================== 本週完成率（先放空資料） ======================== */
class WeekStatsCard extends StatelessWidget {
  const WeekStatsCard({super.key});

  Future<Map<String, dynamic>> _fetchStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return {'rate': 0, 'pending': 0};

      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // 週一
      final endOfWeek = startOfWeek.add(const Duration(days: 6));        // 週日

      String formatDate(DateTime dt) {
        return "${dt.year.toString().padLeft(4, '0')}-"
            "${dt.month.toString().padLeft(2, '0')}-"
            "${dt.day.toString().padLeft(2, '0')}";
      }

      final startStr = formatDate(startOfWeek);
      final endStr   = formatDate(endOfWeek);

      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      final tasks = qs.docs.map((d) => d.data()).toList();

      if (tasks.isEmpty) return {'rate': 0, 'pending': 0};

      final total = tasks.length;
      final done = tasks.where((t) => t['completed'] == true).length;
      final pending = total - done;

      final rate = (done / total) * 100;

      return {'rate': rate, 'pending': pending};
    } catch (e) {
      debugPrint("fetchStats error: $e");
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
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827))),
                  const SizedBox(width: 12),
                  Text('未完成 $pending 則',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                ],
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}


/* ---------------- 小組件 ---------------- */
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
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
        color: const Color(0xFFE0F2FE), // 淡藍底
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E3A8A), // 藍字
        ),
      ),
    );
  }
}
