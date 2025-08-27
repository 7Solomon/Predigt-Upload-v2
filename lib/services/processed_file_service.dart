import 'dart:async';
import 'package:flutter/foundation.dart';

class ProcessedFile {
  final String path;
  final String fileName;
  final DateTime processedAt;
  bool isUploadedToServer;

  ProcessedFile({
    required this.path,
    required this.fileName,
    required this.processedAt,
    this.isUploadedToServer = false,
  });

  String get name => fileName.split('\\').last.split('/').last;
}

class ProcessedFilesService extends ChangeNotifier {
  static final ProcessedFilesService _instance = ProcessedFilesService._internal();
  factory ProcessedFilesService() => _instance;
  ProcessedFilesService._internal();

  final List<ProcessedFile> _processedFiles = [];
  final StreamController<ProcessedFile> _newFileController = StreamController<ProcessedFile>.broadcast();

  List<ProcessedFile> get processedFiles => List.unmodifiable(_processedFiles);
  Stream<ProcessedFile> get newFileStream => _newFileController.stream;

  void addProcessedFile(String filePath) {
    final fileName = filePath.split('\\').last.split('/').last;
    final processedFile = ProcessedFile(
      path: filePath,
      fileName: fileName,
      processedAt: DateTime.now(),
    );
    
    _processedFiles.insert(0, processedFile);
    _newFileController.add(processedFile);
    notifyListeners();
  }

  void markAsUploaded(String filePath) {
    final index = _processedFiles.indexWhere((file) => file.path == filePath);
    if (index != -1) {
      _processedFiles[index].isUploadedToServer = true;
      notifyListeners();
    }
  }

  void removeProcessedFile(String filePath) {
    _processedFiles.removeWhere((file) => file.path == filePath);
    notifyListeners();
  }

  @override
  void dispose() {
    _newFileController.close();
    super.dispose();
  }
}