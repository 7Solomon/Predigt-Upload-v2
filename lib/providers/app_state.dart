import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  AudioProcessingNotifier() : super(AudioProcessingState.initial());

  Future<void> startProcessing(ProcessingRequest request) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true, statusMessage: 'Starte Download...');
    // Placeholder simulated progression
    final steps = [
      (ProcessingStep.download, 20.0, 'Download abgeschlossen'),
      (ProcessingStep.compress, 60.0, 'Komprimierung abgeschlossen'),
      (ProcessingStep.tags, 80.0, 'Tags gesetzt'),
      (ProcessingStep.finalize, 90.0, 'Finalisierung...'),
      (ProcessingStep.complete, 100.0, 'Abgeschlossen'),
    ];
    for (final s in steps) {
      await Future.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(
        currentStep: s.$1,
        progress: s.$2,
        statusMessage: s.$3,
        isProcessing: s.$1 != ProcessingStep.complete,
      );
    }
  }
}

final audioProcessingProvider = StateNotifierProvider<AudioProcessingNotifier, AudioProcessingState>((ref) {
  return AudioProcessingNotifier();
});