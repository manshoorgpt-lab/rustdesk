import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/consts.dart';

class ExternalConfig {
  static const String configUrl = 'https://msarm.ir/rust/servercfg.json';
  static const String configPath = '/storage/emulated/0/rust/';
  static const String configFileName = 'config.json';
  static const String rustdeskConfigName = 'RustDesk2.toml';

  static Future<ServerConfig?> downloadConfig(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Config download failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);

      return ServerConfig(
        idServer: data['host'] ?? '',
        relayServer: data['relay'] ?? '',
        apiServer: data['api'] ?? '',
        key: data['key'] ?? '',
      );
    } catch (e) {
      print('downloadConfig error: $e');
      return null;
    }
  }

  static Future<void> saveConfigJson(ServerConfig config) async {
    try {
      final file = File(p.join(configPath, configFileName));

      final jsonData = {
        "id_server": config.idServer,
        "relay_server": config.relayServer,
        "api_server": config.apiServer,
        "key": config.key,
      };

      await file.writeAsString(jsonEncode(jsonData));
      print('Config saved to config.json');
    } catch (e) {
      print('saveConfigJson error: $e');
    }
  }

  static Future<void> writeRustDeskToml(ServerConfig config) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, rustdeskConfigName));

      String content = '';
      if (await file.exists()) {
        content = await file.readAsString();
      }

      final lines = content.split('\n');

      lines.removeWhere((line) {
        final t = line.trim();
        return t.startsWith('custom-rendezvous-server') ||
            t.startsWith('relay-server') ||
            t.startsWith('api-server') ||
            t.startsWith('key');
      });

      if (config.idServer.isNotEmpty) {
        lines.add('custom-rendezvous-server = "${config.idServer}"');
      }

      if (config.relayServer.isNotEmpty) {
        lines.add('relay-server = "${config.relayServer}"');
      }

      if (config.apiServer.isNotEmpty) {
        lines.add('api-server = "${config.apiServer}"');
      }

      if (config.key.isNotEmpty) {
        lines.add('key = "${config.key}"');
      }

      await file.writeAsString(lines.join('\n'));
      print('RustDesk2.toml updated');
    } catch (e) {
      print('writeRustDeskToml error: $e');
    }
  }

  static Future<void> applyMainOptions(ServerConfig config) async {
    try {
      if (config.idServer.isNotEmpty) {
        await bind.mainSetOption(
          key: 'custom-rendezvous-server',
          value: config.idServer,
        );
      }

      if (config.relayServer.isNotEmpty) {
        await bind.mainSetOption(
          key: 'relay-server',
          value: config.relayServer,
        );
      }

      if (config.apiServer.isNotEmpty) {
        await bind.mainSetOption(
          key: 'api-server',
          value: config.apiServer,
        );
      }

      if (config.key.isNotEmpty) {
        await bind.mainSetOption(
          key: 'key',
          value: config.key,
        );
      }

      print('mainSetOption applied');
    } catch (e) {
      print('applyMainOptions error: $e');
    }
  }

  static Future<ServerConfig> loadCurrentConfig() async {
    final options = await bind.mainGetOptions();
    return ServerConfig.fromOptions(options);
  }

  static Future<void> initialize(configUrl) async {
    try {
      final config = await downloadConfig(url);
      if (config == null) return;

      await saveConfigJson(config);
      await applyMainOptions(config);
      await writeRustDeskToml(config);

      // refresh options
      await bind.mainGetOptions();

      print('External config initialized');
    } catch (e) {
      print('initialize error: $e');
    }
  }
}
