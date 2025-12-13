import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/translations.dart';


// ======================================================
// PANTALLA DE CONFIGURACIÓN DE API KEYS
// ======================================================
class ApiKeysConfigScreen extends StatefulWidget {
  final String language;
  final List<String> userApiKeys;

  const ApiKeysConfigScreen({
    super.key,
    required this.language,
    required this.userApiKeys,
  });

  @override
  State<ApiKeysConfigScreen> createState() => _ApiKeysConfigScreenState();
}

class _ApiKeysConfigScreenState extends State<ApiKeysConfigScreen> {
  late final TextEditingController _apiController;
  late final Translations t;

  @override
  void initState() {
    super.initState();
    t = Translations(widget.language);
    _apiController = TextEditingController(text: widget.userApiKeys.join(','));
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKeys() async {
    final keys = _apiController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (keys.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce al menos una API Key.')),
      );
      return;
    }
    
    // Verificar si las claves realmente cambiaron
    final bool changed = !listEquals(keys, widget.userApiKeys);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('apiKeys', keys);

    if (!mounted) return;
    // Devolvemos 'true' solo si hubo un cambio real.
    Navigator.pop(context, changed); 
  }
  
  // Función de ayuda para comparar listas
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.get('api_keys_config'))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _apiController,
              decoration: InputDecoration(
                labelText: t.get('api_keys'),
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveApiKeys,
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
  }
}