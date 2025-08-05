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
    _checkAndLoad(); // 加入這層封裝
  }

  void _checkAndLoad() async {
    if (_uid == null) {
      debugPrint('❌ 沒有 targetUid，也沒有登入者 uid，無法載入回憶錄');
      return;
    }

    await _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('memories')
          .where('uid', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('📦 找到 ${snapshot.docs.length} 筆回憶錄 for uid=$_uid');

      final memories = snapshot.docs
          .map((doc) => Memory.fromFirestore(doc.id, doc.data()))
          .toList();

      if (!mounted) return; // ✅ 這裡加上這行
      setState(() {
        _memories
          ..clear()
          ..addAll(memories);
      });
    } catch (e) {
      debugPrint('❌ 無法讀取資料：$e');
    }
  }



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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
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
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 100),
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
                                  ? Image.network(
                                memory.imagePaths.first,
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
                                child: Image.network(
                                  path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 150,
                                    color: Colors.grey[300],
                                  ),
                                )
                            ),
                          );
                        }),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: const Color.fromARGB(255, 98, 97, 97),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32), // ✅ 加回箭頭
                      onPressed: () async {
                        final player = AudioPlayer();

                        try {
                          if (memory.audioPath.startsWith('http')) {
                            await player.setUrl(memory.audioPath);
                          } else {
                            await player.setFilePath(memory.audioPath);
                          }
                          await player.play();
                        } catch (e) {
                          debugPrint('播放失敗: $e');
                           // ✅ 確保 widget 還存在
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('無法播放語音')),
                          );
                        }
                      },
                    ),
                  ),
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
                              docId: memory.id, // ← 你需要確保記憶物件有這個欄位
                              title: memory.title,
                              description: memory.description,
                              imagePaths: memory.imagePaths,
                              audioPath: memory.audioPath,
                              category: memory.category,
                              categories: _categories,
                            ),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            final index = _memories.indexOf(memory);
                            if (index != -1) {
                              _memories[index] = Memory(
                                id: memory.id,
                                title: result['title'],
                                description: result['description'],
                                date: memory.date,
                                imagePaths: (result['images'] as List).cast<String>(), // ✅ Cloudinary 回傳是 URL 字串
                                audioPath: result['audio'],
                                category: result['category'],
                              );
                            }
                          });
                          if (context.mounted) Navigator.of(context).pop();
                        }
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


  Future<void> _navigateToAddMemory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddMemoryPage(categories: _categories, targetUid: _uid)),
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
            id: '', // or 'local-temp-id'
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
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('memories')
            .where('uid', isEqualTo: _uid)
            .orderBy('createdAt', descending: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('尚未新增任何回憶'));
          }

          final allMemories = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Memory(
              id: doc.id, // ✅ 使用 doc.id 作為 id
              title: data['title'] ?? '',
              description: data['description'] ?? '',
              date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              imagePaths: (data['imageUrls'] as List?)?.cast<String>() ?? [],
              audioPath: data['audioPath'] ?? '',
              category: data['category'] ?? '',
            );
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: _categories.map((category) {
              final categoryMemories = allMemories.where((m) => m.category == category).toList();
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
                        Icon(isCollapsed ? Icons.expand_more : Icons.expand_less,
                            color: const Color.fromARGB(221, 186, 155, 155)),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(221, 173, 150, 150)),
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
                                  offset: const Offset(2, 2),
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
                                  child: Image.network(
                                    memory.imagePaths.first,
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}