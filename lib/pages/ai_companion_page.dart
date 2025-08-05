import 'package:flutter/material.dart';
import 'package:memory/services/ai_companion_service.dart';

class AICompanionPage extends StatefulWidget {
  const AICompanionPage({super.key});

  @override
  State<AICompanionPage> createState() => _AICompanionPageState();
}

class _AICompanionPageState extends State<AICompanionPage> {
  final AICompanionService _service = AICompanionService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  final List<String> _fixedPrompts = ['幫助我回憶', '提醒我今天要做的事'];

  @override
  void initState() {
    super.initState();
    _loadPreviousMessages();
  }

  Future<void> _loadPreviousMessages() async {
    // 可加入從 Firestore 載入過往訊息的邏輯
  }

  Future<void> _sendMessage(String input) async {
    if (input.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': input});
      _isLoading = true;
    });
    _controller.clear();

    await _scrollToBottom();

    final reply = await _service.processUserMessage(input);
    if (reply != null) {
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });

      await _service.playMemoryAudioIfMatch(input);
      await _service.remindIfUpcomingTask();
      await _service.speak(reply);
      await _service.saveToFirestore(input, reply);
    }

    setState(() => _isLoading = false);
    await _scrollToBottom();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.lightBlue[100] : const Color(0xFFDFF5E1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message['text'] ?? '', style: const TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget _buildQuickPromptButtons() {
    final lastUserMessages = _messages.where((m) => m['role'] == 'user').map((m) => m['text']!).toList();
    String dynamicSuggestion = '提醒我今天要做的事';

    if (lastUserMessages.length >= 3) {
      final last = lastUserMessages.last;
      if (last.contains('家人')) {
        dynamicSuggestion = '聊聊家人';
      } else if (last.contains('旅行')) {
        dynamicSuggestion = '說說旅行的事';
      } else {
        dynamicSuggestion = '你還記得那次的事嗎？';
      }
    }

    final suggestions = [..._fixedPrompts, dynamicSuggestion];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((text) => _buildPromptButton(text)).toList(),
      ),
    );
  }

  Widget _buildPromptButton(String text) {
    final isPrimary = text == '提醒我今天要做的事';
    return ElevatedButton(
      onPressed: () => _sendMessage(text),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: isPrimary ? const Color(0xFFD6EEFF) : Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: isPrimary ? Colors.lightBlue : Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('AI 陪伴'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildQuickPromptButtons(),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      hintText: '輸入訊息...',
                      counterText: '',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(_controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('送出'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
