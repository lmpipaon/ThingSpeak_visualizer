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
  final bool showYAxes; // Nueva propiedad

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
    
    // Si showYAxes es false, usamos un margen mínimo de 10
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
            // Solo dibujamos los ejes si showYAxes es true
            if (showYAxes) ..._buildYAxes(axisWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final List<LineChartBarData> lines = [];

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