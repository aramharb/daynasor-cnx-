// Detects whether the device *really* has internet (not just a Wi-Fi link).
// Listens to connectivity changes, then confirms with a tiny probe request.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Force a mode for debugging: `flutter run --dart-define=NET=online|offline`
const String _kOverride = String.fromEnvironment('NET');

const List<String> _probeUrls = [
  'https://www.gstatic.com/generate_204',
  'https://www.google.com/favicon.ico',
  'https://cloudflare.com/favicon.ico',
];

class NetworkMonitor {
  NetworkMonitor({this.interval = const Duration(seconds: 12), this.timeout = const Duration(seconds: 4)});

  final Duration interval, timeout;

  /// null until the first check finishes.
  bool? online;

  /// Set to 'online' / 'offline' to force a mode (tests / debugging).
  String? override = _kOverride.isEmpty ? null : _kOverride;

  final List<void Function(bool online, bool? previous)> _listeners = [];
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;
  bool _checking = false;

  void addListener(void Function(bool online, bool? previous) cb) => _listeners.add(cb);

  void start() {
    try {
      _sub = Connectivity().onConnectivityChanged.listen((r) {
        if (r.contains(ConnectivityResult.none) && r.length == 1) {
          _set(false);
        } else {
          check();
        }
      }, onError: (_) {});
    } catch (_) {}
    check();
    _timer = Timer.periodic(interval, (_) => check());
  }

  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
  }

  void _set(bool v) {
    if (override != null) v = override == 'online';
    if (v == online) return;
    final prev = online;
    online = v;
    for (final cb in List.of(_listeners)) {
      cb(v, prev);
    }
  }

  Future<void> check() async {
    if (override != null) return _set(override == 'online');
    if (_checking) return;
    _checking = true;
    try {
      try {
        final r = await Connectivity().checkConnectivity();
        if (r.length == 1 && r.first == ConnectivityResult.none) return _set(false);
      } catch (_) {
        // plugin unavailable: fall through to the probe
      }
      for (final url in _probeUrls) {
        if (await _probe(url)) return _set(true);
      }
      _set(false);
    } finally {
      _checking = false;
    }
  }

  Future<bool> _probe(String url) async {
    try {
      await http.get(Uri.parse('$url?_=${DateTime.now().millisecondsSinceEpoch}')).timeout(timeout);
      return true; // any HTTP response means the internet works
    } catch (_) {
      return false;
    }
  }
}
