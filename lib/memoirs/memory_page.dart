// memory_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'add_memory_page.dart';
import 'category_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_memory_page.dart';

class Memory {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final List<String> imagePaths;
  final String audioPath;
  final String category;

  Memory({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.imagePaths,
    required this.audioPath,
    required this.category,
  });

  factory Memory.fromFirestore(String docId, Map<String, dynamic> data) {
    final imageList = data['imageUrls'];
    List<String> imagePaths = [];
    if (imageList is List) {
      imagePaths = imageList.whereType<String>().toList();
    }
    return Memory(
      id: docId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imagePaths: imagePaths,
      audioPath: data['audioPath'] ?? '',
      category: data['category'] ?? '',
    );
  }
}

class MemoryPage extends StatefulWidget {
  final String? targetUid;
  const MemoryPage({super.key, this.targetUid});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final List<Memory> _memories = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _categories = ['人物', '旅遊'];
  final Set<String> _collapsedCategories = {};
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = widget.targetUid ?? FirebaseAuth.instance.currentUser?.uid;
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    if (_uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('memories')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .get();

    final memories = snapshot.docs
        .map((doc) => Memory.fromFirestore(doc.id, doc.data()))
        .toList();

    setState(() {
      _memories
        ..clear()
        ..addAll(memories);
    });
  }

  Future<void> _navigateToAddMemory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemoryPage(
          categories: _categories,
          targetUid: _uid,
        ),
      ),
    );
    if (result != null) _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('回憶錄'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.category, size: 20),
              label: const Text('分類', style: TextStyle(fontSize: 16)),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CategoryManager(
                  initialCategories: _categories,
                  onCategoriesUpdated: (newCats) {
                    setState(() => _categories = newCats);
                  },
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[900],
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        children: _categories.map((category) {
          final memoriesInCategory = _memories.where((m) => m.category == category).toList();
          if (memoriesInCategory.isEmpty) return const SizedBox();
          final isCollapsed = _collapsedCategories.contains(category);
          return Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isCollapsed) {
                        _collapsedCategories.remove(category);
                      } else {
                        _collapsedCategories.add(category);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          isCollapsed ? Icons.expand_more : Icons.expand_less,
                          color: const Color(0xFF5B8EFF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B8EFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                      children: memoriesInCategory.map((memory) {
                        return GestureDetector(
                          onTap: () => _showMemoryDetail(memory),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: memory.imagePaths.isNotEmpty
                                    ? Image.network(
                                  memory.imagePaths.first,
                                  width: double.infinity,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
                                  width: double.infinity,
                                  height: 120,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                memory.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF097988),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                memory.date.toString().substring(0, 16),
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 2),
            )
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _navigateToAddMemory,
        ),
      ),
    );
  }

  void _showMemoryDetail(Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 📷 首圖
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: memory.imagePaths.isNotEmpty
                              ? Image.network(
                            memory.imagePaths.first,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          )
                              : Container(
                            height: 100,
                            width: double.infinity,
                            color: const Color.fromARGB(255, 9, 87, 135),
                          ),
                        ),

                        const SizedBox(height: 1),

                        // 📝 描述區塊
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
                                  color: Color(0xFF5B8EFF),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                memory.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 其餘圖片
                        ...memory.imagePaths.skip(1).map((path) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),

                  // 🔊 播放按鈕
                  Positioned(
                    bottom: 80,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF5B8EFF),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      onPressed: () async {
                        try {
                          if (memory.audioPath.startsWith('http')) {
                            await _audioPlayer.setUrl(memory.audioPath);
                          } else {
                            await _audioPlayer.setFilePath(memory.audioPath);
                          }
                          await _audioPlayer.play();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('無法播放語音')),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  // ✏️ 編輯按鈕
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditMemoryPage(
                              docId: memory.id,
                              title: memory.title,
                              description: memory.description,
                              imagePaths: memory.imagePaths,
                              audioPath: memory.audioPath,
                              category: memory.category,
                              categories: _categories,
                            ),
                          ),
                        );
                        if (result != null) _loadMemories();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('編輯回憶'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}