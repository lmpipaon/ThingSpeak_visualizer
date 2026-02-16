import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'screens/initial_loader.dart';
import 'localization/translations.dart'; // Corregido el path si es necesario
import 'package:intl/date_symbol_data_local.dart';

// --- ESTA ES LA LLAVE MAESTRA PARA MENSAJES GLOBALES ---
final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final String savedLang = prefs.getString('selected_language') ?? 'en';

  final translations = Translations(savedLang);
  await translations.load();

  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('eu', null);
  await initializeDateFormatting('ca', null);
  await initializeDateFormatting('ga', null);
  await initializeDateFormatting('it', null);
  await initializeDateFormatting('pt', null);
  await initializeDateFormatting('fr', null);
  await initializeDateFormatting('de', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ASOCIAMOS LA LLAVE AQUÍ
      scaffoldMessengerKey: globalMessengerKey, 
      debugShowCheckedModeBanner: false,
      home: const InitialLoader(),
    );
  }
}