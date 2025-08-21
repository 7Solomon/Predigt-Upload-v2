// widgets/config_drop_zone.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cross_file/cross_file.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

class ConfigDropZone extends ConsumerStatefulWidget {
  const ConfigDropZone({super.key});
  @override
  ConsumerState<ConfigDropZone> createState() => _ConfigDropZoneState();
}

class _ConfigDropZoneState extends ConsumerState<ConfigDropZone> {
  bool _isDragOver = false;
  
  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) => _handleFileDrop(details.files),
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isDragOver ? Colors.blue : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _isDragOver ? Colors.blue.withOpacity(0.1) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload,
              size: 48,
              color: _isDragOver ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('JSON-Datei hier ablegen'),
            const SizedBox(height: 8),
            TextButton(onPressed: _pickFile, child: const Text('oder Datei auswählen')),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result != null && result.files.single.path != null) {
      await _loadConfig(result.files.single.path!);
    }
  }
  
  Future<void> _handleFileDrop(List<XFile> files) async {
    setState(() => _isDragOver = false);
    
    if (files.isNotEmpty && files.first.name.endsWith('.json')) {
      await _loadConfig(files.first.path);
    }
  }
  
  Future<void> _loadConfig(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final config = AppConfig.fromJson(jsonDecode(content));
      
      // Save config (this will configure both Flutter and Backend)
      final configService = ref.read(configServiceProvider);
      final backendConfigured = await configService.saveConfig(config);
      
      // Update the app state
      final result = await ref.read(configProvider.notifier).setConfig(config);
      
      if (mounted) {
        if (result['success'] as bool) {
          final message = backendConfigured 
              ? '✅ Konfiguration erfolgreich geladen! Flutter und Backend sind konfiguriert.'
              : '⚠️  Konfiguration in Flutter geladen, aber Backend-Konfiguration fehlgeschlagen.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backendConfigured ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          final missingFields = (result['errors'] as List<String>).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Konfiguration unvollständig. Fehlende Felder: $missingFields'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
  } catch (e) {
      if (mounted) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}