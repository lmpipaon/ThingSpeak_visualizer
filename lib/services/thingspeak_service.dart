import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/chart_data.dart';
import '../constants/app_constants.dart';

class ThingSpeakService {
  // ------------------------------------------------------
  // Obtiene todos los canales de un usuario a partir de su API Key
  // ------------------------------------------------------
  Future<List<Channel>> getUserChannels(String userApiKey) async {
    final url = Uri.parse(
      'https://api.thingspeak.com/channels.json?api_key=$userApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los canales');
    }

    final List data = json.decode(response.body);
    final List<Channel> channels = [];

    for (var channelJson in data) {
      String? readApiKey;

      for (var key in channelJson['api_keys']) {
        if (key['write_flag'] == false) {
          readApiKey = key['api_key'];
          break;
        }
      }

      if (readApiKey != null) {
        channels.add(
          Channel(
            id: channelJson['id'].toString(),
            name: channelJson['name'] ?? 'Sin nombre',
            readApiKey: readApiKey,
          ),
        );
      }
    }
    return channels;
  }

  // ------------------------------------------------------
  // Obtiene la última lectura del canal para descubrir campos
  // y mapear fieldName -> fieldX
  // ------------------------------------------------------
  Future<Map<String, String>> getLastFeed(
    Channel channel,
    Map<String, String> fieldNameToFieldX,
  ) async {
    final url = Uri.parse(
      'https://api.thingspeak.com/channels/${channel.id}/feeds.json'
      '?api_key=${channel.readApiKey}&results=1',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Error al obtener la última lectura del canal');
    }

    final data = json.decode(response.body);
    final feeds = data['feeds'];
    final channelInfo = data['channel'];

    if (feeds == null || feeds.isEmpty) return {};

    final lastFeed = feeds[0] as Map<String, dynamic>;
    final Map<String, String> fields = {};

    lastFeed.forEach((key, value) {
      if (key.startsWith('field') && value != null) {
        final fieldName = channelInfo[key] ?? key;
        fields[fieldName] = value.toString();
        fieldNameToFieldX[fieldName] = key;
      }
    });

    return fields;
  }

  // ------------------------------------------------------
  // Obtiene valores de un campo con fecha/hora
  // ------------------------------------------------------
  Future<List<ChartData>> getFieldValuesWithTime(
    Channel channel,
    String fieldX, {
    DateTime? start,
    DateTime? end,
    int results = defaultResultsForChart,
  }) async {
    String urlStr =
        'https://api.thingspeak.com/channels/${channel.id}/feeds.json'
        '?api_key=${channel.readApiKey}&results=$results';

    if (start != null && end != null) {
      urlStr +=
          '&start=${Uri.encodeComponent(start.toIso8601String())}'
          '&end=${Uri.encodeComponent(end.toIso8601String())}';
    }

    final response = await http.get(Uri.parse(urlStr));
    if (response.statusCode != 200) {
      throw Exception('Error al cargar datos del campo');
    }

    final feeds = json.decode(response.body)['feeds'] as List;
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
