import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../localization/translations.dart';

class LanguageConfigScreen extends StatefulWidget {
  final String language;
  const LanguageConfigScreen({super.key, required this.language});

  @override
  State<LanguageConfigScreen> createState() => _LanguageConfigScreenState();
}

class _LanguageConfigScreenState extends State<LanguageConfigScreen> {
  late String _tempLang;
  late Translations t;

  @override
  void initState() {
    super.initState();
    _tempLang = widget.language;
    t = Translations(_tempLang);
  }

  Future<void> _saveLanguage() async {
    if (_tempLang != widget.language) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', _tempLang);
      await Translations(_tempLang).load();
    }
    if (!mounted) return;
    // Devolvemos true si el idioma ha cambiado para refrescar la app
    Navigator.pop(context, _tempLang != widget.language);
  }

  @override
  Widget build(BuildContext context) {
    // Actualizamos las traducciones dinámicamente según la selección temporal
    t = Translations(_tempLang);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('language_config')),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildOption(t.get('lang_es'), 'es'), // Español
                _buildOption(t.get('lang_en'), 'en'), // Inglés
                _buildOption(t.get('lang_eu'), 'eu'), // Euskara
                _buildOption(t.get('lang_ca'), 'ca'), // Català
                _buildOption(t.get('lang_ga'), 'ga'), // Galego
                _buildOption(t.get('lang_it'), 'it'), // Italiano
                _buildOption(t.get('lang_pt'), 'pt'), // Português
                _buildOption(t.get('lang_fr'), 'fr'), // Français
                _buildOption(t.get('lang_de'), 'de'), // Deutsch
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: _saveLanguage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                t.get('save'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(
        label,
        style: const TextStyle(fontSize: 16),
      ),
      value: value,
      groupValue: _tempLang,
      activeColor: Theme.of(context).primaryColor,
      onChanged: (v) {
        setState(() {
          _tempLang = v!;
        });
      },
    );
  }
}