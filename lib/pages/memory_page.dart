import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final List<Map<String, dynamic>> _memories = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    if (!kIsWeb) {
      await _recorder.openRecorder();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (!kIsWeb) {
      _recorder.closeRecorder();
    }
    super.dispose();
  }

  Future<void> _addMemory() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final imageBytes = kIsWeb ? await image.readAsBytes() : null;

    String? audioPath;
    bool isRecording = false;
    final titleController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('新增回憶'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.memory(imageBytes!, height: 180, fit: BoxFit.cover)
                        : Image.file(File(image.path), height: 180, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '標題'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    label: Text(isRecording ? '停止錄音' : '開始錄音'),
                    onPressed: () async {
                      if (kIsWeb) return;
                      if (!isRecording) {
                        final status = await Permission.microphone.request();
                        if (!status.isGranted) return;

                        final tempDir = Directory.systemTemp;
                        _recordedPath = '${tempDir.path}/memory_${DateTime.now().millisecondsSinceEpoch}.aac';
                        await _recorder.startRecorder(toFile: _recordedPath);
                      } else {
                        await _recorder.stopRecorder();
                        audioPath = _recordedPath;
                      }
                      setState(() => isRecording = !isRecording);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(type: FileType.audio);
                      if (picked != null && picked.files.single.path != null) {
                        setState(() {
                          audioPath = picked.files.single.path;
                        });
                      }
                    },
                    child: const Text('或選擇音檔'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, titleController.text),
                child: const Text('儲存'),
              ),
            ],
          ),
        );
      },
    );

    final title = titleController.text;
    if (title.isNotEmpty) {
      setState(() {
        _memories.add({
          'title': title,
          'imagePath': image.path,
          'imageBytes': imageBytes,
          'audioPath': audioPath,
          'date': DateTime.now(),
        });
      });
    }
    _recordedPath = null;
  }

  void _playAudio(String? path) async {
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('這張回憶沒有語音')),
      );
      return;
    }
    await _audioPlayer.stop();
    if (kIsWeb) {
      await _audioPlayer.play(UrlSource(path));
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回憶錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _addMemory,
          )
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
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: kIsWeb
                          ? Image.memory(
                        memory['imageBytes'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : Image.file(
                        File(memory['imagePath']),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
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
