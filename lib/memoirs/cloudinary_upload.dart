import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String?> uploadImageToCloudinary(File imageFile) async {
  const cloudName = 'dftre2xh6';
  const uploadPreset = 'memoirs'; // 若使用 unsigned upload
  final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  final request = http.MultipartRequest('POST', uploadUrl)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = json.decode(responseBody);
    return data['secure_url'];
  } else {
    return null;
  }
}

Future<String?> uploadFileToCloudinary(File file, {required bool isImage}) async {
  const cloudName = 'dftre2xh6';
  const uploadPreset = 'memoirs';
  final uploadType = isImage ? 'image' : 'video'; // ⬅️ 音檔用 video
  final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$uploadType/upload');

  final request = http.MultipartRequest('POST', uploadUrl)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', file.path));

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = json.decode(responseBody);
    return data['secure_url'];
  } else {
    return null;
  }
}