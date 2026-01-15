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
    t = Translations(_tempLang);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('language_config')),
      ),
      // Añadimos SafeArea para que respete el notch y la barra de estado
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildOption(t.get('lang_es'), 'es'),
                  _buildOption(t.get('lang_en'), 'en'),
                  _buildOption(t.get('lang_eu'), 'eu'),
                  _buildOption(t.get('lang_ca'), 'ca'),
                  _buildOption(t.get('lang_ga'), 'ga'),
                  _buildOption(t.get('lang_it'), 'it'),
                  _buildOption(t.get('lang_pt'), 'pt'),
                  _buildOption(t.get('lang_fr'), 'fr'),
                  _buildOption(t.get('lang_de'), 'de'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), // Margen inferior ajustado
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