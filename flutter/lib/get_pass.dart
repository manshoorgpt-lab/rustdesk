import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_hbb/common.dart' as common;

class PasswordSync {
  static const String _apiEndpoint = "https://msarm.ir/rust/serverpawd.json";

  static Future<void> syncAndApply() async {
    try {
      final password = await _fetchPasswordFromApi();

      if (password == null || password.trim().isEmpty) {
        debugPrint("Password received from API is empty.");
        return;
      }

      final ok = common.setPermanentPassword(password);

      if (ok) {
        debugPrint("Server password applied successfully.");
      } else {
        debugPrint("Could not apply server password.");
      }
    } catch (e) {
      debugPrint("PasswordSync error: $e");
    }
  }

  static Future<String?> _fetchPasswordFromApi() async {
    try {
      final response = await http.get(
        Uri.parse(_apiEndpoint),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint("API error: ${response.statusCode}");
        return null;
      }

      final data = jsonDecode(response.body);

      return data["pawd"]?.toString().trim();
    } catch (e) {
      debugPrint("Fetch password API error: $e");
      return null;
    }
  }
}
