import 'dart:convert';
import 'package:flutter/material.dart';
import 'chart_source.dart';
import 'channel.dart'; 

class FavoriteConfig {
  final String name;
  final List<ChartSource> sources;
  final Map<String, double?> minValues;
  final Map<String, double?> maxValues;

  FavoriteConfig({
    required this.name,
    required this.sources,
    required this.minValues,
    required this.maxValues,
  });

  String toJson() {
    return jsonEncode({
      'name': name,
      'sources': sources.map((s) => {
        'channel_id': s.channel.id,
        'channel_name': s.channel.name,
        'channel_key': s.channel.readApiKey,
        'fieldName': s.fieldName,
        'fieldX': s.fieldX,
        'color': s.color.value,
      }).toList(),
      'minValues': minValues,
      'maxValues': maxValues,
    });
  }

  factory FavoriteConfig.fromJson(String sourceStr) {
    final Map<String, dynamic> map = jsonDecode(sourceStr);
    final List<dynamic> sourcesRaw = map['sources'] ?? [];
    
    final List<ChartSource> loadedSources = sourcesRaw.map((s) {
      return ChartSource(
        channel: Channel(
          id: s['channel_id'] ?? '',
          name: s['channel_name'] ?? '',
          readApiKey: s['channel_key'] ?? '',
        ),
        fieldName: s['fieldName'] ?? '',
        fieldX: s['fieldX'] ?? '',
        color: Color(s['color'] ?? 0xFF000000),
      );
    }).toList();

    return FavoriteConfig(
      name: map['name'] ?? 'Sin nombre',
      sources: loadedSources,
      minValues: (map['minValues'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v?.toDouble())),
      maxValues: (map['maxValues'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v?.toDouble())),
    );
  }
}