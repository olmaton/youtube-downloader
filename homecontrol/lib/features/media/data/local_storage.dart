import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_media_entry.dart';

class LocalStorage {
  static const _key = 'local_media_entries';

  Future<List<LocalMediaEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List;
    final entries = list
        .map((e) => LocalMediaEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    // Filter out entries whose local file no longer exists
    return entries.where((e) => File(e.localPath).existsSync()).toList();
  }

  Future<void> saveEntry(LocalMediaEntry entry) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.jobId == entry.jobId);
    entries.insert(0, entry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteEntry(String jobId) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.jobId == jobId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
