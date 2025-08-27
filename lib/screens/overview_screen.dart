import 'package:flutter/material.dart';
import 'package:predigt_upload_v2/services/processed_file_service.dart';
import '../services/python_service.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with TickerProviderStateMixin {
  final PythonService _pythonService = PythonService();
  final ProcessedFilesService _processedFilesService = ProcessedFilesService();
  
  List<String> serverFiles = [];
  bool isLoadingServer = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadServerFiles();
    
    // Listen to processed files service
    _processedFilesService.addListener(_onProcessedFilesChanged);
  }

  @override
  void dispose() {
    _processedFilesService.removeListener(_onProcessedFilesChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onProcessedFilesChanged() {
    setState(() {}); // Refresh UI when processed files change
  }

  Future<void> _loadServerFiles() async {
    setState(() => isLoadingServer = true);
    try {
      final files = await _pythonService.getServerFiles();
      setState(() => serverFiles = files);
    } catch (e) {
      _showErrorSnackBar('Fehler beim Laden der Server-Dateien: $e');
    } finally {
      setState(() => isLoadingServer = false);
    }
  }

  Future<void> _uploadToServer(ProcessedFile file) async {
    try {
      final success = await _pythonService.uploadFile(file.path);
      if (success) {
        _processedFilesService.markAsUploaded(file.path);
        _showSuccessSnackBar('Datei erfolgreich hochgeladen');
        _loadServerFiles(); // Refresh server files
      } else {
        _showErrorSnackBar('Fehler beim Hochladen der Datei');
      }
    } catch (e) {
      _showErrorSnackBar('Fehler beim Hochladen: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dateien-Übersicht'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Verarbeitete Dateien', icon: Icon(Icons.audio_file)),
            Tab(text: 'Server-Dateien', icon: Icon(Icons.cloud)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadServerFiles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProcessedFilesView(),
          _buildServerFilesView(),
        ],
      ),
    );
  }

  Widget _buildProcessedFilesView() {
    final processedFiles = _processedFilesService.processedFiles;
    
    if (processedFiles.isEmpty) {
      return const Center(
        child: Text('Keine verarbeiteten Dateien vorhanden'),
      );
    }

    return ListView.builder(
      itemCount: processedFiles.length,
      itemBuilder: (context, index) {
        final file = processedFiles[index];
        
        return ListTile(
          leading: Icon(
            file.isUploadedToServer ? Icons.cloud_done : Icons.audio_file,
            color: file.isUploadedToServer ? Colors.green : Colors.blue,
          ),
          title: Text(file.name),
          subtitle: Text(
            file.isUploadedToServer 
              ? 'Hochgeladen • ${_formatDateTime(file.processedAt)}'
              : 'Bereit zum Hochladen • ${_formatDateTime(file.processedAt)}',
          ),
          trailing: file.isUploadedToServer 
            ? null 
            : IconButton(
                icon: const Icon(Icons.cloud_upload),
                onPressed: () => _uploadToServer(file),
              ),
        );
      },
    );
  }

  Widget _buildServerFilesView() {
    if (isLoadingServer) {
      return const Center(child: CircularProgressIndicator());
    }

    if (serverFiles.isEmpty) {
      return const Center(
        child: Text('Keine Dateien auf dem Server gefunden'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadServerFiles,
      child: ListView.builder(
        itemCount: serverFiles.length,
        itemBuilder: (context, index) {
          final fileName = serverFiles[index];
          
          return ListTile(
            leading: const Icon(Icons.cloud_done, color: Colors.green),
            title: Text(fileName),
            subtitle: const Text('Auf Server verfügbar'),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}