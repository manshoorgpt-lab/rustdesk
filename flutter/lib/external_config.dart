import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ExternalConfigManager {
  static const String configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String backupPath = '/storage/emulated/0/rust/config.json';

  /// Download config from server
  static Future<Map<String, dynamic>?> downloadConfig() async {
    try {
      debugPrint('Downloading config from: $configUrl');
      final response = await http.get(Uri.parse(configUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('Config downloaded successfully');
        return data;
      } else {
        debugPrint('Failed to download config: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading config: $e');
      return null;
    }
  }

  /// Save backup to external storage
  static Future<void> saveBackup(Map<String, dynamic> config) async {
    try {
      final file = File(backupPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(json.encode(config));
      debugPrint('Backup saved to: $backupPath');
    } catch (e) {
      debugPrint('Failed to save backup: $e');
    }
  }

  /// Write config directly to RustDesk2.toml
  static Future<void> writeToRustDeskConfig(Map<String, dynamic> config) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.parent.path}/files/RustDesk2.toml');

      debugPrint('Writing to RustDesk config: ${configFile.path}');

      // Read existing config
      String content = '';
      if (await configFile.exists()) {
        content = await configFile.readAsString();
      }

      // Parse TOML-like structure
      final lines = content.split('\n');
      final Map<String, String> configMap = {};

      for (var line in lines) {
        if (line.contains('=')) {
          final parts = line.split('=');
          if (parts.length == 2) {
            configMap[parts[0].trim()] = parts[1].trim();
          }
        }
      }

      // Update values from server config
      if (config.containsKey('id_server')) {
        configMap['custom-rendezvous-server'] = '"${config['id_server']}"';
      }
      if (config.containsKey('relay_server')) {
        configMap['relay-server'] = '"${config['relay_server']}"';
      }
      if (config.containsKey('api_server')) {
        configMap['api-server'] = '"${config['api_server']}"';
      }
      if (config.containsKey('key')) {
        configMap['key'] = '"${config['key']}"';
      }

      // Write back to file
      final newContent = configMap.entries
          .map((e) => '${e.key} = ${e.value}')
          .join('\n');

      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(newContent);

      debugPrint('RustDesk config updated successfully');
      debugPrint('  ID Server: ${config['id_server']}');
      debugPrint('  Relay Server: ${config['relay_server']}');
      debugPrint('  API Server: ${config['api_server']}');
      debugPrint('  Key: ${config['key']?.isNotEmpty == true ? "***" : "(empty)"}');
    } catch (e) {
      debugPrint('Failed to write RustDesk config: $e');
    }
  }

  /// Main initialization: download, backup, and apply config
  static Future<void> initialize() async {
    try {
      debugPrint('Starting external config initialization...');

      // Download from server
      final config = await downloadConfig();
      if (config == null) {
        debugPrint('No config downloaded, skipping initialization');
        return;
      }

      // Save backup
      await saveBackup(config)
	  // Apply to RustDesk config file
      await writeToRustDeskConfig(config);

      debugPrint('External config initialization completed');
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }
}
