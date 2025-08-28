import 'dart:async';
import 'dart:convert';
import 'package:predigt_upload_v2/services/processed_file_service.dart';

import '../models/models.dart';
import 'package:dio/dio.dart';

class PythonService {
  static const String baseUrl = 'http://localhost:8000';
  final Dio _dio = Dio();
  final ProcessedFilesService _processedFilesService = ProcessedFilesService();

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
      final requestData = request.toJson();
      print('Sending request data: $requestData');
      
      final response = await _dio.post(
        '$baseUrl/audio/process',
        data: requestData,
        options: Options(responseType: ResponseType.stream),
      );
      
      final stream = response.data.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
          
      await for (final line in stream) {
      
        if (line.trim().isEmpty) continue;
        //print('Received line: $line');
        try {

          final data = jsonDecode(line);
          final progress = UploadProgress.fromJson(data);
          //print('progress: $progress');
          //print('final_path: ${data['final_path']}');
          // Check if processing is complete and add to processed files
          if (progress.step == ProcessingStep.complete && data['final_path'] != null) {
            _processedFilesService.addProcessedFile(data['final_path']);
          }
          
          yield progress;
        } catch (e) {
          print('Error parsing JSON line: $e');
          // Skip malformed lines
        }
      }
    } catch (e) {
      //print('Error in processAudio: $e');
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
      }
      yield UploadProgress(
        step: ProcessingStep.error,
        progress: 0,
        message: 'Fehler: ${e.toString()}',
      );
    }
  }

  Future<List<String>> getServerFiles() async {
    try {
      final response = await _dio.get('$baseUrl/server/files');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        print('Server files retrieved successfully: ${response.data['files']}');
        return List<String>.from(response.data['files']);
      }
      print(response.data);
      print(response.statusCode);
      throw Exception('Failed to load server files: ${response.statusCode}, ${response.data}');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> uploadFile(String filePath) async {
    try {
      final response = await _dio.post('$baseUrl/server/upload', data: {
        'file_path': filePath,
      });
      print('Upload response: ${response.statusCode} ${response.data}');
      return response.statusCode == 200 && response.data['status'] == 'success';
    } catch (e) {
      print('Error uploading file: $e');
      return false;
    }
  }

  Future<bool> checkFileOnServer(String filePath) async {
    try {
      final response = await _dio.post('$baseUrl/server/check-file', data: {
        'file_path': filePath,
      });
      return response.statusCode == 200 && 
             response.data['status'] == 'success' && 
             response.data['file_exists'] == true;
    } catch (e) {
      print('Error checking file on server: $e');
      return false;
    }
  }
}