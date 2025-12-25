import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chart_source_selector_screen.dart';
import '../localization/translations.dart';

class InitialLoader extends StatefulWidget {
  const InitialLoader({super.key});

  @override
  State<InitialLoader> createState() => _InitialLoaderState();
}

class _InitialLoaderState extends State<InitialLoader> {
  // 1. CAMBIO AQUÍ: Inicialización a 'en'
  String language = 'en'; 
  List<String> userApiKeys = [];
  bool _isLoading = true;

  final TextEditingController _apiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    // --- AÑADE ESTA LÍNEA SOLO UNA VEZ ---
     //await prefs.remove('favorites_list'); 
    // -------------------------------------
    // 2. CAMBIO AQUÍ: Fallback de SharedPreferences a 'en'

// Esto simula un 'cat' imprimiendo el contenido en tu terminal de Flutter
  List<String>? rawFavs = prefs.getStringList('favorites_list');
  
  print("========= CONTENIDO DEL REGISTRO (FAVORITOS) =========");
  if (rawFavs == null || rawFavs.isEmpty) {
    print("El registro está vacío o la clave no existe.");
  } else {
    for (var f in rawFavs) {
      print(f); // Aquí verás el JSON puro
    }
  }
  print("======================================================");


    language = prefs.getString('language') ?? 'en'; 
    userApiKeys = prefs.getStringList('apiKeys') ?? [];
    _apiController.text = userApiKeys.join(',');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (userApiKeys.isEmpty) {
        setState(() => _isLoading = false);
        _showInitialConfig();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChartSourceSelectorScreen(
              language: language,
              userApiKeys: userApiKeys,
            ),
          ),
        );
      }
    });
  }

  Future<void> _showInitialConfig() async {
    String tempLang = language;
    Translations t = Translations(tempLang);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          t = Translations(tempLang);
          return AlertDialog(
            title: Text(t.get('initial_config')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _apiController,
                  decoration: InputDecoration(labelText: t.get('api_keys')),
                ),
                const SizedBox(height: 10),
                for (final lang in const [
                  // 3. CAMBIO AQUÍ: Poner 'en' primero y cambiar el texto 'Español' si quieres.
                  {'id': 'en', 'label': 'English'},
                  {'id': 'es', 'label': 'Español'}, 
                  {'id': 'eu', 'label': 'Euskara'},
                ])
                  RadioListTile<String>(
                    title: Text(lang['label']!),
                    value: lang['id']!,
                    groupValue: tempLang,
                    onChanged: (v) => setDialogState(() => tempLang = v!),
                  ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  final keys = _apiController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  Navigator.pop(context, {
                    'apiKeys': keys,
                    'language': tempLang,
                  });
                },
                child: Text(t.get('save')),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('apiKeys', result['apiKeys']);
      await prefs.setString('language', result['language']);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChartSourceSelectorScreen(
            language: result['language'],
            userApiKeys: result['apiKeys'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading ? const CircularProgressIndicator() : const SizedBox(),
      ),
    );
  }
}