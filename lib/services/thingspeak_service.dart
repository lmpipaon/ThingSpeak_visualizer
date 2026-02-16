import '../main.dart'; 
import 'dart:convert';
import 'dart:async'; 
import 'dart:io';    
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Necesario para la UI del SnackBar

import '../models/channel.dart';
import '../models/chart_data.dart';
import '../constants/app_constants.dart';

class ThingSpeakService {
  // Tiempo máximo de espera para todas las peticiones
  final Duration timeoutDuration = const Duration(seconds: 10);

  // --- FUNCIÓN PRIVADA PARA MANEJO DE ERRORES DE RED ---
  void _handleError(Object e) {
    String message = '';

    // 1. Identificamos el tipo de error y asignamos el texto
    if (e is SocketException) {
      message = 'Sin conexión a Internet. Revisa tu WiFi o datos.';
    } else if (e is TimeoutException) {
      message = 'Tiempo de espera agotado. ThingSpeak no responde.';
    } else {
      message = 'Error de red: $e';
    }

    // 2. DISPARAMOS EL POP-UP (SnackBar)
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(color: Colors.white, fontSize: 14)
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5), // Desaparece tras 3 segundos
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // 3. LANZAMOS LA EXCEPCIÓN
    // Esto es lo que ves en la consola y lo que atrapa el "catch" de tu UI
    throw Exception(message);
  }

  // 1. Obtiene un canal individual
  Future<Channel> getChannelById(String channelId, {String? readApiKey}) async {
    final String keyParam = (readApiKey != null && readApiKey.isNotEmpty)
        ? '?api_key=$readApiKey'
        : '';

    final url = Uri.parse('https://api.thingspeak.com/channels/$channelId.json$keyParam');
    
    try {
      final response = await http.get(url).timeout(timeoutDuration);
      if (response.statusCode != 200) {
        throw Exception('Error al acceder al canal $channelId (Código ${response.statusCode})');
      }
      final data = json.decode(response.body);
      return Channel(
        id: data['id'].toString(),
        name: data['name'] ?? 'Canal $channelId',
        readApiKey: readApiKey ?? '',
      );
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // 2. Obtiene todos los canales de un usuario
  Future<List<Channel>> getUserChannels(String userApiKey) async {
    final url = Uri.parse('https://api.thingspeak.com/channels.json?api_key=$userApiKey');

    try {
      final response = await http.get(url).timeout(timeoutDuration);
      if (response.statusCode != 200) {
        throw Exception('No se pudieron cargar los canales del usuario');
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
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // 3. Mapear fieldName -> fieldX
  Future<dynamic> getLastFeed(Channel channel, Map<String, String> fieldNameToFieldX) async {
    String urlStr = 'https://api.thingspeak.com/channels/${channel.id}/feeds.json?results=1';
    if (channel.readApiKey.isNotEmpty) {
      urlStr += '&api_key=${channel.readApiKey}';
    }

    try {
      final response = await http.get(Uri.parse(urlStr)).timeout(timeoutDuration);
      if (response.statusCode != 200) {
        throw Exception('Error al obtener la última lectura del canal');
      }

      final data = json.decode(response.body);
      final feeds = data['feeds'];
      final channelInfo = data['channel'];

      if (feeds == null || feeds.isEmpty) return null;

      final lastFeed = feeds[0] as Map<String, dynamic>;
      lastFeed.forEach((key, value) {
        if (key.startsWith('field')) {
          final fieldName = (channelInfo != null && channelInfo[key] != null) 
              ? channelInfo[key].toString() 
              : key; 
          fieldNameToFieldX[fieldName] = key;
        }
      });

      return data;
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // 4. Obtiene valores para la gráfica
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

    try {
      final response = await http.get(Uri.parse(urlStr)).timeout(timeoutDuration);
      if (response.statusCode != 200) {
        throw Exception('Error al cargar datos del campo');
      }

      final decoded = json.decode(response.body);
      final feeds = decoded['feeds'] as List?;
      if (feeds == null) return [];

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
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }
}