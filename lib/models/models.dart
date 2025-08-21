import 'dart:convert';

class AppConfig {
  final String youtubeApiKey;
  final String channelId;
  final String ftpHost;
  final String ftpUser;
  final String ftpPassword;
  final String websiteUrl;
  final double thresholdDb;
  final double ratio;
  final double attack;
  final double release;

  const AppConfig({
    required this.youtubeApiKey,
    required this.channelId,
    required this.ftpHost,
    required this.ftpUser,
    required this.ftpPassword,
    required this.websiteUrl,
    required this.thresholdDb,
    required this.ratio,
    required this.attack,
    required this.release,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return AppConfig(
      youtubeApiKey: json['YOUTUBE_API_KEY'] ?? '',
      channelId: json['channel_id'] ?? '',
      ftpHost: json['server'] ?? '',   
      ftpUser: json['name'] ?? '',      
      ftpPassword: json['password'] ?? '',  
      websiteUrl: json['website_url'] ?? '',
      thresholdDb: parseDouble(json['threshold_db']),
      ratio: parseDouble(json['ratio']),
      attack: parseDouble(json['attack']),
      release: parseDouble(json['release']),
    );
  }

  // Only return non-sensitive data for API calls
  Map<String, dynamic> toNonSensitiveJson() => {
    'threshold_db': thresholdDb,
    'ratio': ratio,
    'attack': attack,
    'release': release,
  };

  // Full JSON for local storage only
  Map<String, dynamic> toJson() => {
    'YOUTUBE_API_KEY': youtubeApiKey,
    'channel_id': channelId,
    'server': ftpHost,
    'name': ftpUser,
    'password': ftpPassword,
    'website_url': websiteUrl,
    'threshold_db': thresholdDb,
    'ratio': ratio,
    'attack': attack,
    'release': release,
  };

  List<String> getValidationErrors() {
    final errors = <String>[];
    
    // Check for empty values
    if (youtubeApiKey.isEmpty) errors.add('YOUTUBE_API_KEY');
    if (channelId.isEmpty) errors.add('channel_id');
    if (ftpHost.isEmpty) errors.add('server (FTP Host)');
    if (ftpUser.isEmpty) errors.add('name (FTP User)');
    if (ftpPassword.isEmpty) errors.add('password (FTP Password)');
    
    // Check for placeholder values that indicate unconfigured state
    if (youtubeApiKey == 'YOUR_API_KEY_HERE' || youtubeApiKey == 'YOUR_ACTUAL_YOUTUBE_API_KEY_HERE') {
      errors.add('YOUTUBE_API_KEY (still placeholder)');
    }
    if (channelId == 'YOUR_YOUTUBE_CHANNEL_ID_HERE') {
      errors.add('channel_id (still placeholder)');
    }
    if (ftpHost == 'ftp.example.com') {
      errors.add('server (still placeholder)');
    }
    if (ftpUser == 'your_ftp_username') {
      errors.add('name (still placeholder)');
    }
    if (ftpPassword == 'your_ftp_password') {
      errors.add('password (still placeholder)');
    }
    
    return errors;
  }

  bool get isValid => getValidationErrors().isEmpty;
}

class Livestream {
  final String id;
  final String title;
  final String url;
  final int length; // milliseconds
  const Livestream({required this.id, required this.title, required this.url, required this.length});
  factory Livestream.fromJson(Map<String, dynamic> json) => Livestream(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    url: json['url'] ?? '',
    length: json['length'] ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'length': length,
  };
}

enum ProcessingStep { download, compress, tags, finalize, complete }

extension ProcessingStepX on ProcessingStep {
  String get displayName => switch (this) {
    ProcessingStep.download => 'Download',
    ProcessingStep.compress => 'Komprimieren',
    ProcessingStep.tags => 'Tags setzen',
    ProcessingStep.finalize => 'Finalisieren',
    ProcessingStep.complete => 'Abgeschlossen',
  };
}

class ProcessingRequest {
  final String url;
  final String prediger;
  final String titel;
  final DateTime datum;
  ProcessingRequest({required this.url, required this.prediger, required this.titel, required this.datum});
  Map<String, dynamic> toJson() => {
    'url': url,
    'prediger': prediger,
    'titel': titel,
    'datum': datum.toIso8601String(),
  };
}

class UploadProgress {
  final ProcessingStep step;
  final double progress; // 0 - 100
  final String message;
  final String? finalPath;
  UploadProgress({required this.step, required this.progress, required this.message, this.finalPath});
  factory UploadProgress.fromJson(Map<String, dynamic> json) => UploadProgress(
    step: _parseStep(json['step']),
    progress: (json['progress'] ?? 0).toDouble(),
    message: json['message'] ?? '',
    finalPath: json['final_path'],
  );
  static ProcessingStep _parseStep(String? value) {
    return ProcessingStep.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProcessingStep.download,
    );
  }
}
