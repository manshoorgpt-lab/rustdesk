import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/generated_bridge.dart';

class ExternalConfigManager {
  static const String _configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String _backupPath = '/storage/emulated/0/rust/config.json';
  
  static RustdeskImpl? _bind;
  
  static void initialize(RustdeskImpl bind) {
    _bind = bind;
  }

  static Future<Map<String, String>?> downloadConfig() async {
    try {
      final response = await http.get(Uri.parse(_configUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return {
          'custom-rendezvous-server': json['host']?.toString() ?? '',
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
      final file = File(_backupPath);
      await file.writeAsString(jsonEncode(config));
      debugPrint('Backup saved');
    } catch (e) {
      debugPrint('Backup save error: $e');
    }
  }

  static Future<Map<String, String>?> readBackup() async {
    try {
      final file = File(_backupPath);
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

  static Future<void> applyRuntimeConfig(Map<String, String> config) async {
    if (_bind == null) {
      debugPrint('Error: bind not initialized');
      return;
    }
    
    try {
      for (final entry in config.entries) {
        if (entry.value.isNotEmpty) {
          await _bind!.mainSetOption(key: entry.key, value: entry.value);
          debugPrint('Set ${entry.key} = ${entry.value}');
        }
      }
      debugPrint('Runtime config applied successfully');
    } catch (e) {
      debugPrint('Runtime config error: $e');
    }
  }

  static Future<void> applyRuntimeConfigBatch(Map<String, String> config) async {
    if (_bind == null) {
      debugPrint('Error: bind not initialized');
      return;
    }
    
    try {
      final jsonString = jsonEncode(config);
      await _bind!.mainSetOptions(json: jsonString);
      debugPrint('Batch config applied: $jsonString');
    } catch (e) {
      debugPrint('Batch config error: $e');
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
