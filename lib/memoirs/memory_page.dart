// memory_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'add_memory_page.dart';
import 'edit_memory_page.dart';
import 'category_manager.dart';

class Memory {
  final String title;
  final String description;
  final DateTime date;
  final List<String> imagePaths;
  final String audioPath;
  final String category;

  Memory({
    required this.title,
    required this.description,
    required this.date,
    required this.imagePaths,
    required this.audioPath,
    required this.category,
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
  List<String> _categories = ['人物', '旅遊'];
  final Set<String> _collapsedCategories = {};

  void _showCategoryManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryManager(
        initialCategories: _categories,
        onCategoriesUpdated: (newCategories) {
          setState(() {
            _categories = newCategories;
          });
        },
      ),
    );
  }

  void _showMemoryDetail(Memory memory) {
    // 保留原彈窗邏輯
  }

  Future<void> _navigateToAddMemory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddMemoryPage(categories: _categories)),
    );
    if (result != null) {
      final title = result['title'] as String? ?? '';
      final description = result['description'] as String? ?? '';
      final audioPath = result['audioPath'] as String? ?? '';
      final images = (result['images'] as List?)?.cast<File>() ?? [];
      final category = result['category'] as String? ?? _categories.first;
      setState(() {
        _memories.add(
          Memory(
            title: title,
            description: description,
            date: DateTime.now(),
            imagePaths: images.map((f) => f.path).toList(),
            audioPath: audioPath,
            category: category,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回憶錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _showCategoryManager,
          ),
        ],
      ),
      body: _memories.isEmpty
          ? const Center(child: Text('尚未新增任何回憶'))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _categories.map((category) {
                final categoryMemories = _memories.where((m) => m.category == category).toList();
                if (categoryMemories.isEmpty) return const SizedBox();
                final isCollapsed = _collapsedCategories.contains(category);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_collapsedCategories.contains(category)) {
                            _collapsedCategories.remove(category);
                          } else {
                            _collapsedCategories.add(category);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, color: const Color.fromARGB(221, 186, 155, 155)),
                          const SizedBox(width: 4),
                          Text(
                            category,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(221, 173, 150, 150)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 1, color: Colors.black45, height: 16),
                    if (!isCollapsed)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: categoryMemories.map((memory) {
                          return GestureDetector(
                            onTap: () => _showMemoryDetail(memory),
                            child: Container(
                              width: MediaQuery.of(context).size.width / 2 - 24,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(221, 131, 123, 123),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromARGB(66, 160, 143, 143),
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
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
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 120,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: 120,
                                          width: double.infinity,
                                          decoration: const BoxDecoration(
                                            color: Colors.grey,
                                            borderRadius: BorderRadius.only(
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
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMemory,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
