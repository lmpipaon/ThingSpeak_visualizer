import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../models/chart_data.dart';
import '../../models/chart_source.dart';
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
  });

  @override
  Widget build(BuildContext context) {
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
                bottom: 5
              ),
              child: _buildLineChart(),
            ),
            if (showYAxes) ..._buildYAxes(axisWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
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

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: s.color,
        barWidth: 1.5,
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
            // Fondo blanco con 60% de transparencia
            getTooltipColor: (LineBarSpot touchedSpot) => Colors.white.withOpacity(0.6),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              // Ordenar para que siempre aparezcan en el mismo orden de la lista de fuentes
              final sortedSpots = List<LineBarSpot>.from(touchedSpots)
                ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

              return sortedSpots.map((barSpot) {
                // Obtenemos la fuente correspondiente para recuperar los valores reales
                final s = activeSources[barSpot.barIndex];
                final data = multiData[s.id] ?? [];
                final minY = minValues[s.id] ?? data.map((e) => e.value).reduce(min);
                final maxY = maxValues[s.id] ?? data.map((e) => e.value).reduce(max);
                
                // Des-normalizar el valor Y
                final double realValue = barSpot.y * (maxY - minY) + minY;

                // Formatear valor: >= 1000 sin decimales, < 1000 con 2 decimales
                final String valueStr = realValue >= 1000 
                    ? realValue.toStringAsFixed(0) 
                    : realValue.toStringAsFixed(2);

                // Formatear Fecha y Hora
                final DateTime dt = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
                final String timeStr = DateFormat('dd/MM HH:mm').format(dt);

                return LineTooltipItem(
                  '$timeStr\n$valueStr',
                  TextStyle(
                    color: s.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: 0,
        maxY: 1,
        lineBarsData: lines,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (_) => const FlLine(color: Colors.black12, strokeWidth: 1),
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
              reservedSize: 40,
              interval: intervalMs > 0 ? intervalMs : 1,
              getTitlesWidget: (value, meta) {
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('dd/MM').format(dt), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(DateFormat('HH:mm').format(dt), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
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
        top: 0, 
        bottom: 45,
        child: CustomPaint(
          size: Size(width, 0),
          painter: YAxisPainter(minY: minY, maxY: maxY, width: width, color: s.color),
        ),
      );
    }).toList();
  }
}