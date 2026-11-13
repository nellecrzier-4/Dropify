import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan perilaku aplikasi (selain tema & bahasa).
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _keyClipboard = 'set_clipboard';
  static const _keyConfirmDelete = 'set_confirm_delete';
  static const _keyConnections = 'set_connections';
  static const _keyNotifications = 'set_notifications';

  bool _clipboardDetect = true;
  bool _confirmDelete = true;
  int _connections = 8;
  bool _notifications = true;

  bool get clipboardDetect => _clipboardDetect;
  bool get confirmDelete => _confirmDelete;
  int get connections => _connections;
  bool get notifications => _notifications;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _clipboardDetect = prefs.getBool(_keyClipboard) ?? true;
    _confirmDelete = prefs.getBool(_keyConfirmDelete) ?? true;
    _connections = prefs.getInt(_keyConnections) ?? 8;
    _notifications = prefs.getBool(_keyNotifications) ?? true;
    notifyListeners();
  }

  Future<void> setClipboardDetect(bool value) async {
    _clipboardDetect = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyClipboard, value);
  }

  Future<void> setConfirmDelete(bool value) async {
    _confirmDelete = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConfirmDelete, value);
  }

  Future<void> setConnections(int value) async {
    _connections = value.clamp(2, 12);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyConnections, _connections);
  }

  Future<void> setNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
  }
}

/// Riwayat download yang tersimpan di perangkat.
class DownloadRecord {
  DownloadRecord({
    required this.name,
    required this.path,
    required this.size,
    required this.time,
  });

  final String name;
  final String path;
  final int size;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'size': size,
        'time': time.toIso8601String(),
      };

  static DownloadRecord? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString();
    final path = json['path']?.toString();
    if (name == null || path == null) return null;
    return DownloadRecord(
      name: name,
      path: path,
      size: (json['size'] as num?)?.toInt() ?? 0,
      time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class DownloadHistory extends ChangeNotifier {
  DownloadHistory._();

  static final DownloadHistory instance = DownloadHistory._();

  static const _key = 'download_history';
  static const int maxItems = 60;

  final List<DownloadRecord> items = <DownloadRecord>[];

  Future<void> load() async {
    List<String> raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getStringList(_key) ?? const [];
    } catch (_) {
      raw = const [];
    }
    items
      ..clear()
      ..addAll(raw
          .map((e) {
            try {
              final map = jsonDecode(e);
              if (map is Map<String, dynamic>) return DownloadRecord.fromJson(map);
            } catch (_) {}
            return null;
          })
          .whereType<DownloadRecord>());
    notifyListeners();
  }

  Future<void> add(DownloadRecord record) async {
    items.removeWhere((r) => r.path == record.path);
    items.insert(0, record);
    if (items.length > maxItems) items.removeRange(maxItems, items.length);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(DownloadRecord record) async {
    items.remove(record);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        items.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {
      // Penyimpanan tidak tersedia (mis. saat test) — riwayat tetap di memori.
    }
  }
}
