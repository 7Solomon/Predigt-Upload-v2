import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/step_progress_indicator.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final Livestream livestream;
  final String prediger;
  final String titel;

  final DateTime datum;
  
  const ProcessingScreen({super.key, 
    required this.livestream,
    required this.prediger,
    required this.titel,
    required this.datum,
  });
  
  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
  with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioProcessingProvider.notifier).startProcessing(
        ProcessingRequest(
          id: widget.livestream.id,
          prediger: widget.prediger,
          titel: widget.titel,
          datum: widget.datum,
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  
  @override
  Widget build(BuildContext context) {
    final processingState = ref.watch(audioProcessingProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verarbeitung'),
        automaticallyImplyLeading: !processingState.isProcessing,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _animationController.value * 2 * pi,
                          child: Icon(
                            _getStatusIcon(processingState.currentStep),
                            size: 48,
                            color: _getStatusColor(processingState.currentStep),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      processingState.currentStep.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      processingState.statusMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Progress Indicator
            LinearProgressIndicator(
              value: processingState.progress / 100,
              backgroundColor: Colors.grey[300],
              minHeight: 8,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '${processingState.progress.toInt()}%',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const Spacer(),
            
            // Step Indicators
            StepProgressIndicator(currentStep: processingState.currentStep, steps: ProcessingStep.values),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(ProcessingStep step) => switch (step) {
        ProcessingStep.download => Icons.download,
        ProcessingStep.compress => Icons.compress,
        ProcessingStep.tags => Icons.tag,
        ProcessingStep.finalize => Icons.build,
        ProcessingStep.complete => Icons.check_circle,
        ProcessingStep.error => Icons.error,
      };

  Color _getStatusColor(ProcessingStep step) => switch (step) {
        ProcessingStep.download => Colors.blue,
        ProcessingStep.compress => Colors.orange,
        ProcessingStep.tags => Colors.purple,
        ProcessingStep.finalize => Colors.teal,
        ProcessingStep.complete => Colors.green,
        ProcessingStep.error => Colors.red,
      };
}