import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:memory/memoirs/memory_service.dart';

class AICompanionService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 讀取今日任務
  Future<List<Map<String, String>>> fetchTodayTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('date', isEqualTo: todayKey)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'task': (data['task'] ?? '').toString(),
        'time': (data['time'] ?? '').toString(),
        'end': (data['end'] ?? '').toString(),
        'type': (data['type'] ?? '').toString(),
      };
    }).toList();
  }

  /// 若有任務在一小時內，語音提醒
  Future<void> remindIfUpcomingTask() async {
    final tasks = await fetchTodayTasks();
    final now = DateTime.now();

    for (final task in tasks) {
      final taskTime = DateFormat('HH:mm').parse(task['time']!);
      final taskDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        taskTime.hour,
        taskTime.minute,
      );

      if (taskDateTime.isAfter(now) &&
          taskDateTime.difference(now).inMinutes <= 60) {
        await speak("提醒您，一個小時後有任務：${task['task']}");
        break;
      }
    }
  }

  /// AI 說話
  Future<void> speak(String text) async {
    await _flutterTts.setPitch(1.2);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setLanguage('zh-TW');
    await _flutterTts.speak(text);
  }

  /// 存對話進 Firestore
  Future<void> saveToFirestore(String userText, String aiResponse) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('ai_companion').add({
      'uid': uid,
      'userText': userText,
      'aiResponse': aiResponse,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 根據關鍵字播放回憶語音
  Future<void> playMemoryAudioIfMatch(String userInput) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final memoryService = MemoryService();
    final memories = await memoryService.fetchMemories(uid);

    final keywords = userInput.split(RegExp(r'\s+'));
    final match = memories.firstWhere(
      (m) => keywords.any((kw) =>
          (m['title'] ?? '').toString().contains(kw) ||
          (m['description'] ?? '').toString().contains(kw)),
      orElse: () => {},
    );

    final audioUrl = match['audioPath'];
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      await _flutterTts.stop();
      await _audioPlayer.stop();

      if (audioUrl.startsWith('http')) {
        await _audioPlayer.setUrl(audioUrl);
      } else if (audioUrl.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(audioUrl);
        final downloadUrl = await ref.getDownloadURL();
        await _audioPlayer.setUrl(downloadUrl);
      } else {
        await _audioPlayer.setFilePath(audioUrl);
      }

      await _audioPlayer.play();
    } catch (e) {
      print('❌ 回憶語音播放失敗: $e');
    }
  }

  /// 處理訊息並請求 AI 回覆
  Future<String?> processUserMessage(String prompt) async {
    const apiKey = 'AIzaSyCSiUQBqYBaWgpxHr37RcuKoaiiUOUfQhs';
    const url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final uid = FirebaseAuth.instance.currentUser?.uid;
    String memorySummary = '（尚無回憶紀錄）';
    if (uid != null) {
      final memoryService = MemoryService();
      final memories = await memoryService.fetchMemories(uid);
      memorySummary = memoryService.summarizeMemories(memories);
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': '''
你是一位溫柔且簡潔的 AI 陪伴者，擅長傾聽與陪伴使用者，幫助他們回憶過去的美好往事，並提醒即將到來的重要任務。

📌 注意重點：

1. 「回憶錄」是使用者曾經記錄過的**過去經歷**，請協助他回想與分享當時的感受與細節。
2. 「行事曆任務」是未來即將發生的事件，例如吃藥、活動、看診，請用來提醒他注意安排。
3. 不要混淆「回憶」與「任務」，你的任務是陪伴與引導回憶。
4. 你可以說：「這個回憶真棒，要不要聽聽那段錄音？」
5.請回答於50字以內，若對話時間有一小時內的任務可以提醒使用者。

🧠 以下是使用者的回憶摘要：
$memorySummary

📅 使用者說：
「$prompt」
'''
            }
          ]
        }
      ]
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    } else {
      print('Gemini API error: ${response.body}');
      return null;
    }
  }
}
