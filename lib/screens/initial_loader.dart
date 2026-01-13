import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'chart_source_selector_screen.dart';
import 'settings/api_keys_config_screen.dart'; // Asegúrate de que esta ruta es correcta
import '../localization/translations.dart';

class InitialLoader extends StatefulWidget {
  const InitialLoader({super.key});

  @override
  State<InitialLoader> createState() => _InitialLoaderState();
}

class _InitialLoaderState extends State<InitialLoader> {
  String language = 'en'; 
  List<String> userApiKeys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Debug de favoritos en consola
    List<String>? rawFavs = prefs.getStringList('favorites_list');
    /*
    print("========= CONTENIDO DEL REGISTRO (FAVORITOS) =========");
    if (rawFavs == null || rawFavs.isEmpty) {
      print("El registro está vacío o la clave no existe.");
    } else {
      for (var f in rawFavs) {
        print(f); 
      }
    }
    print("======================================================");
*/
    language = prefs.getString('language') ?? 'en'; 
    userApiKeys = prefs.getStringList('apiKeys') ?? [];

    if (!mounted) return;

    // LÓGICA MEJORADA:
    // Si no hay llaves, mandamos a la pantalla de configuración profesional.
    if (userApiKeys.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ApiKeysConfigScreen(
            language: language,
            userApiKeys: const [], // Lista vacía al ser la primera vez
          ),
        ),
      );
    } else {
      // Si ya hay llaves, vamos directos al selector de gráficas.
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
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Solo mostramos el cargador mientras decide a dónde ir
      ),
    );
  }
}