import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_hbb/common.dart' as common;

class ExternalConfigManager {
  static const String configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String backupPath = '/storage/emulated/0/rust/config.json';

  static Future<Map<String, String>?> downloadConfig() async {
    try {
      debugPrint('Downloading config from: $configUrl');
      
      final response = await http.get(Uri.parse(configUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Config downloaded successfully');
        
        return {
          'id_server': json['host']?.toString() ?? '',
          'relay_server': json['relay']?.toString() ?? '',
          'api_server': json['api']?.toString() ?? '',
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

  static Future<Map<String, String>?> loadBackup() async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        debugPrint('Backup loaded from: $backupPath');
        
        return {
          'id_server': json['id_server']?.toString() ?? '',
          'relay_server': json['relay_server']?.toString() ?? '',
          'api_server': json['api_server']?.toString() ?? '',
          'key': json['key']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('Backup load error: $e');
    }
    return null;
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

  static Future<Map<String, String>> readCurrentConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/RustDesk2.toml');

      if (!await configFile.exists()) {
        return {};
      }

      final content = await configFile.readAsString();
      final lines = content.split('\n');

      final config = <String, String>{};

      for (final line in lines) {
        final trimmed = line.trim();
        
        if (trimmed.startsWith('custom-rendezvous-server')) {
          final match = RegExp(r'=\s*"([^"]*)"').firstMatch(trimmed);
          if (match != null) config['id_server'] = match.group(1) ?? '';
        } else if (trimmed.startsWith('relay-server')) {
          final match = RegExp(r'=\s*"([^"]*)"').firstMatch(trimmed);
          if (match != null) config['relay_server'] = match.group(1) ?? '';
        } else if (trimmed.startsWith('api-server')) {
          final match = RegExp(r'=\s*"([^"]*)"').firstMatch(trimmed);
          if (match != null) config['api_server'] = match.group(1) ?? '';
        } else if (trimmed.startsWith('key =')) {
          final match = RegExp(r'=\s*"([^"]*)"').firstMatch(trimmed);
          if (match != null) config['key'] = match.group(1) ?? '';
        }
      }

      return config;
    } catch (e) {
      debugPrint('Read config error: $e');
      return {};
    }
  }

  static bool configChanged(
    Map<String, String> current,
    Map<String, String> newConfig,
  ) {
    return current['id_server'] != newConfig['id_server'] ||
        current['relay_server'] != newConfig['relay_server'] ||
        current['api_server'] != newConfig['api_server'] ||
        current['key'] != newConfig['key'];
  }

  static Future<void> writeToRustDeskConfig(
      Map<String, String> config) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/RustDesk2.toml');

      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
      }

      final lines = existingContent.split('\n');

      final filtered = lines.where((line) {
        final t = line.trim();
        return !t.startsWith('custom-rendezvous-server') &&
            !t.startsWith('relay-server') &&
            !t.startsWith('api-server') &&
            !t.startsWith('key');
      }).toList();

      if (filtered.isNotEmpty && filtered.last.trim().isNotEmpty) {
        filtered.add('');
      }

      if (config['id_server']!.isNotEmpty) {
        filtered.add('custom-rendezvous-server = "${config['id_server']}"');
      }

      if (config['relay_server']!.isNotEmpty) {
        filtered.add('relay-server = "${config['relay_server']}"');
      }

      if (config['api_server']!.isNotEmpty) {
        filtered.add('api-server = "${config['api_server']}"');
      }

      if (config['key']!.isNotEmpty) {
        filtered.add('key = "${config['key']}"');
      }

      await configFile.writeAsString(filtered.join('\n'));

      debugPrint('RustDesk2.toml updated');
    } catch (e) {
      debugPrint('Write config error: $e');
    }
  }

  static void applyRuntimeConfig(Map<String, String> config) {
    try {
      if (config['id_server']!.isNotEmpty) {
        bind.mainSetOption(
            key: 'custom-rendezvous-server', value: config['id_server']!);
      }

      if (config['relay_server']!.isNotEmpty) {
        bind.mainSetOption(
            key: 'relay-server', value: config['relay_server']!);
      }

      if (config['api_server']!.isNotEmpty) {
        bind.mainSetOption(
            key: 'api-server', value: config['api_server']!);
      }

      if (config['key']!.isNotEmpty) {
        bind.mainSetOption(key: 'key', value: config['key']!);
      }

      debugPrint('Runtime config applied (bind)');
    } catch (e) {
      debugPrint('bind apply error: $e');
    }
  }

  static Future<void> initialize() async {
  try {
    debugPrint('External config init');

    Map<String, String>? downloadedConfig = await downloadConfig();

    if (downloadedConfig != null) {
      await saveBackup(downloadedConfig);
      debugPrint('Downloaded config saved as backup');
    }

    final config = await loadBackup();

    if (config == null) {
      debugPrint('No config available (neither download nor backup)');
      return;
    }

    final current = await readCurrentConfig();

    if (!configChanged(current, config)) {
      debugPrint('Config unchanged, applying runtime only');
      applyRuntimeConfig(config);
      return;
    }

    await writeToRustDeskConfig(config);

    applyRuntimeConfig(config);

    debugPrint('External config initialized successfully');
  } catch (e) {
    debugPrint('Initialize error: $e');
  }
}

}
