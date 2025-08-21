import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BackendService {
  Process? _process;

  Future<void> start() async {
    if (_process != null) {
      debugPrint("Backend process already running.");
      return;
    }

    String scriptPath;
    if (kDebugMode) {
      // In debug mode, we can use the relative path from the project root.
      scriptPath = 'backend\\run_backend.ps1';
    } else {
      print('USE PATH PROVIDER');
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      scriptPath = '$exeDir\\data\\flutter_assets\\backend\\run_backend.ps1';
    }

    if (!File(scriptPath).existsSync()) {
      debugPrint("ERROR: Backend script not found at $scriptPath");
      return;
    }

    debugPrint("Starting backend server...");
    try {
      _process = await Process.start(
        'powershell.exe',
        ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
        runInShell: true,
      );

      // Listen to stdout and stderr to see the server's output in the debug console.
      _process!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('BACKEND [stdout]: $data');
      });
      _process!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('BACKEND [stderr]: $data');
      });

      _process!.exitCode.then((code) {
        debugPrint('Backend process exited with code: $code');
        _process = null;
      });

    } catch (e) {
      debugPrint("Failed to start backend process: $e");
      _process = null;
    }
  }

  void stop() {
    if (_process != null) {
      debugPrint("Stopping backend server...");
      _process!.kill();
      _process = null;
    }
  }
}
