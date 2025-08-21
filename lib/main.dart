import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/main_screen.dart';
import 'services/backend_service.dart';

const bool _manageBackend = false;

final backendService = _manageBackend ? BackendService() : null;

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  if (_manageBackend) {
    await backendService?.start();
  }

  // Set up window listener to stop the backend on close
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    center: true,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: PredigtenUploaderApp()));
}

class PredigtenUploaderApp extends ConsumerStatefulWidget {
  const PredigtenUploaderApp({super.key});

  @override
  ConsumerState<PredigtenUploaderApp> createState() => _PredigtenUploaderAppState();
}

class _PredigtenUploaderAppState extends ConsumerState<PredigtenUploaderApp> with WindowListener {

  @override
  void initState() {
    super.initState();
    if (_manageBackend) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (_manageBackend) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    if (_manageBackend) {
      backendService?.stop();
    }
    super.onWindowClose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Predigten Uploader',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}