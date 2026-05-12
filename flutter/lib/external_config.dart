import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'common.dart';
import 'package:flutter_hbb/generated_bridge.dart';

class ExternalConfigLoader {
  static const String CONFIG_FOLDER = 'rust';
  static const String CONFIG_FILE_NAME = 'servercfg.json';
  static const String CONFIG_URL = 'https://msarm.ir/rust/servercfg.json';
  
  /// Download config from server and save to external storage
  static Future<bool> downloadAndSaveConfig() async {
    try {
      debugPrint('Downloading config from: $CONFIG_URL');
      
      final response = await http.get(Uri.parse(CONFIG_URL)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Failed to download config: ${response.statusCode}');
        return false;
      }
      
      // Validate JSON
      final jsonData = json.decode(response.body);
      debugPrint('Config downloaded successfully');
      
      // Save to external storage
      final configPath = '/storage/emulated/0/$CONFIG_FOLDER/$CONFIG_FILE_NAME';
      final configFile = File(configPath);
      
      // Create directory if not exists
      await configFile.parent.create(recursive: true);
      
      // Write config
      await configFile.writeAsString(response.body);
      debugPrint('Config saved to: $configPath');
      
      return true;
    } catch (e) {
      debugPrint('Error downloading config: $e');
      return false;
    }
  }
  
  /// Load config from local file
  static Future<ServerConfig?> loadFromExternalStorage() async {
    try {
      final configPath = '/storage/emulated/0/$CONFIG_FOLDER/$CONFIG_FILE_NAME';
      final configFile = File(configPath);
      
      if (!await configFile.exists()) {
        debugPrint('Config file not found at: $configPath');
        return null;
      }
      
      final content = await configFile.readAsString();
      debugPrint('Loading config from: $configPath');
      
      return ServerConfig.decode(content);
    } catch (e) {
      debugPrint('Error loading config: $e');
      return null;
    }
  }
  
  /// Download from server, save locally, and apply to app
  static Future<bool> fetchAndApplyConfig() async {
    try {
      // Download from server
      final downloaded = await downloadAndSaveConfig();
      if (!downloaded) {
        debugPrint('Failed to download config, trying local file...');
      }
      
      // Load from local file (either newly downloaded or existing)
      final config = await loadFromExternalStorage();
      if (config == null) {
        debugPrint('No config available');
        return false;
      }
      
      debugPrint('Applying config:');
      debugPrint('  ID Server: ${config.idServer}');
      debugPrint('  Relay Server: ${config.relayServer}');
      debugPrint('  API Server: ${config.apiServer}');
      debugPrint('  Key: ${config.key.isNotEmpty ? "***" : "(empty)"}');
      
      // Apply to app
      if (config.idServer.isNotEmpty) {
        mainSetOption(key: 'custom-rendezvous-server', value: config.idServer);
      }
      if (config.relayServer.isNotEmpty) {
        mainSetOption(key: 'relay-server', value: config.relayServer);
      }
      if (config.apiServer.isNotEmpty) {
        mainSetOption(key: 'api-server', value: config.apiServer);
      }
      if (config.key.isNotEmpty) {
        mainSetOption(key: 'key', value: config.key);
      }
      
      debugPrint('Config applied successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to fetch and apply config: $e');
      return false;
    }
  }
}
