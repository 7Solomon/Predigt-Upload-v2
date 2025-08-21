import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';

class ConfigService {
  static const String _configKey = 'app_config';
  static const String baseUrl = 'http://localhost:8000';
  final Dio _dio = Dio();

  /// Load configuration from local storage first, then sync with backend
  Future<AppConfig?> loadConfig() async {
    AppConfig? localConfig = await _loadFromPreferences();
    
    // Check if the loaded config is actually valid (not just placeholder values)
    if (localConfig != null && !localConfig.isValid) {
      print('🔧 Found config but it contains placeholder values, treating as not configured');
      await _clearInvalidConfig();
      return null;
    }
    
    // If we have valid local config, try to ensure backend is configured too
    if (localConfig != null) {
      await _ensureBackendConfigured(localConfig);
    }
    
    return localConfig;
  }

  /// Clear invalid configuration from local storage
  Future<void> _clearInvalidConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    print('🧹 Cleared invalid configuration from local storage');
  }

  /// Save configuration - this is the main method used by the JSON drop zone
  Future<bool> saveConfig(AppConfig config) async {
    // 1. Save to local storage first (always works)
    await _saveToPreferences(config);
    
    // 2. Configure the backend with the full config
    return await _configureBackend(config);
  }

  /// Configure backend with full configuration
  Future<bool> _configureBackend(AppConfig config) async {
    try {
      final response = await _dio.post('$baseUrl/config/setup', data: config.toJson());
      if (response.statusCode == 200) {
        print('✅ Backend configured successfully');
        return true;
      }
    } catch (e) {
      print('❌ Failed to configure backend: $e');
    }
    return false;
  }

  /// Ensure backend is configured if we have local config
  Future<void> _ensureBackendConfigured(AppConfig config) async {
    try {
      // Test if backend is working by checking the status endpoint
      final response = await _dio.get('$baseUrl/status');
      if (response.statusCode == 200) {
        final status = response.data;
        if (status['fully_configured'] == true) {
          print('✅ Backend already configured and working');
          return;
        } else {
          print('🔧 Backend not fully configured, configuring now...');
        }
      }
    } catch (e) {
      print('🔧 Backend not reachable, configuring when possible...');
    }
    
    // Always try to configure the backend with our local config
    await _configureBackend(config);
  }

  Future<AppConfig?> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final configString = prefs.getString(_configKey);
    if (configString != null) {
      return AppConfig.fromJson(jsonDecode(configString));
    }
    return null;
  }

  Future<void> _saveToPreferences(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }
}