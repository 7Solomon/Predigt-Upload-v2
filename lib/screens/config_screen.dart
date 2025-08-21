import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/config_drop_zone.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 24),
                  Text('Konfiguration laden', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  const Text('Bitte laden Sie Ihre Konfigurationsdatei (JSON) hoch.', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ConfigDropZone(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
