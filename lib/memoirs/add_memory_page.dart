import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'memory_platform.dart';
import 'cloudinary_upload.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddMemoryPage extends StatefulWidget {
  final List<String> categories;

  const AddMemoryPage({super.key, required this.categories});

  @override
  State<AddMemoryPage> createState() => _AddMemoryPageState();
}

class _AddMemoryPageState extends State<AddMemoryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _imagePaths = [];
  String? _recordedPath;
  bool _isRecording = false;
  bool _isSaving = false;
  late final MemoryPlatform recorder;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    recorder = getPlatformRecorder();
    _selectedCategory = widget.categories.first;
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(pickedFiles.map((e) => e.path));
      });
    }
  }

  Future<void> _startRecording() async {
    await recorder.startRecording();
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final result = await recorder.stopRecording();
    setState(() {
      _recordedPath = result['audioPath'];
      _isRecording = false;
    });
  }

  Future<void> _playRecording() async {
    if (_recordedPath != null) {
      final player = AudioPlayer();
      await player.setFilePath(_recordedPath!);
      await player.play();
    }
  }

  Future<void> _saveMemory() async {
    debugPrint('開始儲存記憶');

    if (_titleController.text.trim().isEmpty) {
      debugPrint('標題為空，中止儲存');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入回憶標題')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('找不到登入使用者');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未登入')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final List<String> uploadedImageUrls = [];
    for (final path in _imagePaths) {
      final file = File(path);
      debugPrint('正在上傳圖片: $path');
      final url = await uploadFileToCloudinary(file, isImage: true);
      if (url != null) {
        uploadedImageUrls.add(url);
        debugPrint('圖片上傳成功: $url');
      } else {
        debugPrint('圖片上傳失敗，跳過');
      }
    }

    String? uploadedAudioUrl;
    if (_recordedPath != null) {
      final audioFile = File(_recordedPath!);
      debugPrint('正在上傳音檔: $_recordedPath');
      uploadedAudioUrl = await uploadFileToCloudinary(audioFile, isImage: false);
      if (uploadedAudioUrl != null) {
        debugPrint('音檔上傳成功: $uploadedAudioUrl');
      } else {
        debugPrint('音檔上傳失敗，將使用空字串');
      }
    }

    debugPrint('即將寫入 Firestore');

    await FirebaseFirestore.instance.collection('memories').add({
      'uid': uid,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'imageUrls': uploadedImageUrls,
      'audioPath': uploadedAudioUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('Firestore 寫入完成');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('回憶已儲存')),
    );
    Navigator.pop(context, true); // 回傳 true 讓上一頁可以重新整理

    setState(() => _isSaving = false);
  }

  Widget _buildImageItem(String path) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: kIsWeb
              ? Image.network(path, width: 100, height: 100, fit: BoxFit.cover)
              : Image.file(File(path), width: 100, height: 100, fit: BoxFit.cover),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            onPressed: () {
              setState(() {
                _imagePaths.remove(path);
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立回憶')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '回憶標題'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '回憶描述',
                hintText: '請輸入描述內容（選填）',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: widget.categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
              decoration: const InputDecoration(labelText: '分類'),
            ),
            const SizedBox(height: 16),
            if (_imagePaths.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _imagePaths.map(_buildImageItem).toList(),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('新增圖片'),
              onPressed: _pickImages,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? '停止錄音' : '開始錄音'),
                  onPressed: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else {
                      _startRecording();
                    }
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放錄音'),
                  onPressed: _recordedPath == null ? null : _playRecording,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('儲存回憶', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}