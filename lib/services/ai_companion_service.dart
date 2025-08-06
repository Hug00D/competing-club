import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:memory/memoirs/memory_service.dart';
import 'package:flutter/foundation.dart'; // 👈 加這行才有 debugPrint

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

Map<String, dynamic>? _lastPlayedMemory;

Future<bool> playMemoryAudioIfMatch(String userInput) async {
  debugPrint('🎧 呼叫 playMemoryAudioIfMatch');

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;

  final memoryService = MemoryService();
  final memories = await memoryService.fetchMemories(uid);
  debugPrint('📦 撈到 ${memories.length} 筆記憶');

  final lowerInput = userInput.toLowerCase();
  final keywords = userInput.split(RegExp(r'\s+'));
  debugPrint('🔍 關鍵字：$keywords');

  // ✅ 處理「再播一次」類型
  if (lowerInput.contains("再播") || lowerInput.contains("重播") || lowerInput.contains("再聽")) {
    if (_lastPlayedMemory != null) {
      final audioUrl = _lastPlayedMemory!['audioPath'];
      if (audioUrl != null && audioUrl.isNotEmpty) {
        debugPrint('🔁 重播上次記憶：$audioUrl');
        return await _playAudioFromPath(audioUrl);
      }
    }
    debugPrint('⚠️ 沒有可重播的記憶');
    return false;
  }

  // ✅ 從輸入找日期（例如 8/6）
  final datePattern = RegExp(r'(\d{1,2})[\/\-](\d{1,2})');
  final now = DateTime.now();

  DateTime? targetDate;
  final match = datePattern.firstMatch(userInput);
  if (match != null) {
    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    if (month != null && day != null) {
      targetDate = DateTime(now.year, month, day);
    }
  }

  Map<String, dynamic>? matched;

  // ✅ 先用日期找
  if (targetDate != null) {
    debugPrint('📅 嘗試比對日期：$targetDate');
    matched = memories.firstWhere(
      (m) {
        final ts = m['createdAt']; // 🔁 改成 createdAt

        if (ts is Timestamp) {
          final memDate = ts.toDate();
          return memDate.year == targetDate!.year &&
                memDate.month == targetDate.month &&
                memDate.day == targetDate.day;
        } else if (ts is String) {
          try {
            final memDate = DateTime.parse(ts);
            return memDate.year == targetDate!.year &&
                  memDate.month == targetDate.month &&
                  memDate.day == targetDate.day;
          } catch (_) {
            return false;
          }
        }

        return false;
      },
      orElse: () => {},
    );
  }

  // ✅ 再用文字比對
  matched ??= memories.firstWhere(
    (m) => keywords.any((kw) =>
        (m['title'] ?? '').toString().contains(kw) ||
        (m['description'] ?? '').toString().contains(kw)),
    orElse: () => {},
  );

  final audioUrl = matched['audioPath'];
  if (audioUrl == null || audioUrl.isEmpty) {
    debugPrint('❌ 沒有找到匹配的記憶或 audioPath 為空');
    return false;
  }

  // ✅ 成功的話記住這筆記憶
  _lastPlayedMemory = matched;
  return await _playAudioFromPath(audioUrl);
}



Future<bool> _playAudioFromPath(String path) async {
  try {
    await _audioPlayer.stop();
    await _flutterTts.stop();

    if (path.startsWith('http')) {
      await _audioPlayer.setUrl(path);
    } else if (path.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(path);
      final downloadUrl = await ref.getDownloadURL();
      print('☁️ Firebase Storage URL: $downloadUrl');
      await _audioPlayer.setUrl(downloadUrl);
    } else {
      print('📁 播放本地音檔: $path');
      await _audioPlayer.setFilePath(path); // 僅限手機
    }

    await _audioPlayer.play();
    print('▶️ 開始播放音檔');
    return true;
  } catch (e) {
    print('❌ 音檔播放失敗: $e');
    return false;
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
如果使用者提到希望「聽錄音」、「播放」、「聽某段記憶」，請直接回應播放結束，並在文字後面加上 `[播放回憶錄]` 標記。

📌 注意重點：

1. 「回憶錄」是使用者曾經記錄過的**過去經歷**，請利用回憶錄紀錄的事項(錄音、描述)協助他回想與分享當時的感受與細節。
2. 「行事曆任務」是未來即將發生的事件，例如吃藥、活動、看診，請用來提醒他注意安排。
3. 不要混淆「回憶」與「任務」，你的任務是陪伴與引導回憶。
4.請回答於50字以內，若對話時間有一小時內的任務可以提醒使用者。
5.請根據他之前說過的內容延續對話、更新記憶，不要出現重複傳話的狀況。

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
