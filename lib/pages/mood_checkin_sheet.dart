import 'package:flutter/material.dart';

class MoodCheckinSheet extends StatefulWidget {
  final void Function(String mood, String? note) onSubmit;
  const MoodCheckinSheet({super.key, required this.onSubmit});

  @override
  State<MoodCheckinSheet> createState() => _MoodCheckinSheetState();
}

class _MoodCheckinSheetState extends State<MoodCheckinSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const deepBlue = Color(0xFF0D47A1);
    const brandBlue = Color(0xFF5B8EFF);

    final items = const [
      {'label': '喜', 'emoji': '😊'},
      {'label': '怒', 'emoji': '😠'},
      {'label': '哀', 'emoji': '😢'},
      {'label': '樂', 'emoji': '😄'},
    ];

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '今天的心情是？',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: deepBlue,  // 深藍
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4 個表情（可自動換行）
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items.map((m) {
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 20*2 - 12*3) / 4,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: brandBlue,
                            foregroundColor: Colors.white,
                            elevation: 2,
                          ),
                          onPressed: () {
                            final note = _ctrl.text.trim();
                            widget.onSubmit(m['label']!, note.isEmpty ? null : note);
                          },
                          child: Column(
                            children: [
                              Text(m['emoji']!, style: const TextStyle(fontSize: 30)),
                              const SizedBox(height: 8),
                              Text(m['label']!, style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '發生了什麼：（可不填）',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: deepBlue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: '想補充一句嗎？（例如：和家人吃飯很開心 / 通勤塞車心很煩）',
                      filled: true,
                      fillColor: const Color(0xFFF5F7FB),
                      hintStyle: const TextStyle( // 提示字更深
                        fontSize: 16,
                        color: Color(0xFF5E6A7D),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E6F1)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: brandBlue, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text('（每日只需打卡一次）',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
