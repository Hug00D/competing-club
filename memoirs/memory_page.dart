import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'add_memory_page.dart';
import 'edit_memory_page.dart';

class Memory {
  final String title;
  final String description;
  final DateTime date;
  final List<String> imagePaths;
  final String audioPath;

  Memory({
    required this.title,
    required this.description,
    required this.date,
    required this.imagePaths,
    required this.audioPath,
  });
}

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final List<Memory> _memories = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _showMemoryDetail(Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.85,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              child: memory.imagePaths.isNotEmpty
                                  ? Image.file(
                                      File(memory.imagePaths.first),
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                      ),
                                    )
                                  : Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                    ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    memory.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black.withOpacity(0.7),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                                    label: const Text('播放語音', style: TextStyle(color: Colors.white)),
                                    onPressed: () async {
                                      final player = AudioPlayer();
                                      await player.setFilePath(memory.audioPath);
                                      await player.play();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '描述',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(221, 103, 102, 102),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                memory.description,
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...memory.imagePaths.skip(1).map((path) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditMemoryPage(
                        title: memory.title,
                        description: memory.description,
                        imagePaths: memory.imagePaths,
                        audioPath: memory.audioPath,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    final updatedMemory = Memory(
                      title: result['title'],
                      description: result['description'],
                      date: DateTime.now(),
                      imagePaths: (result['images'] as List?)?.cast<File>().map((f) => f.path).toList() ?? [],
                      audioPath: result['audio'] ?? '',
                    );
                    setState(() {
                      final index = _memories.indexOf(memory);
                      if (index != -1) _memories[index] = updatedMemory;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('編輯回憶', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToAddMemory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMemoryPage()),
    );
    if (result != null) {
      final title = result['title'] as String? ?? '';
      final description = result['description'] as String? ?? '';
      final audioPath = result['audioPath'] as String? ?? '';
      final images = (result['images'] as List?)?.cast<File>() ?? [];
      setState(() {
        _memories.add(
          Memory(
            title: title,
            description: description,
            date: DateTime.now(),
            imagePaths: images.map((f) => f.path).toList(),
            audioPath: audioPath,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回憶錄')),
      body: _memories.isEmpty
          ? const Center(child: Text('尚未新增任何回憶'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _memories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 4,
              ),
              itemBuilder: (context, index) {
                final memory = _memories[index];
                return GestureDetector(
                  onTap: () => _showMemoryDetail(memory),
                  child: Card(
                    elevation: 4,
                    color: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        memory.imagePaths.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: Image.file(
                                  File(memory.imagePaths.first),
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 150,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              )
                            : Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                memory.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                memory.date.toString().substring(0, 16),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMemory,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}
