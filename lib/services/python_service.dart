import 'dart:async';
import 'dart:convert';
import '../models/models.dart';
import 'package:dio/dio.dart';

class PythonService {
  static const String baseUrl = 'http://localhost:8000';
  final Dio _dio = Dio();

  Future<List<Livestream>> getLastLivestreams(int limit) async {
    print('get last live');
    //try {
      final response = await _dio.get('$baseUrl/youtube/livestreams', queryParameters: {'limit': limit});
      print('Response: ${response.statusCode} ${response.data}');
      if (response.statusCode != 200) {
        throw Exception('Failed to load livestreams');
      }
      return (response.data as List).map((e) => Livestream.fromJson(e)).toList();
     //}catch (_) {
      // Fallback dummy data
      //return List.generate(limit, (i) => Livestream(id: '$i', title: 'Dummy Stream $i', url: 'https://example.com/$i', length: 3_600_000));
    //}
  }

  Stream<UploadProgress> processAudio(ProcessingRequest request) async* {
    try {
      final response = await _dio.post(
        '$baseUrl/audio/process',
        data: request.toJson(),
        options: Options(responseType: ResponseType.stream),
      );
      final stream = response.data.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in stream) {
        if (line.trim().isEmpty) continue;
        final data = jsonDecode(line);
        yield UploadProgress.fromJson(data);
      }
    } catch (e) {
      // Emit simulated progression if backend unreachable
      final simulated = [
        (ProcessingStep.download, 20.0, 'Download abgeschlossen'),
        (ProcessingStep.compress, 60.0, 'Komprimierung abgeschlossen'),
        (ProcessingStep.tags, 80.0, 'Tags gesetzt'),
        (ProcessingStep.finalize, 90.0, 'Finalisierung...'),
        (ProcessingStep.complete, 100.0, 'Abgeschlossen'),
      ];
      for (final s in simulated) {
        await Future.delayed(const Duration(milliseconds: 400));
        yield UploadProgress(step: s.$1, progress: s.$2, message: s.$3);
      }
    }
  }
}