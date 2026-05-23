import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_hbb/models/platform_model.dart';

class ExternalConfigManager {
  static const String configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String backupPath = '/storage/emulated/0/rust/config.json';

  static final Map<String, String> _cachedConfig = {};

  static Future<Map<String, String>?> downloadConfig() async {
    try {
      debugPrint('Downloading config from: $configUrl');

      final response = await http
          .get(Uri.parse(configUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Config downloaded successfully');

        return {
          'custom-rendezvous-server': json['host']?.toString() ?? '',
          'relay-server': json['relay']?.toString() ?? '',
          'api-server': json['api']?.toString() ?? '',
          'key': json['key']?.toString() ?? '',
        };
      } else {
        debugPrint('Server returned: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  static Future<void> saveBackup(Map<String, String> config) async {
    try {
      final file = File(backupPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(config));
      debugPrint('Backup saved: $backupPath');
    } catch (e) {
      debugPrint('Backup save error: $e');
    }
  }

  static Future<Map<String, String>?> readBackup() async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        debugPrint('Backup loaded from: $backupPath');
        return json.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('Backup read error: $e');
    }
    return null;
  }

  static Future<void> writeToRustDeskConfig(
    Map<String, String> config,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/RustDesk2.toml');

      debugPrint('Writing to: ${configFile.path}');

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

      if (config['custom-rendezvous-server']?.isNotEmpty ?? false) {
        newLines.add(
          'custom-rendezvous-server = "${config['custom-rendezvous-server']}"',
        );
      }

      if (config['relay-server']?.isNotEmpty ?? false) {
        newLines.add('relay-server = "${config['relay-server']}"');
      }

      if (config['api-server']?.isNotEmpty ?? false) {
        newLines.add('api-server = "${config['api-server']}"');
      }

      if (config['key']?.isNotEmpty ?? false) {
        newLines.add('key = "${config['key']}"');
      }

      await configFile.writeAsString(newLines.join('\n'));
            debugPrint('RustDesk config file updated');
    } catch (e) {
      debugPrint('Config write error: $e');
    }
  }

  static Future<void> applyToRuntime() async {
    if (_cachedConfig.isEmpty) {
      debugPrint('Cached config empty, trying backup...');
      final backup = await readBackup();
      if (backup != null && backup.isNotEmpty) {
        _cachedConfig.addAll(backup);
      } else {
        debugPrint('No config available for runtime');
        return;
      }
    }

    for (final entry in _cachedConfig.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value.isEmpty) continue;

      try {
        if (value is String) {
          await ffiSetByName(key, value);
        } else {
          await ffiSetByName(key, value.toString());
        }
        debugPrint('Set runtime option: $key = $value');
      } catch (e) {
        debugPrint('Runtime set error for $key: $e');
      }
    }
  }

  static Future<void> initialize() async {
    try {
      debugPrint('ExternalConfigManager: Starting initialization...');

      Map<String, String>? config = await downloadConfig();

      if (config != null && config.isNotEmpty) {
        await saveBackup(config);
      } else {
        config ??= await readBackup();
      }

      if (config == null || config.isEmpty) {
        debugPrint('No config available');
        return;
      }

      await writeToRustDeskConfig(config);

      debugPrint('ExternalConfigManager initialized successfully');
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }
}
