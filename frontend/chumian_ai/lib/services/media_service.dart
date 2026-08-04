import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  Future<Map<String, dynamic>> generateImage({
    required String prompt,
    String? size,
  }) async {
    return await ApiClient().post('/api/media/images', body: {
      'prompt': prompt,
      'size': size,
    });
  }

  Future<Map<String, dynamic>> generateVideo({
    required String prompt,
    String? imageUrl,
    String? size,
  }) async {
    return await ApiClient().post('/api/media/videos', body: {
      'prompt': prompt,
      'image_url': imageUrl,
      'size': size,
    });
  }

  Future<Map<String, dynamic>> getVideoTask(String taskId) async {
    return await ApiClient().get('/api/media/videos/$taskId');
  }

  Future<Map<String, dynamic>> uploadFile(File file) async {
    return await ApiClient().upload('/api/media/upload', file);
  }

  Future<File?> downloadImage(String url, {String? filename}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final name = filename ?? '${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }
}
