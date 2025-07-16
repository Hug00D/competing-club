import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:memory/pages/memory_platform.dart';

class AddMemoryPage extends StatefulWidget {
  const AddMemoryPage({super.key});

  @override
  State<AddMemoryPage> createState() => _AddMemoryPageState();
}

class _AddMemoryPageState extends State<AddMemoryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<File> _imageFiles = [];
  String? _recordedPath;
  bool _isRecording = false;
  late final MemoryPlatform recorder;

  @override
  void initState() {
    super.initState();
    recorder = getPlatformRecorder();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(pickedFiles.map((e) => File(e.path)));
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
      _recordedPath = result['path'];
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
    if (_titleController.text.trim().isEmpty) return;

    final memory = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'images': _imageFiles,
      'audio': _recordedPath,
    };

    Navigator.pop(context, memory);
  }

  Widget _buildImageItem(File file) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
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
                _imageFiles.remove(file);
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
            const SizedBox(height: 16),
            if (_imageFiles.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _imageFiles.map(_buildImageItem).toList(),
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
              onPressed: _saveMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('儲存回憶', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
