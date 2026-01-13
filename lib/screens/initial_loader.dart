import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'chart_source_selector_screen.dart';
import '../localization/translations.dart';

class InitialLoader extends StatefulWidget {
  const InitialLoader({super.key});

  @override
  State<InitialLoader> createState() => _InitialLoaderState();
}

class _InitialLoaderState extends State<InitialLoader> {
  // Inicialización a 'en' por defecto
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
    
    // Debug de favoritos en consola
    List<String>? rawFavs = prefs.getStringList('favorites_list');
    print("========= CONTENIDO DEL REGISTRO (FAVORITOS) =========");
    if (rawFavs == null || rawFavs.isEmpty) {
      print("El registro está vacío o la clave no existe.");
    } else {
      for (var f in rawFavs) {
        print(f); 
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
    // Creamos una instancia local de traducciones
    Translations t = Translations(tempLang);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Actualizamos la instancia de traducción si cambia el idioma en el diálogo
          t = Translations(tempLang);
          
          return AlertDialog(
            title: Text(t.get('initial_config')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
TextField(
  controller: _apiController,
  decoration: InputDecoration(
    labelText: t.get('api_keys'),
    hintText: "Key1, Key2...",
    // El borde ayuda a delimitar el espacio y hace que el icono resalte
    border: const OutlineInputBorder(), 
    // Esto coloca el icono dentro del cuadro, a la derecha
    suffixIcon: Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
        icon: const Icon(Icons.help_outline, color: Colors.blue, size: 30),
        onPressed: () => _showApiHelpDialog(context, t),
      ),
    ),
  ),
),
                  const SizedBox(height: 20),
                  for (final lang in const [
                    {'id': 'en', 'label': 'English'},
                    {'id': 'es', 'label': 'Español'}, 
                    {'id': 'eu', 'label': 'Euskara'},
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(lang['label']!),
                      value: lang['id']!,
                      groupValue: tempLang,
                      onChanged: (v) {
                        setDialogState(() => tempLang = v!);
                      },
                    ),
                ],
              ),
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
      body: SafeArea(
        child: Center(
          child: _isLoading 
              ? const CircularProgressIndicator() 
              : const SizedBox(),
        ),
      ),
    );
  }

  // --- FUNCIÓN DE AYUDA INTEGRADA ---
  void _showApiHelpDialog(BuildContext context, Translations t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: Colors.blue),
            const SizedBox(width: 10),
            Text(t.get('api_keys')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Puedes introducir varias llaves separadas por comas:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            _helpItem("Read API Key", "Para leer datos de tus canales privados."),
            _helpItem("User API Key", "Para listar todos tus canales automáticamente."),
            const Divider(),
            const Text(
              "Ejemplo: ABC123XYZ, 987654QWERTY",
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              "Nota: Los canales públicos (como Zekuiano) no necesitan ninguna llave aquí.",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.get('close') ?? 'Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 13),
          children: [
            TextSpan(text: "• $title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }
}