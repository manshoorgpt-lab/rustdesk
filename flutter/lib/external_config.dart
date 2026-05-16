import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ExternalConfigManager {
  static const String configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String backupPath = '/storage/emulated/0/rust/config.json';

  static Future<Map<String, String>?> downloadConfig() async {
    try {
      debugPrint(' Downloading config from: $configUrl');
      
      final response = await http.get(Uri.parse(configUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(' Config downloaded successfully');
        
        return {
          'id_server': json['host']?.toString() ?? '',
          'relay_server': json['relay']?.toString() ?? '',
          'api_server': json['api']?.toString() ?? '',
          'key': json['key']?.toString() ?? '',
        };
      } else {
        debugPrint(' Server returned: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint(' Download error: $e');
      return null;
    }
  }

  static Future<void> saveBackup(Map<String, String> config) async {
    try {
      final file = File(backupPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(config));
      debugPrint(' Backup saved: $backupPath');
    } catch (e) {
      debugPrint(' Backup error: $e');
    }
  }

  static Future<void> writeToRustDeskConfig(Map<String, String> config) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/RustDesk2.toml');

      debugPrint('📝 Writing to: ${configFile.path}');

      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
      }

      final lines = existingContent.split('\n');
      final filteredLines = lines.where((line) {
        final trimmed = line.trim();
        return !trimmed.startsWith('custom-rendezvous-server') &&
               !trimmed.startsWith('relay-server') &&
               !trimmed.startsWith('api-server') &&
               !trimmed.startsWith('key =');
      }).toList();

      final newLines = <String>[];
      
      if (filteredLines.isNotEmpty && filteredLines.last.trim().isNotEmpty) {
        newLines.addAll(filteredLines);
        newLines.add(''); 
      } else {
        newLines.addAll(filteredLines);
      }

      if (config['id_server']?.isNotEmpty ?? false) {
        newLines.add('custom-rendezvous-server = "${config['id_server']}"');
      }
      
      if (config['relay_server']?.isNotEmpty ?? false) {
        newLines.add('relay-server = "${config['relay_server']}"');
      }
      
      if (config['api_server']?.isNotEmpty ?? false) {
        newLines.add('api-server = "${config['api_server']}"');
      }
      
      if (config['key']?.isNotEmpty ?? false) {
        newLines.add('key = "${config['key']}"');
      }

      await configFile.writeAsString(newLines.join('\n'));

      debugPrint('   RustDesk config updated');
      debugPrint('   - ID Server: ${config['id_server']}');
      debugPrint('   - Relay: ${config['relay_server']}');
      debugPrint('   - API: ${config['api_server']}');
      debugPrint('   - Key: ${config['key']?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('  Config write error: $e');
    }

      static Future<void> initialize() async {
        try {
          final config = await downloadConfig();

          if (config == null) {
            debugPrint(' Failed to load config');
            return;
          }

          await saveBackup(config);

          await writeToRustDeskConfig(config);

          debugPrint(' External config initialized');
        } catch (e) {
          debugPrint(' Initialize error: $e');
        }
      }
  }
  
