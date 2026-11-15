import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gofile_api.dart';

/// Status akun Gofile: token tersimpan, info akun, dan isi root folder.
class GofileController extends ChangeNotifier {
  GofileController({GofileApi? api}) : api = api ?? GofileApi();

  static const _prefToken = 'gofile_token';

  final GofileApi api;

  String? _token;
  GofileAccount? _account;
  List<GofileEntry> _entries = const [];
  List<GofileEntry>? _shareEntries;
  String? _shareName;
  String? _shareId;
  bool _loading = false;
  bool _linkSent = false;
  String? _error;

  String? get token => _token;
  GofileAccount? get account => _account;
  List<GofileEntry> get entries => _entries;
  List<GofileEntry> get shareEntries => _shareEntries ?? const [];
  String? get shareName => _shareName;
  bool get showingShare => _shareEntries != null;
  bool get loading => _loading;
  bool get linkSent => _linkSent;
  String? get error => _error;
  bool get loggedIn => _account != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefToken);
    if (saved != null && saved.isNotEmpty) {
      _token = saved;
      try {
        _account = await api.account(saved);
        await _loadEntries();
      } on GofileException {
        _token = null;
        _account = null;
      } catch (_) {
        _error = 'koneksi';
      }
    }
    notifyListeners();
  }

  /// Kirim tautan masuk ke email.
  Future<bool> sendLoginLink(String email) async {
    _error = null;
    _linkSent = false;
    notifyListeners();
    try {
      await api.requestLoginLink(email.trim());
      _linkSent = true;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is GofileException ? e.code : 'koneksi';
      notifyListeners();
      return false;
    }
  }

  /// Simpan token (dari tautan email atau token manual) lalu muat akun.
  Future<bool> useToken(String input) async {
    final token = GofileApi.tokenFromInput(input);
    if (token == null) {
      _error = 'token_tidak_valid';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final account = await api.account(token);
      _token = account.token;
      _account = account;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefToken, account.token);
      await _loadEntries();
      return true;
    } catch (e) {
      _error = e is GofileException ? e.code : 'koneksi';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_account == null) return;
    _loading = true;
    notifyListeners();
    await _loadEntries();
    _loading = false;
    notifyListeners();
  }

  Future<List<GofileEntry>> folder(String id) =>
      api.list(id, _token ?? '');

  Future<void> _loadEntries() async {
    final account = _account;
    if (account == null) return;
    try {
      _entries = await api.list(account.rootFolder, account.token);
      _error = null;
    } catch (e) {
      _error = e is GofileException ? e.code : 'koneksi';
    }
  }

  /// Buka link share Gofile (tanpa perlu akun).
  Future<bool> openShare(String input) async {
    final id = GofileApi.shareIdFromInput(input);
    if (id == null) {
      _error = 'link_tidak_valid';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final folder = await api.folder(id, token: _token);
      _shareId = id;
      _shareName = folder.name;
      _shareEntries = folder.entries;
      return true;
    } catch (e) {
      _error = e is GofileException ? e.code : 'koneksi';
      _shareEntries = null;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void closeShare() {
    _shareEntries = null;
    _shareName = null;
    _shareId = null;
    notifyListeners();
  }

  String? get shareId => _shareId;

  Future<void> logout() async {
    _token = null;
    _account = null;
    _entries = const [];
    _error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    notifyListeners();
  }
}
