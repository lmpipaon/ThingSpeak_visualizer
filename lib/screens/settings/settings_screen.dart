// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/translations.dart';
import '../initial_loader.dart';
import 'api_keys_config_screen.dart';
import 'language_config_screen.dart'; // Asegúrate que el archivo se llame así en minúsculas

class SettingsScreen extends StatelessWidget {
  final String language;
  final List<String> userApiKeys;

  const SettingsScreen({
    super.key,
    required this.language,
    required this.userApiKeys,
  });

  Future<void> _resetConfig(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKeys');
    await prefs.remove('selected_language');
    await prefs.remove('favorites_list');

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const InitialLoader()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _navigate(BuildContext context, Widget screen) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => screen),
    );

    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations(language);

    return Scaffold(
      appBar: AppBar(title: Text(t.get('settings_title'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(t.get('api_keys_config')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(
              context,
              ApiKeysConfigScreen(language: language, userApiKeys: userApiKeys),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(t.get('language_config')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(
              context,
              LanguageConfigScreen(language: language),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: Text(t.get('reset_config_full')),
              onPressed: () => _showResetDialog(context, t),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, Translations t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('reset')),
        content: Text(t.get('reset_config_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.get('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetConfig(context);
            },
            child: Text(t.get('reset'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}