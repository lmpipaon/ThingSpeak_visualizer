import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chart_data.dart';
import '../models/chart_source.dart';
import '../models/favorite_config.dart';
import '../services/thingspeak_service.dart';
import '../constants/app_constants.dart';
import '../localization/translations.dart';

// ------------------- PAINTER DE EJES Y (MULTIESCALA EXTERNA) -------------------
class YAxisPainter extends CustomPainter {
  final double minY;
  final double maxY;
  final double width;
  final Color color;

  YAxisPainter({
    required this.minY,
    required this.maxY,
    required this.width,
    required this.color,
  });

  double normalize(double value) => (maxY == minY) ? 0.5 : (value - minY) / (maxY - minY);

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()..color = color.withOpacity(0.1)..strokeWidth = 0.5;
    final paintLine = Paint()..color = color..strokeWidth = 2;

    final values = [minY, minY + (maxY - minY) * 0.5, maxY];

    for (var v in values) {
      final y = size.height * (1 - normalize(v));
      canvas.drawLine(Offset(width - 5, y), Offset(size.width * 20, y), paintGrid);

      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(1),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 8);
      
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ------------------- PANTALLA PRINCIPAL -------------------
class MultiFieldChartScreen extends StatefulWidget {
  final List<ChartSource> sources;
  final DateTime start;
  final DateTime end;
  final String language;
  final Map<String, double?>? initialMin;
  final Map<String, double?>? initialMax;

  const MultiFieldChartScreen({
    super.key,
    required this.sources,
    required this.start,
    required this.end,
    required this.language,
    this.initialMin,
    this.initialMax,
  });

  @override
  State<MultiFieldChartScreen> createState() => _MultiFieldChartScreenState();
}

class _MultiFieldChartScreenState extends State<MultiFieldChartScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  
  late DateTime startDate;
  late DateTime endDate;
  bool _isLoadingData = true;
  final ThingSpeakService service = ThingSpeakService();
  
  Map<String, List<ChartData>> multiData = {};
  List<ChartData> widestDataList = [];
  RangeValues? xRange;

  final Map<String, double?> minValues = {};
  final Map<String, double?> maxValues = {};
  final Map<String, TextEditingController> minControllers = {};
  final Map<String, TextEditingController> maxControllers = {};
  Map<String, bool> serieVisible = {};

  late Translations t;

  @override
  void initState() {
    super.initState();
    t = Translations(widget.language);
    startDate = widget.start;
    endDate = widget.end;
    
    for (var s in widget.sources) {
      minValues[s.id] = widget.initialMin?[s.id];
      maxValues[s.id] = widget.initialMax?[s.id];
      minControllers[s.id] = TextEditingController(text: minValues[s.id]?.toString() ?? '');
      maxControllers[s.id] = TextEditingController(text: maxValues[s.id]?.toString() ?? '');
      serieVisible[s.id] = true;
    }
    fetchData();
  }

  @override
  void dispose() {
    for (var c in minControllers.values) c.dispose();
    for (var c in maxControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      multiData.clear();
      widestDataList.clear();
      xRange = null; 
    });

    try {
      for (var s in widget.sources) {
        final data = await service.getFieldValuesWithTime(
          s.channel, s.fieldX, start: startDate, end: endDate, results: 8000,
        );
        multiData[s.id] = data;
      }

      final allTimes = multiData.values
          .expand((list) => list.map((e) => e.time.millisecondsSinceEpoch))
          .toList();

      if (allTimes.isNotEmpty) {
        final minX = allTimes.reduce(min).toDouble();
        final maxX = allTimes.reduce(max).toDouble();

        setState(() {
          xRange = RangeValues(minX, maxX);
        });
      }

    } catch (e) {
      debugPrint("${t.get('error_data_load')}: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.get('captureChart'))),
      );
    } catch (e) {
      debugPrint("Error al capturar: $e");
    }
  }

  Future<void> _saveAsFavorite() async {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('saveFavorite')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(hintText: t.get('favoriteNameHint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.get('cancel'))
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                final newFavorite = FavoriteConfig(
                  name: nameController.text,
                  sources: widget.sources,
                  minValues: Map<String, double?>.from(minValues), 
                  maxValues: Map<String, double?>.from(maxValues), 
                );

                List<String> favs = prefs.getStringList('favorites_list') ?? [];
                favs.add(newFavorite.toJson());
                await prefs.setStringList('favorites_list', favs);

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${nameController.text}" ${t.get('saved')}')),
                );
              }
            },
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (xRange == null || multiData.isEmpty) {
      return Center(child: Text(t.get('no_data_available')));
    }

    final List<LineChartBarData> lines = [];
    final List<ChartSource> visibleSources = [];

    final allTimes = multiData.values
        .expand((list) => list.map((e) => e.time.millisecondsSinceEpoch.toDouble()))
        .toList();

    if (allTimes.isEmpty) {
      return Center(child: Text(t.get('no_data_available')));
    }

    final double minTime = allTimes.reduce(min);
    final double maxTime = allTimes.reduce(max);

    for (var s in widget.sources) {
      if (serieVisible[s.id] != true) continue;
      visibleSources.add(s);

      final data = multiData[s.id] ?? [];
      if (data.isEmpty) continue;

      final minY = minValues[s.id] ?? data.map((e) => e.value).reduce(min);
      final maxY = maxValues[s.id] ?? data.map((e) => e.value).reduce(max);

      final spots = data
          .where((e) =>
              e.time.millisecondsSinceEpoch.toDouble() >= xRange!.start &&
              e.time.millisecondsSinceEpoch.toDouble() <= xRange!.end)
          .map((e) => FlSpot(
                e.time.millisecondsSinceEpoch.toDouble(),
                (maxY == minY) ? 0.5 : (e.value - minY) / (maxY - minY),
              ))
          .toList();

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: s.color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ));
    }

    final rangeMs = xRange!.end - xRange!.start;
    final desiredLabels = 5;
    final intervalMs = (rangeMs / desiredLabels).ceilToDouble();

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
              lineBarsData: lines,
              gridData: FlGridData(
                show: true,
                horizontalInterval: 0.25,
                getDrawingHorizontalLine: (_) => const FlLine(color: Colors.black12),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.black26),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: intervalMs,
                    getTitlesWidget: (value, meta) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          DateFormat('HH:mm').format(dt),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (group) => Colors.white.withOpacity(0.45),
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipRoundedRadius: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> spots) {
                    return spots.map((LineBarSpot s) {
                      final serie = visibleSources[s.barIndex];
                      final list = multiData[serie.id]!;

                      final point = list.firstWhere(
                          (e) => e.time.millisecondsSinceEpoch.toDouble() == s.x,
                          orElse: () => list.first);

                      final DateTime time = point.time;
                      final double valor = point.value;

                      return LineTooltipItem(
                        '${DateFormat('MM/dd HH:mm').format(time)}\n${valor.toStringAsFixed(2)}',
                        TextStyle(
                          color: serie.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: RangeSlider(
            values: RangeValues(xRange!.start - minTime, xRange!.end - minTime),
            min: 0,
            max: maxTime - minTime,
            onChanged: (v) {
              setState(() {
                xRange = RangeValues(v.start + minTime, v.end + minTime);
              });
            },
            labels: RangeLabels(
              DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(xRange!.start.toInt())),
              DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(xRange!.end.toInt())),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartArea() {
    const double axisWidth = 46.0;
    int visibleCount = widget.sources.where((s) => serieVisible[s.id] == true).length;
    final double leftPadding = visibleCount * axisWidth;

    return RepaintBoundary(
      key: _boundaryKey,
      child: Container(
        color: Colors.white,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(left: leftPadding + 10, right: 20, bottom: 5),
              child: _buildChart(),
            ),
            ..._buildYAxes(axisWidth),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildYAxes(double width) {
    int index = 0;
    return widget.sources.where((s) => serieVisible[s.id] == true).map((s) {
      final data = multiData[s.id] ?? [];
      if (data.isEmpty) return const SizedBox.shrink();
      final minY = minValues[s.id] ?? data.map((e) => e.value).reduce(min);
      final maxY = maxValues[s.id] ?? data.map((e) => e.value).reduce(max);
      final left = (index++).toDouble() * width;

      return Positioned(
        left: left, top: 0, bottom: 35,
        child: CustomPaint(
          size: Size(width, 0),
          painter: YAxisPainter(minY: minY, maxY: maxY, width: width, color: s.color),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.get('thingSpeakMulti')), actions: [
        IconButton(icon: const Icon(Icons.camera_alt), onPressed: _takeScreenshot, tooltip: t.get('captureChart')),
        IconButton(icon: const Icon(Icons.favorite_border, color: Colors.redAccent), onPressed: _saveAsFavorite, tooltip: t.get('saveFavorite')),
        IconButton(icon: const Icon(Icons.tune), onPressed: _showYAxisSettings, tooltip: t.get('adjustYScales')),
        IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData, tooltip: t.get('reset')),
      ]),
      body: Column(children: [
        _buildDateHeader(),
        _buildVisibilityToggles(),
        Expanded(
          child: _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : Padding(padding: const EdgeInsets.only(top: 20), child: _buildChartArea()),
        ),
        if (xRange != null && widestDataList.isNotEmpty) _buildZoomSlider(),
      ]),
    );
  }

  Widget _buildDateHeader() => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
              child: ActionChip(
                  onPressed: () => _selectDate(true),
                  label: Text('${t.get('start')}: ${DateFormat('dd/MM HH:mm').format(startDate)}'))),
          const SizedBox(width: 8),
          Expanded(
              child: ActionChip(
                  onPressed: () => _selectDate(false),
                  label: Text('${t.get('end')}: ${DateFormat('dd/MM HH:mm').format(endDate)}'))),
        ]),
      );

  Widget _buildVisibilityToggles() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: widget.sources
                .map((s) => Row(children: [
                      Checkbox(
                          value: serieVisible[s.id],
                          onChanged: (v) => setState(() => serieVisible[s.id] = v ?? true),
                          activeColor: s.color),
                      Text(s.displayName,
                          style: TextStyle(color: s.color, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15),
                    ]))
                .toList()),
      );

  Widget _buildZoomSlider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: RangeSlider(
          values: xRange!,
          min: xRange!.start,
          max: xRange!.end,
          onChanged: (v) => setState(() => xRange = v),
        ),
      );

  Future<void> _selectDate(bool start) async {
    final d = await showDatePicker(
        context: context,
        initialDate: start ? startDate : endDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (d == null) return;
    final tPick = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(start ? startDate : endDate));
    if (tPick == null) return;
    setState(() {
      final nd = DateTime(d.year, d.month, d.day, tPick.hour, tPick.minute);
      if (start) {
        startDate = nd;
      } else {
        endDate = nd;
      }
    });
    fetchData();
  }

  void _showYAxisSettings() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(t.get('adjustYScales')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.sources
                      .map((s) => Column(children: [
                            Text(s.displayName,
                                style: TextStyle(color: s.color, fontWeight: FontWeight.bold)),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                      controller: minControllers[s.id],
                                      decoration: InputDecoration(labelText: t.get('min')),
                                      keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: TextField(
                                      controller: maxControllers[s.id],
                                      decoration: InputDecoration(labelText: t.get('max')),
                                      keyboardType: TextInputType.number)),
                            ]),
                            const Divider(),
                          ]))
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      setState(() {
                        for (var s in widget.sources) {
                          minValues[s.id] = double.tryParse(minControllers[s.id]!.text);
                          maxValues[s.id] = double.tryParse(maxControllers[s.id]!.text);
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(t.get('apply')))
              ],
            ));
  }
}
