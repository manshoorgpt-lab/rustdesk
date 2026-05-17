import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ExternalConfigManager {
  static const String configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String backupPath = '/storage/emulated/0/rust/config.json';

  // Download config from server
  static Future<Map<String, dynamic>?> downloadConfig() async {
    try {
      debugPrint('Downloading config from: $configUrl');

      final response = await http
          .get(Uri.parse(configUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('Config downloaded successfully');
        return data;
      }

      debugPrint('Download failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  // Save backup json externally
  static Future<void> saveBackup(Map<String, dynamic> config) async {
    try {
      final file = File(backupPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(json.encode(config));
      debugPrint('Backup saved: $backupPath');
    } catch (e) {
      debugPrint('Backup error: $e');
    }
  }

  // Write values to RustDesk2.toml
  static Future<void> writeToRustDeskConfig(
      Map<String, dynamic> config) async {
    try {
	  debugPrint('writeToRustDeskConfig start');
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.parent.path}/files/RustDesk2.toml');

      String content = '';
      if (await configFile.exists()) {
        content = await configFile.readAsString();
      }

      final lines = content.split('\n');
      final Map<String, String> map = {};

      for (var line in lines) {
        if (!line.contains('=')) continue;
        final parts = line.split('=');
        if (parts.length != 2) continue;
        map[parts[0].trim()] = parts[1].trim();
      }
	    debugPrint('host: ${config['host']}');
      if (config['host'] != null) {
        map['custom-rendezvous-server'] = '"${config['host']}"';
      }
	    debugPrint('relay: ${config['relay']}');
      if (config['relay'] != null) {
        map['relay-server'] = '"${config['relay']}"';
      }
	    debugPrint('api: ${config['api']}');
      if (config['api'] != null) {
        map['api-server'] = '"${config['api']}"';
      }
	    debugPrint('key: ${config['key']}');
      if (config['key'] != null) {
        map['key'] = '"${config['key']}"';
      }

      final newContent =
          map.entries.map((e) => '${e.key} = ${e.value}').join('\n');

      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(newContent);

      debugPrint('RustDesk config updated');
    } catch (e) {
      debugPrint('Write config error: $e');
    }
  }

  // Main initializer
  static Future<void> initialize() async {
    try {
      debugPrint('External config init start');

      final config = await downloadConfig();
      if (config == null) {
        debugPrint('No config received');
        return;
      }

      await saveBackup(config);
      await writeToRustDeskConfig(config);

      debugPrint('External config applied');
    } catch (e) {
      debugPrint('Initialize error: $e');
    }
  }
}
