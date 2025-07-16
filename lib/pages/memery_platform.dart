export 'memory_web.dart' if (dart.library.io) 'memory_mobile.dart';

abstract class MemoryPlatform {
  Future<void> startRecording();
  Future<Map<String, String?>> stopRecording();

  void downloadWebAudio(String url) {} // 預設為空（只有 Web 實作）
}

/// 工廠方法會由被 export 的檔案覆蓋，不應定義預設錯誤！⬇️ 請刪除這個：
/// MemoryPlatform getPlatformRecorder() => throw UnimplementedError();
