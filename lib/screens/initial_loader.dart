import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'chart_source_selector_screen.dart';
import 'settings/api_keys_config_screen.dart'; 
import '../localization/translations.dart';

class InitialLoader extends StatefulWidget {
  const InitialLoader({super.key});

  @override
  State<InitialLoader> createState() => _InitialLoaderState();
}

class _InitialLoaderState extends State<InitialLoader> {
  // Por defecto iniciamos en inglés si no hay nada guardado
  String language = 'en'; 
  List<String> userApiKeys = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sincronizamos con la clave usada en el main.dart
    language = prefs.getString('selected_language') ?? 'en'; 
    userApiKeys = prefs.getStringList('apiKeys') ?? [];

    if (!mounted) return;

    // Ya no cargamos traducciones aquí porque se encargó el main.dart
    // de que el sistema estuviera listo.

    if (userApiKeys.isEmpty) {
      // Si no hay llaves, a la configuración inicial
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ApiKeysConfigScreen(
            language: language,
            userApiKeys: const [],
          ),
        ),
      );
    } else {
      // Si hay llaves, al selector de gráficas
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
        // Mientras el Future _loadConfig decide el destino, mostramos esto
        child: CircularProgressIndicator(), 
      ),
    );
  }
}