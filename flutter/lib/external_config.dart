import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_hbb/common.dart';

class ExternalConfigManager {
  static const String _configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String _backupFileName = 'server_config_backup.json';

  static Future<Map<String, String>?> downloadConfig() async {
    try {
      final response = await http.get(Uri.parse(_configUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return {
          'id-server': json['host']?.toString() ?? '',
          'relay-server': json['relay']?.toString() ?? '',
          'api-server': json['api']?.toString() ?? '',
          'key': json['key']?.toString() ?? '',
        };
      }
      debugPrint('Config download failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Config download error: $e');
      return null;
    }
  }

  static Future<void> saveBackup(Map<String, String> config) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _backupFileName));
      await file.writeAsString(jsonEncode(config));
      debugPrint('Backup saved');
    } catch (e) {
      debugPrint('Backup save error: $e');
    }
  }

  static Future<Map<String, String>?> readBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _backupFileName));
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        return json.map((key, value) => MapEntry(key, value.toString()));
      }
      return null;
    } catch (e) {
      debugPrint('Backup read error: $e');
      return null;
    }
  }

  static Future<void> writeToRustDeskConfig(Map<String, String> config) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'RustDesk2.toml'));

      String content = '';
      if (await file.exists()) {
        content = await file.readAsString();
      }

      config.forEach((key, value) {
        final regex = RegExp('^$key\\s*=.*\$', multiLine: true);
        final newLine = "$key = '$value'";
        if (regex.hasMatch(content)) {
          content = content.replaceAll(regex, newLine);
        } else {
          content += '\n$newLine';
        }
      });

      await file.writeAsString(content.trim() + '\n');
      debugPrint('RustDesk2.toml updated');
    } catch (e) {
      debugPrint('Config write error: $e');
    }
  }

  static Future<void> applyRuntimeConfig(Map<String, String> config) async {
    try {
      for (final entry in config.entries) {
        if (entry.value.isNotEmpty) {
          await mainSetOption(key: entry.key, value: entry.value);
        }
      }
      debugPrint('Runtime config applied');
    } catch (e) {
      debugPrint('Runtime config error: $e');
    }
  }

  static Future<void> initialize() async {
    debugPrint('ExternalConfigManager initializing...');

    Map<String, String>? config = await downloadConfig();

    if (config != null) {
      await saveBackup(config);
    } else {
      debugPrint('Using backup config...');
      config = await readBackup();
    }

    if (config != null) {
      await writeToRustDeskConfig(config);
      await applyRuntimeConfig(config);
      debugPrint('ExternalConfigManager done');
    } else {
      debugPrint('No config available (online or backup)');
    }
  }
}
