import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:predigt_upload_v2/providers/app_state.dart';
import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../services/config_services.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _youtubeApiKeyController;
  late TextEditingController _channelIdController;
  late TextEditingController _ftpServerController;
  late TextEditingController _ftpUsernameController;
  late TextEditingController _ftpPasswordController;
  late TextEditingController _websiteUrlController;
  
  double _thresholdDb = -12;
  double _ratio = 2;
  double _attack = 200;
  double _release = 1000;
  
  bool _isLoading = false;
  Map<String, bool> _connectionStatus = {};
  
  // Add visibility state variables for password fields
  bool _youtubeApiKeyVisible = false;
  bool _ftpPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers first
    _youtubeApiKeyController = TextEditingController();
    _channelIdController = TextEditingController();
    _ftpServerController = TextEditingController();
    _ftpUsernameController = TextEditingController();
    _ftpPasswordController = TextEditingController();
    _websiteUrlController = TextEditingController();
    
    // Then populate them with config data
    _initializeControllers();
  }

  void _initializeControllers() {
    final config = ref.read(configProvider).config;
    
    // Update existing controllers with values
    _youtubeApiKeyController.text = config?.youtubeApiKey ?? '';
    _channelIdController.text = config?.channelId ?? '';
    _ftpServerController.text = config?.ftpHost ?? '';
    _ftpUsernameController.text = config?.ftpUser ?? '';
    _ftpPasswordController.text = config?.ftpPassword ?? '';
    _websiteUrlController.text = config?.websiteUrl ?? '';
    
    if (config != null) {
      setState(() {
        _thresholdDb = config.thresholdDb;
        _ratio = config.ratio;
        _attack = config.attack;
        _release = config.release;
      });
    }
  }
  @override
  void dispose() {
    _youtubeApiKeyController.dispose();
    _channelIdController.dispose();
    _ftpServerController.dispose();
    _ftpUsernameController.dispose();
    _ftpPasswordController.dispose();
    _websiteUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(configProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Einstellungen'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'import', child: Text('JSON importieren')),
              PopupMenuItem(value: 'export', child: Text('JSON exportieren')),
              PopupMenuItem(value: 'test', child: Text('Verbindungen testen')),
            ],
          ),
        ],
      ),
      body: configState.config != null 
          ? _buildSettingsForm(configState.config!)
          : _buildNotConfiguredView(),
      floatingActionButton: configState.config != null
          ? FloatingActionButton.extended(
              onPressed: _saveConfiguration,
              icon: Icon(Icons.save),
              label: Text('Speichern'),
            )
          : null,
    );
  }

  Widget _buildNotConfiguredView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'Keine Konfiguration gefunden',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 10),
          Text(
            'Importieren Sie eine JSON-Konfiguration um zu beginnen',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _handleMenuAction('import'),
            icon: Icon(Icons.upload_file),
            label: Text('JSON importieren'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsForm(AppConfig config) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Card
            if (_connectionStatus.isNotEmpty) _buildConnectionStatusCard(),
            
            // YouTube Settings
            _buildSection(
              'YouTube Einstellungen',
              Icons.video_library,
              [
                _buildTextField(
                  'YouTube API Key',
                  _youtubeApiKeyController,
                  obscureText: true,
                  fieldKey: 'youtube_api', // Add this
                  validator: (value) => value?.isEmpty == true ? 'API Key erforderlich' : null,
                ),
                _buildTextField(
                  'Channel ID',
                  _channelIdController,
                  validator: (value) => value?.isEmpty == true ? 'Channel ID erforderlich' : null,
                ),
              ],
            ),

            SizedBox(height: 20),

            // FTP Settings
            _buildSection(
              'FTP Server Einstellungen',
              Icons.cloud_upload,
              [
                _buildTextField(
                  'FTP Server',
                  _ftpServerController,
                  validator: (value) => value?.isEmpty == true ? 'FTP Server erforderlich' : null,
                ),
                _buildTextField(
                  'Benutzername',
                  _ftpUsernameController,
                  validator: (value) => value?.isEmpty == true ? 'Benutzername erforderlich' : null,
                ),
                _buildTextField(
                  'Passwort',
                  _ftpPasswordController,
                  obscureText: true,
                  fieldKey: 'ftp_password', // Add this
                  validator: (value) => value?.isEmpty == true ? 'Passwort erforderlich' : null,
                ),
              ],
            ),

            SizedBox(height: 20),

            // Website Settings
            _buildSection(
              'Website Einstellungen',
              Icons.web,
              [
                _buildTextField(
                  'Website URL (optional)',
                  _websiteUrlController,
                ),
              ],
            ),

            SizedBox(height: 20),

            // Audio Settings
            _buildSection(
              'Audio Komprimierung',
              Icons.audio_file,
              [
                _buildSlider(
                  'Threshold (dB)',
                  _thresholdDb,
                  -30,
                  0,
                  (value) => setState(() => _thresholdDb = value),
                ),
                _buildSlider(
                  'Ratio',
                  _ratio,
                  1,
                  10,
                  (value) => setState(() => _ratio = value),
                ),
                _buildSlider(
                  'Attack (ms)',
                  _attack,
                  50,
                  1000,
                  (value) => setState(() => _attack = value),
                ),
                _buildSlider(
                  'Release (ms)',
                  _release,
                  100,
                  3000,
                  (value) => setState(() => _release = value),
                ),
              ],
            ),

            SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.network_check, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Verbindungsstatus',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 12),
            ...(_connectionStatus.entries.map((entry) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.error,
                    color: entry.value ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(_getConnectionLabel(entry.key)),
                ],
              ),
            ))),
          ],
        ),
      ),
    );
  }

  String _getConnectionLabel(String key) {
    switch (key) {
      case 'backend': return 'Backend Server';
      case 'youtube': return 'YouTube API';
      case 'ftp': return 'FTP Server';
      default: return key;
    }
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    String? Function(String?)? validator,
    String? fieldKey, // Add this to identify which field
  }) {
    // Determine if this specific field should be obscured
    bool isObscured = obscureText;
    if (fieldKey != null) {
      switch (fieldKey) {
        case 'youtube_api':
          isObscured = obscureText && !_youtubeApiKeyVisible;
          break;
        case 'ftp_password':
          isObscured = obscureText && !_ftpPasswordVisible;
          break;
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isObscured,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: obscureText
              ? IconButton(
                  icon: Icon(
                    isObscured ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      switch (fieldKey) {
                        case 'youtube_api':
                          _youtubeApiKeyVisible = !_youtubeApiKeyVisible;
                          break;
                        case 'ftp_password':
                          _ftpPasswordVisible = !_ftpPasswordVisible;
                          break;
                      }
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / (max > 100 ? 10 : 1)).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import':
        _importConfiguration();
        break;
      case 'export':
        _exportConfiguration();
        break;
      case 'test':
        _testConnections();
        break;
    }
  }

  Future<void> _importConfiguration() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      
      print('📄 Imported JSON data: $jsonData'); // Debug log
      
      final config = AppConfig.fromJson(jsonData);
      print('📄 Parsed config - API Key: ${config.youtubeApiKey.isEmpty ? "EMPTY" : "SET"}'); // Debug log
      
      final configService = ConfigService();
      final success = await configService.saveConfig(config);
      
      if (success) {
        // Invalidate the provider to force a reload
        ref.invalidate(configProvider);
        
        // Add a small delay to ensure the provider has updated
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Update controllers with new values
        _initializeControllers();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konfiguration erfolgreich importiert'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Backend-Konfiguration fehlgeschlagen');
      }
    }
  } catch (e) {
    print('❌ Import error: $e'); // Debug log
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Import fehlgeschlagen: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isLoading = false);
  }
  }

  Future<void> _exportConfiguration() async {
    try {
      final config = ref.read(configProvider).config;
      if (config == null) {
        throw Exception('Keine Konfiguration zum Exportieren vorhanden');
      }

      final jsonString = jsonEncode(config.toJson());
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Konfiguration speichern',
        fileName: 'predigt_config_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konfiguration erfolgreich exportiert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export fehlgeschlagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testConnections() async {
    setState(() => _isLoading = true);
    
    try {
      final configService = ConfigService();
      final status = await configService.testConnections();
      
      setState(() => _connectionStatus = status);
      
      final allConnected = status.values.every((connected) => connected);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allConnected 
                ? 'Alle Verbindungen erfolgreich'
                : 'Einige Verbindungen fehlgeschlagen',
          ),
          backgroundColor: allConnected ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verbindungstest fehlgeschlagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newConfig = AppConfig(
        youtubeApiKey: _youtubeApiKeyController.text,
        channelId: _channelIdController.text,
        ftpHost: _ftpServerController.text,
        ftpUser: _ftpUsernameController.text,
        ftpPassword: _ftpPasswordController.text,
        websiteUrl: _websiteUrlController.text,
        thresholdDb: _thresholdDb,
        ratio: _ratio,
        attack: _attack,
        release: _release,
      );

      final configService = ConfigService();
      final success = await configService.saveConfig(newConfig);

      if (success) {
        ref.invalidate(configProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konfiguration erfolgreich gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Backend-Konfiguration fehlgeschlagen');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speichern fehlgeschlagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}