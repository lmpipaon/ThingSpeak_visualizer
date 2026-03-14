import 'dart:convert';
import 'package:flutter/services.dart';

class Translations {
  final String lang;
  // Cambiamos el mapa estático por uno dinámico que se llena al cargar el JSON
  static Map<String, dynamic>? _data;

  Translations(this.lang);

  // Este método sustituye a la carga estática. Se llama una vez al inicio o al cambiar idioma.
  Future<void> load() async {
    try {
      String jsonString = await rootBundle.loadString('assets/lang/$lang.json');
      _data = json.decode(jsonString);
    } catch (e) {
      // Fallback a español si el archivo no existe o falla
      String jsonString = await rootBundle.loadString('assets/lang/es.json');
      _data = json.decode(jsonString);
      print("Error cargando idioma $lang: $e");
    }
  }

  // Mantenemos la firma de tu método para no romper el resto de la App
  String get(String key) {
    return _data?[key] ?? key;
  }
  
  // Lista para generar tus menús de selección de idioma
  static List<Map<String, String>> get languages => [
    {'code': 'es', 'name': 'Español'},
    {'code': 'en', 'name': 'English'},
    {'code': 'eu', 'name': 'Euskara'},
    {'code': 'ca', 'name': 'Català'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'it', 'name': 'Italiano'},
  ];
}