import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // 為了 Clipboard
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';





class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String _role = '';
  String? _uid;
  String? _identityCode;
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// ✅ 從 Firestore 讀取個人資料
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _role = data['role'] ?? '';
          _identityCode = data['identityCode'] ?? '';
          _avatarUrl = data['avatarUrl']; // ✅ 可能為 null
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 讀取個人資料失敗')),
        );
      }
    }
  }

  /// ✅ 儲存名稱 & 身分
  Future<void> _saveProfile() async {
    if (_uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(_uid).set({
      'name': _nameController.text.trim(),
      'role': _role,
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 資料已儲存')),
      );
    }
  }

  /// ✅ 登出功能
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/'); // 登出後導回登入頁
    }
  }

final CropController _cropController = CropController();

Future<void> _pickAndUploadAvatar() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result == null) return;

  // 直接讀 File
  File file = File(result.files.first.path!);
  Uint8List imageBytes = await file.readAsBytes();

  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 500,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('裁剪頭像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: Crop(
                  controller: _cropController,
                  image: imageBytes, // ✅ 這裡直接用 Uint8List
                  aspectRatio: 1,
                  onCropped: (croppedData) async {
                    Navigator.pop(context);

                    // ✅ 存檔後再上傳
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = File('${tempDir.path}/avatar.png');
                    await tempFile.writeAsBytes(croppedData);

                    String? url = await uploadFileToCloudinary(tempFile, isImage: true);

                    if (url != null) {
                      setState(() => _avatarUrl = url);
                      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
                        'avatarUrl': url,
                      }, SetOptions(merge: true));
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _cropController.crop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('完成裁剪'),
              )
            ],
          ),
        ),
      );
    },
  );
}







  Future<String?> uploadBytesToCloudinary(Uint8List bytes, String fileName) async {
    const cloudName = 'dftre2xh6';
    const uploadPreset = 'memoirs';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    )
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(resBody);
      return data['secure_url'];
    } else {
      debugPrint('❌ Cloudinary 錯誤: $resBody');
      return null;
    }
  }

  /// ✅ 上傳檔案到 Cloudinary
  Future<String?> uploadFileToCloudinary(File file, {required bool isImage}) async {
    const cloudName = 'dftre2xh6';
    const uploadPreset = 'memoirs';
    final resourceType = isImage ? 'image' : 'video';

    final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    final mimeType = isImage ? 'image/jpeg' : 'audio/m4a';

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(responseBody);
      return data['secure_url'];
    } else {
      debugPrint('❌ Cloudinary 錯誤: $responseBody');
      return null;
    }
  }

  /// ✅ 下拉選單（照顧者/被照顧者）
  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _role.isNotEmpty ? _role : null,
      style: const TextStyle(color: Colors.black),
      dropdownColor: Colors.white,
      decoration: const InputDecoration(
        labelText: '身分',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'caregiver', child: Text('照顧者')),
        DropdownMenuItem(value: 'user', child: Text('被照顧者')),
      ],
      onChanged: (value) => setState(() => _role = value!),
    );
  }

  /// ✅ 顯示唯一識別碼（可長按複製）
  Widget _buildIdentityCodeField() {
    return _identityCode == null || _identityCode!.isEmpty
        ? const SizedBox.shrink()
        : GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: _identityCode!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已複製識別碼')),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('唯一識別碼（長按可複製）',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              _identityCode!,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('個人檔案'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            /// ✅ 頭像（支援上傳）
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!)
                  : const AssetImage('assets/images/default_avatar.png')
              as ImageProvider,
              child: Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: _pickAndUploadAvatar,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.black87),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// ✅ 名稱輸入框
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: '名稱',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            _buildRoleDropdown(),
            _buildIdentityCodeField(),

            const SizedBox(height: 32),

            /// ✅ 儲存按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('儲存變更', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔴 登出按鈕
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('登出', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
