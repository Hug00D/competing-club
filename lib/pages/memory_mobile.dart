import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

Widget buildMemoryPage(BuildContext context) {
  return const _MemoryPage();
}

class _MemoryPage extends StatefulWidget {
  const _MemoryPage();

  @override
  State<_MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<_MemoryPage> {
  final List<Map<String, dynamic>> _memories = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  XFile? _imageFile;
  String? _recordedPath;
  bool _isRecording = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _imageFile = picked;
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final path = '/sdcard/Download/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordedPath = path;
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
  }

  Future<void> _stopRecording() async {
    _recordedPath = await _recorder.stop();
  }

  void _playAudio(String? path) async {
    await _audioPlayer.stop();
    if (path != null) {
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('沒有可播放的語音')));
    }
  }

  Future<void> _addMemory() async {
    final titleController = TextEditingController();
    _imageFile = null;
    _recordedPath = null;
    _isRecording = false;

    await _pickImage();
    if (_imageFile == null) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('新增回憶'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_imageFile != null)
                    Image.file(File(_imageFile!.path), height: 180, fit: BoxFit.cover),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '標題'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? '停止錄音' : '開始錄音'),
                    onPressed: () async {
                      if (_isRecording) {
                        await _stopRecording();
                      } else {
                        await _startRecording();
                      }
                      setState(() => _isRecording = !_isRecording);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(type: FileType.audio);
                      if (picked != null && picked.files.single.path != null) {
                        setState(() {
                          _recordedPath = picked.files.single.path!;
                        });
                      }
                    },
                    child: const Text('或選擇音檔'),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.pop(context, titleController.text);
                },
                child: const Text('儲存'),
              ),
            ],
          );
        });
      },
    );

    final title = titleController.text;
    if (title.isNotEmpty) {
      setState(() {
        _memories.add({
          'title': title,
          'date': DateTime.now(),
          'imagePath': _imageFile?.path,
          'audioPath': _recordedPath,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回憶錄'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addMemory),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _memories.length,
        itemBuilder: (context, index) {
          final memory = _memories[index];
          return GestureDetector(
            onTap: () => _playAudio(memory['audioPath']),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.file(File(memory['imagePath']), width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          memory['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (memory['date'] as DateTime).toLocal().toString().split(' ')[0],
                          style: const TextStyle(color: Colors.grey),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}