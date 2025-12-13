import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/translations.dart';


// ======================================================
// PANTALLA DE CONFIGURACIÓN DE IDIOMA
// ======================================================
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
    final bool changed = _tempLang != widget.language;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _tempLang);

    if (!mounted) return;
    // Devolvemos 'true' solo si hubo un cambio real.
    Navigator.pop(context, changed); 
  }

  @override
  Widget build(BuildContext context) {
    t = Translations(_tempLang);

    return Scaffold(
      appBar: AppBar(title: Text(t.get('language_config'))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'es',
              groupValue: _tempLang,
              onChanged: (v) {
                setState(() {
                  _tempLang = v!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _tempLang,
              onChanged: (v) {
                setState(() {
                  _tempLang = v!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Euskara'),
              value: 'eu',
              groupValue: _tempLang,
              onChanged: (v) {
                setState(() {
                  _tempLang = v!;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveLanguage,
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
  }
}
