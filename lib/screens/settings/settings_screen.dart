import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/translations.dart';
import 'api_keys_config_screen.dart';
import 'language_config_screen.dart';
// Se elimina el import de about_screen.dart ya que no se usa aquí

import '../initial_loader.dart';

class SettingsScreen extends StatelessWidget {
  final String language;
  final List<String> userApiKeys;

  const SettingsScreen({super.key, required this.language, required this.userApiKeys});

  Future<void> _resetConfig(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKeys');
    await prefs.remove('language');

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const InitialLoader()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _navigateAndPropagateChange(BuildContext context, Widget screen) async {
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
          // Opción 1: Configuración de API Keys
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(t.get('api_keys_config')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateAndPropagateChange(
              context,
              ApiKeysConfigScreen(
                language: language,
                userApiKeys: userApiKeys,
              ),
            ),
          ),
          const Divider(),
          // Opción 2: Configuración de Idioma
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(t.get('language_config')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateAndPropagateChange(
              context,
              LanguageConfigScreen(language: language),
            ),
          ),
          const Divider(),
          
          // LA OPCIÓN DE "ACERCA DE" HA SIDO ELIMINADA DE AQUÍ
          
          // Opción 3: Resetear Configuración
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  label: Text(t.get('reset_config_full')),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.get('reset')),
                        content: Text(t.get('reset_config_warning')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _resetConfig(context);
                            },
                            child: const Text('Resetear'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}