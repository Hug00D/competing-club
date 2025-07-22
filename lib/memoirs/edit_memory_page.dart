import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'memory_platform.dart';

class EditMemoryPage extends StatefulWidget {
  final String title;
  final String description;
  final List<String> imagePaths;
  final String audioPath;
  final String category;
  final List<String> categories;

  const EditMemoryPage({
    super.key,
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
  late final MemoryPlatform recorder;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
    _imagePaths = [...widget.imagePaths];
    _recordedPath = widget.audioPath;
    recorder = getPlatformRecorder();
    _selectedCategory = widget.category;
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(pickedFiles.map((e) => e.path));
      });
    }
  }

  Future<void> _createBlackImageIfNeeded() async {
    if (_imagePaths.isEmpty) {
      final Uint8List blackBytes = Uint8List.fromList(List.generate(100 * 100 * 4, (i) => 0));
      final directory = await getTemporaryDirectory();
      final blackImage = File('${directory.path}/black_${DateTime.now().millisecondsSinceEpoch}.png');
      await blackImage.writeAsBytes(blackBytes);
      _imagePaths.add(blackImage.path);
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
    await _createBlackImageIfNeeded();
    final updatedMemory = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'images': _imagePaths.map((path) => File(path)).toList(),
      'audio': _recordedPath,
      'category': _selectedCategory,
    };
    Navigator.pop(context, updatedMemory);
  }

  Widget _buildImageItem(String path) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path), width: 100, height: 100, fit: BoxFit.cover),
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
                  setState(() {
                    _selectedCategory = value;
                  });
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
            const SizedBox(height: 20),
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
