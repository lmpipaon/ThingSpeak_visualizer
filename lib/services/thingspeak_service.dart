import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/chart_data.dart';
import '../constants/app_constants.dart';

class ThingSpeakService {
  // ------------------------------------------------------
  // Obtiene un canal individual (Público o Privado)
  // ------------------------------------------------------
  Future<Channel> getChannelById(String channelId, {String? readApiKey}) async {
    final String keyParam = (readApiKey != null && readApiKey.isNotEmpty)
        ? '?api_key=$readApiKey'
        : '';

    final url = Uri.parse('https://api.thingspeak.com/channels/$channelId.json$keyParam');
    
    // debugPrint('🌐 GET Canal Info: $url'); // DEBUG

    final response = await http.get(url);
    if (response.statusCode != 200) {
      // debugPrint('❌ Error en getChannelById: ${response.statusCode}');
      throw Exception('Error al acceder al canal $channelId');
    }

    final data = json.decode(response.body);
    return Channel(
      id: data['id'].toString(),
      name: data['name'] ?? 'Canal $channelId',
      readApiKey: readApiKey ?? '',
    );
  }

  // ------------------------------------------------------
  // Obtiene todos los canales de un usuario (User API Key)
  // ------------------------------------------------------
  Future<List<Channel>> getUserChannels(String userApiKey) async {
    final url = Uri.parse(
      'https://api.thingspeak.com/channels.json?api_key=$userApiKey',
    );

    // debugPrint('🌐 GET Canales Usuario: $url'); // DEBUG

    final response = await http.get(url);
    if (response.statusCode != 200) {
      // debugPrint('❌ Error en getUserChannels: ${response.statusCode}');
      throw Exception('No se pudieron cargar los canales');
    }

    final List data = json.decode(response.body);
    final List<Channel> channels = [];

    for (var channelJson in data) {
      String? readApiKey;
      if (channelJson['api_keys'] != null) {
        for (var key in channelJson['api_keys']) {
          if (key['write_flag'] == false) {
            readApiKey = key['api_key'];
            break;
          }
        }
      }

      channels.add(
        Channel(
          id: channelJson['id'].toString(),
          name: channelJson['name'] ?? 'Sin nombre',
          readApiKey: readApiKey ?? '',
        ),
      );
    }
    return channels;
  }

  // ------------------------------------------------------
  // Mapear fieldName -> fieldX (SOPORTA PÚBLICOS)
  // ------------------------------------------------------
Future<dynamic> getLastFeed( // <--- Cambiado de Map<String, String> a dynamic
    Channel channel,
    Map<String, String> fieldNameToFieldX,
  ) async {
    String urlStr = 'https://api.thingspeak.com/channels/${channel.id}/feeds.json?results=1';
    
    if (channel.readApiKey.isNotEmpty) {
      urlStr += '&api_key=${channel.readApiKey}';
    }

    final response = await http.get(Uri.parse(urlStr));
    if (response.statusCode != 200) {
      throw Exception('Error al obtener la última lectura del canal');
    }

    final data = json.decode(response.body);
    final feeds = data['feeds'];
    final channelInfo = data['channel'];

    if (feeds == null || feeds.isEmpty) {
      return null; // <--- Cambiado para manejar errores de canal vacío
    }

    final lastFeed = feeds[0] as Map<String, dynamic>;

    lastFeed.forEach((key, value) {
      if (key.startsWith('field')) {
        final fieldName = (channelInfo != null && channelInfo[key] != null) 
            ? channelInfo[key].toString() 
            : key; 
            
        // Seguimos llenando este mapa por referencia para que la pantalla lo use
        fieldNameToFieldX[fieldName] = key;
      }
    });

    return data; // <--- AHORA DEVOLVEMOS TODO EL JSON PARA SACAR EL NOMBRE
  }

  // ------------------------------------------------------
  // Obtiene valores de un campo (SOPORTA PÚBLICOS)
  // ------------------------------------------------------
  Future<List<ChartData>> getFieldValuesWithTime(
    Channel channel,
    String fieldX, {
    DateTime? start,
    DateTime? end,
    int results = defaultResultsForChart,
  }) async {
    String urlStr = 'https://api.thingspeak.com/channels/${channel.id}/feeds.json?results=$results';

    if (channel.readApiKey.isNotEmpty) {
      urlStr += '&api_key=${channel.readApiKey}';
    }

    if (start != null && end != null) {
      urlStr += '&start=${Uri.encodeComponent(start.toIso8601String())}'
                '&end=${Uri.encodeComponent(end.toIso8601String())}';
    }

    // ESTE ES EL LINK QUE NECESITAS COPIAR
    // debugPrint('📊 GET Gráfica ($fieldX): $urlStr'); 

    final response = await http.get(Uri.parse(urlStr));
    if (response.statusCode != 200) {
      // debugPrint('❌ Error en getFieldValuesWithTime: ${response.statusCode}');
      throw Exception('Error al cargar datos del campo');
    }

    final decoded = json.decode(response.body);
    final feeds = decoded['feeds'] as List?;
    
    if (feeds == null) {
      // debugPrint('⚠️ Respuesta sin feeds para campo $fieldX');
      return [];
    }

    // debugPrint('✅ Datos recibidos para $fieldX: ${feeds.length} puntos');

    final List<ChartData> values = [];
    for (var feed in feeds) {
      final rawValue = feed[fieldX];
      final rawTime = feed['created_at'];

      if (rawValue != null && rawTime != null) {
        final value = double.tryParse(rawValue.toString());
        final time = DateTime.tryParse(rawTime);
        if (value != null && time != null) {
          values.add(ChartData(time.toLocal(), value));
        }
      }
    }

    return values;
  }
}