import 'package:flutter/material.dart';
import 'channel.dart';

class ChartSource {
  final Channel channel;
  final String fieldName;
  final String fieldX;
  final Color color;

  ChartSource({
    required this.channel,
    required this.fieldName,
    required this.fieldX,
    required this.color,
  });

  String get id => '${channel.id}_$fieldX';
  String get displayName => '${channel.name} / $fieldName';
}

