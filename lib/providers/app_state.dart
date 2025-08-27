import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:predigt_upload_v2/services/processed_file_service.dart';
import '../models/models.dart';
import '../services/config_services.dart';
import '../services/python_service.dart';

// Config
class ConfigState {
  final AppConfig? config;
  const ConfigState(this.config);
  bool get isConfigured => config?.isValid == true;
}

class ConfigNotifier extends StateNotifier<ConfigState> {
  final ConfigService _service;
  ConfigNotifier(this._service) : super(const ConfigState(null)) {
    load();
  }
  Future<void> load() async {
    final cfg = await _service.loadConfig();
    state = ConfigState(cfg);
  }
  Future<Map<String, dynamic>> setConfig(AppConfig config) async {
    final errors = config.getValidationErrors();
    if (errors.isEmpty) {
      state = ConfigState(config);
      // Note: saveConfig is now handled by the caller (ConfigService.saveConfig)
      return {'success': true, 'errors': <String>[]};
    } else {
      return {'success': false, 'errors': errors};
    }
  }
}

final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());
final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  return ConfigNotifier(ref.read(configServiceProvider));
});

// Livestream list
final livestreamProvider = FutureProvider.family<List<Livestream>, int>((ref, limit) async {
  return PythonService().getLastLivestreams(limit);
});

// Processing progress
class AudioProcessingState {
  final ProcessingStep currentStep;
  final double progress;
  final String statusMessage;
  final bool isProcessing;
  final String? finalPath;
  const AudioProcessingState({
    required this.currentStep,
    required this.progress,
    required this.statusMessage,
    required this.isProcessing,
    this.finalPath,
  });
  AudioProcessingState copyWith({
    ProcessingStep? currentStep,
    double? progress,
    String? statusMessage,
    bool? isProcessing,
    String? finalPath,
  }) => AudioProcessingState(
    currentStep: currentStep ?? this.currentStep,
    progress: progress ?? this.progress,
    statusMessage: statusMessage ?? this.statusMessage,
    isProcessing: isProcessing ?? this.isProcessing,
    finalPath: finalPath ?? this.finalPath,
  );
  factory AudioProcessingState.initial() => const AudioProcessingState(
    currentStep: ProcessingStep.download,
    progress: 0,
    statusMessage: 'Bereit',
    isProcessing: false,
  );
}

class AudioProcessingNotifier extends StateNotifier<AudioProcessingState> {
  final PythonService _pythonService = PythonService();
  final Ref ref;

  AudioProcessingNotifier(this.ref) : super(AudioProcessingState.initial());
  Future<void> startProcessing(ProcessingRequest request) async {
    state = state.copyWith(isProcessing: true);
    
    await for (final progress in _pythonService.processAudio(request)) {
      state = state.copyWith(
        currentStep: progress.step,
        progress: progress.progress,
        statusMessage: progress.message,
      );
      
      // Handle completion and trigger navigation
      if (progress.step == ProcessingStep.complete) {
        state = state.copyWith(isProcessing: false);
        
        // Trigger navigation callback if set
        final navigationCallback = ref.read(navigationCallbackProvider);
        if (navigationCallback != null) {
          navigationCallback();
        }
        break;
      }
      
      if (progress.step == ProcessingStep.error) {
        state = state.copyWith(isProcessing: false);
        break;
      }
    }
  }
}

// Add a provider for navigation callback
final navigationCallbackProvider = StateProvider<VoidCallback?>((ref) => null);

final audioProcessingProvider = StateNotifierProvider<AudioProcessingNotifier, AudioProcessingState>(
  (ref) => AudioProcessingNotifier(ref),
);