// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../models/chart_data.dart';
import '../../models/chart_source.dart';
import '../../localization/translations.dart';
import 'y_axis_painter.dart';

class ChartView extends StatelessWidget {
  final List<ChartSource> sources;
  final Map<String, List<ChartData>> multiData;
  final RangeValues xRange;
  final Map<String, bool> serieVisible;
  final Map<String, double?> minValues;
  final Map<String, double?> maxValues;
  final GlobalKey boundaryKey;
  final bool isFullScreen;
  final bool showYAxes;
  final String language; // Recibimos el idioma para localizar fechas

  const ChartView({
    super.key,
    required this.sources,
    required this.multiData,
    required this.xRange,
    required this.serieVisible,
    required this.minValues,
    required this.maxValues,
    required this.boundaryKey,
    required this.isFullScreen,
    required this.showYAxes,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final t = Translations(language);
    const double axisWidth = 46.0;
    
    int visibleCount = sources.where((s) => serieVisible[s.id] == true).length;
    final double leftPadding = showYAxes ? (visibleCount * axisWidth) : 10.0;

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        color: Colors.white,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: leftPadding, 
                right: 20, 
                top: 25, // Margen superior para tooltips
                bottom: 5
              ),
              child: _buildLineChart(t),
            ),
            if (showYAxes) ..._buildYAxes(axisWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(Translations t) {
    final List<LineChartBarData> lines = [];
    final List<ChartSource> activeSources = sources.where((s) => serieVisible[s.id] == true).toList();

    for (var s in sources) {
      if (serieVisible[s.id] != true) continue;
      final data = multiData[s.id] ?? [];
      if (data.isEmpty) continue;

      final minY = minValues[s.id] ?? data.map((e) => e.value).reduce(min);
      final maxY = maxValues[s.id] ?? data.map((e) => e.value).reduce(max);

      final spots = data
          .where((e) => e.time.millisecondsSinceEpoch >= xRange.start && e.time.millisecondsSinceEpoch <= xRange.end)
          .map((e) => FlSpot(
                e.time.millisecondsSinceEpoch.toDouble(),
                (maxY == minY) ? 0.5 : (e.value - minY) / (maxY - minY),
              ))
          .toList();

      if (spots.isEmpty) continue;

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: s.color,
        barWidth: 1.8,
        dotData: const FlDotData(show: false),
      ));
    }

    final rangeMs = xRange.end - xRange.start;
    final intervalMs = (rangeMs / 5).ceilToDouble();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (LineBarSpot touchedSpot) => Colors.white.withOpacity(0.9),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              final sortedSpots = List<LineBarSpot>.from(touchedSpots)
                ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

              return sortedSpots.map((barSpot) {
                final s = activeSources[barSpot.barIndex];
                final data = multiData[s.id] ?? [];
                final minY = minValues[s.id] ?? data.map((e) => e.value).reduce(min);
                final maxY = maxValues[s.id] ?? data.map((e) => e.value).reduce(max);
                
                final double realValue = barSpot.y * (maxY - minY) + minY;
                final String valueStr = realValue.abs() >= 1000 
                    ? realValue.toStringAsFixed(1) 
                    : realValue.toStringAsFixed(2);

                final DateTime dt = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
                
                // --- LOCALIZACIÓN DE FECHA EN TOOLTIP ---
                // Muestra: "14 ene, 23:15" en ES o "Jan 14, 11:15 PM" en EN
                final String timeStr = DateFormat.MMMd(language).add_Hm().format(dt);

                return LineTooltipItem(
                  '${s.displayName}\n$timeStr\n$valueStr',
                  TextStyle(
                    color: s.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: -0.02,
        maxY: 1.02,
        lineBarsData: lines,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (_) => const FlLine(color: Colors.black12, strokeWidth: 1),
          drawVerticalLine: true,
          getDrawingVerticalLine: (_) => const FlLine(color: Colors.black12, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.black26)),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: intervalMs > 0 ? intervalMs : 1,
              getTitlesWidget: (value, meta) {
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                
                // --- LOCALIZACIÓN DE FECHA EN EJE X ---
                final String datePart = DateFormat.MMMd(language).format(dt);
                final String timePart = DateFormat.Hm(language).format(dt);

                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    '$datePart\n$timePart',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black54
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildYAxes(double width) {
    int index = 0;
    return sources.where((s) => serieVisible[s.id] == true).map((s) {
      final data = multiData[s.id] ?? [];
      if (data.isEmpty) return const SizedBox.shrink();
      
      final minY = minValues[s.id] ?? data.map((e) => e.value).reduce(min);
      final maxY = maxValues[s.id] ?? data.map((e) => e.value).reduce(max);
      final left = (index++).toDouble() * width;

      return Positioned(
        left: left, 
        top: 25, 
        bottom: 47,
        child: CustomPaint(
          size: Size(width, 0),
          painter: YAxisPainter(minY: minY, maxY: maxY, width: width, color: s.color),
        ),
      );
    }).toList();
  }
}