import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Necesario para leer el idioma guardado
import 'screens/initial_loader.dart';
import '../localization/translations.dart';

void main() async {
  // 1. Asegurar la inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Leer el idioma guardado del almacenamiento local (o español por defecto)
  final prefs = await SharedPreferences.getInstance();
  final String savedLang = prefs.getString('selected_language') ?? 'en';

  // 3. Cargar el JSON de traducciones ANTES de runApp
  final translations = Translations(savedLang);
  await translations.load();

  // 4. Iniciar la App
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: InitialLoader(), // Tu loader ahora ya tendrá las traducciones listas
    );
  }
}
