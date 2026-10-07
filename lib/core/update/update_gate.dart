import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Account-independent update gate.
/// Stores only an app-generated anonymous installation id and app version.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  static const _installIdKey = 'mumin_install_id';
  static const _versionName = '0.20.8';
  static const _versionCode = 2028;
  static const _latestUrl =
      'https://mooreunivers.com.tr/media/mumin-duasi/updates/latest.json';
  static const _pingUrl =
      'https://mooreunivers.com.tr/media/mumin-duasi/updates/ping.txt';

  bool _checking = true;
  bool _mustUpdate = false;
  String? _downloadUrl;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<String> _installId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_installIdKey);
    if (saved != null && saved.length >= 20) return saved;
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final value = base64UrlEncode(bytes).replaceAll('=', '');
    await prefs.setString(_installIdKey, value);
    return value;
  }

  Future<void> _check() async {
    try {
      final installId = await _installId();
      final ping = Uri.parse(_pingUrl).replace(queryParameters: {
        'install_id': installId,
        'version': _versionName,
        'version_code': '$_versionCode',
        'event': 'open',
      });
      try {
        await http.get(ping).timeout(const Duration(seconds: 5));
      } catch (_) {}

      final response =
          await http.get(Uri.parse(_latestUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('latest_http_${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestCode = (data['versionCode'] as num?)?.toInt() ?? 0;
      final latestVersion = data['version']?.toString();
      final apkUrl = data['apkUrl']?.toString();
      final mandatory = data['mandatory'] == true;

      if (!mounted) return;
      setState(() {
        _mustUpdate = mandatory &&
            latestCode > _versionCode &&
            apkUrl != null &&
            apkUrl.isNotEmpty;
        _downloadUrl = apkUrl;
        _latestVersion = latestVersion;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    final raw = _downloadUrl;
    if (raw == null || raw.isEmpty) return;
    final installId = await _installId();
    final uri = Uri.parse(raw).replace(queryParameters: {
      'install_id': installId,
      'from': _versionName,
      'from_code': '$_versionCode',
      'event': 'update_download',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_mustUpdate) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_alt_rounded, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Zorunlu güncelleme',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mümin Duası ${_latestVersion ?? ''} sürümü hazır. '
                  'Devam etmek için uygulamayı güncelleyin.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Güncellemeyi indir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
