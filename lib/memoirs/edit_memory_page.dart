// ✅ edit_memory_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'memory_platform.dart';
import 'cloudinary_upload.dart';


class EditMemoryPage extends StatefulWidget {
  final String docId;
  final String title;
  final String description;
  final List<String> imagePaths;
  final String audioPath;
  final String category;
  final List<String> categories;

  const EditMemoryPage({
    super.key,
    required this.docId,
    required this.title,
    required this.description,
    required this.imagePaths,
    required this.audioPath,
    required this.category,
    required this.categories,
  });

  @override
  State<EditMemoryPage> createState() => _EditMemoryPageState();
}

class _EditMemoryPageState extends State<EditMemoryPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<String> _imagePaths;
  String? _recordedPath;
  bool _isRecording = false;
  bool _isSaving = false;
  late final MemoryPlatform recorder;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
    _imagePaths = [...widget.imagePaths];
    _recordedPath = widget.audioPath;
    _selectedCategory = widget.category;
    recorder = getPlatformRecorder();
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
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入回憶標題')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final List<String> uploadedImageUrls = [];
    for (final path in _imagePaths) {
      if (path.startsWith('http')) {
        uploadedImageUrls.add(path);
      } else {
        final file = File(path);
        final url = await uploadFileToCloudinary(file, isImage: true);
        if (url != null) uploadedImageUrls.add(url);
      }
    }

    String? uploadedAudioUrl = _recordedPath;
    if (_recordedPath != null && !_recordedPath!.startsWith('http')) {
      final audioFile = File(_recordedPath!);
      final audioUrl = await uploadFileToCloudinary(audioFile, isImage: false);
      if (audioUrl != null) uploadedAudioUrl = audioUrl;
    }

    await FirebaseFirestore.instance.collection('memories').doc(widget.docId).update({
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'imageUrls': uploadedImageUrls,
      'audioPath': uploadedAudioUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('回憶已更新')),
    );
    Navigator.pop(context, true);
    setState(() => _isSaving = false);
  }

  Widget _buildImageItem(String path) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: path.startsWith('http')
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
      appBar: AppBar(title: const Text('編輯回憶')),
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
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('刪除回憶'),
                    content: const Text('確定要刪除這則回憶嗎？刪除後無法恢復。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('刪除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('memories')
                      .doc(widget.docId)
                      .delete();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('回憶已刪除')),
                    );
                  }
                  if (context.mounted) Navigator.of(context).pop(true); // 返回上一頁並刷新
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // ✅ 黑色背景
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                '刪除回憶',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold), // ✅ 紅字
              ),
            ),
          ],
        ),
      ),
    );
  }
}