import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart' as sliders;

import '../models/chart_data.dart';
import '../models/chart_source.dart';
import '../services/thingspeak_service.dart';
import '../constants/app_constants.dart';
import '../localization/translations.dart';

class MultiFieldChartScreen extends StatefulWidget {
  final List<ChartSource> sources;
  final DateTime start;
  final DateTime end;
  final String language;

  const MultiFieldChartScreen({
    super.key,
    required this.sources,
    required this.start,
    required this.end,
    required this.language,
  });

  @override
  State<MultiFieldChartScreen> createState() => _MultiFieldChartScreenState();
}

class _MultiFieldChartScreenState extends State<MultiFieldChartScreen> {
  late DateTime startDate;
  late DateTime endDate;
  Map<String, List<ChartData>> multiData = {};
  
  sliders.SfRangeValues? xRange;
  List<ChartData> widestDataList = []; 

  bool _isLoadingData = true;
  String? _dataErrorMessage; 

  final ThingSpeakService service = ThingSpeakService();
  late Translations t;

  // --- CONFIGURACIÓN DE ESTILO ---
  final double axisFontSize = 10.0; 

  final Map<String, double?> minValues = {};
  final Map<String, double?> maxValues = {};
  final Map<String, TextEditingController> minControllers = {};
  final Map<String, TextEditingController> maxControllers = {};

  @override
  void initState() {
    super.initState();
    startDate = widget.start;
    endDate = widget.end;
    t = Translations(widget.language); 
    
    for (var source in widget.sources) {
      minControllers[source.id] = TextEditingController();
      maxControllers[source.id] = TextEditingController();
      minValues[source.id] = null;
      maxValues[source.id] = null;
    }
    fetchData();
  }

  @override
  void dispose() {
    for (var c in minControllers.values) { c.dispose(); }
    for (var c in maxControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoadingData = true;
      _dataErrorMessage = null;
      multiData = {};
      widestDataList = [];
    });

    try {
      List<Future<void>> futures = [];
      for (var source in widget.sources) {
        futures.add(() async {
          final values = await service.getFieldValuesWithTime(
            source.channel,
            source.fieldX,
            start: startDate,
            end: endDate,
            results: maxResultsForChart,
          );
          if (mounted) {
            setState(() { multiData[source.id] = values; });
          }
        }());
      }
      await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        int maxLen = 0;
        for (var dataList in multiData.values) {
          if (dataList.length > maxLen) maxLen = dataList.length;
        }
        if (maxLen > 0) {
          xRange = sliders.SfRangeValues(0.0, (maxLen - 1).toDouble());
          for (var dataList in multiData.values) {
            if (dataList.length == maxLen) {
              widestDataList = dataList;
              break;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataErrorMessage = t.get('error_data_load'); 
        _isLoadingData = false;
      });
    }
  }

  void _showYAxisSettings() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.get('y_axis_settings') ?? "Ajustar Ejes Y"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.sources.length,
              itemBuilder: (context, index) {
                final source = widget.sources[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: source.color)),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: minControllers[source.id], decoration: const InputDecoration(labelText: "Mín"), keyboardType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: maxControllers[source.id], decoration: const InputDecoration(labelText: "Máx"), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () {
              setState(() {
                for (var source in widget.sources) {
                  minValues[source.id] = double.tryParse(minControllers[source.id]!.text);
                  maxValues[source.id] = double.tryParse(maxControllers[source.id]!.text);
                }
              });
              Navigator.pop(context);
            }, child: const Text("Aplicar")),
            TextButton(onPressed: () {
              setState(() {
                for (var source in widget.sources) {
                  minValues[source.id] = maxValues[source.id] = null;
                  minControllers[source.id]!.clear();
                  maxControllers[source.id]!.clear();
                }
              });
              Navigator.pop(context);
            }, child: const Text("Auto")),
          ],
        );
      },
    );
  }

  Future<void> pickStartDateTime() async {
    final date = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: endDate);
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startDate));
    if (time == null) return;
    setState(() => startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    fetchData();
  }

  Future<void> pickEndDateTime() async {
    final date = await showDatePicker(context: context, initialDate: endDate, firstDate: startDate, lastDate: DateTime.now());
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(endDate));
    if (time == null) return;
    setState(() => endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    fetchData();
  }
  
  @override
  Widget build(BuildContext context) {
    final List<CartesianSeries> seriesList = [];
    final List<ChartAxis> additionalAxes = [];
    final ChartSource? firstSource = widget.sources.isNotEmpty ? widget.sources.first : null;

    for (int i = 0; i < widget.sources.length; i++) {
      final source = widget.sources[i];
      final rawData = multiData[source.id] ?? [];
      
      if (xRange != null && rawData.isNotEmpty) {
        final startIdx = xRange!.start.round(); 
        final endIdx = xRange!.end.round();
        final filteredData = rawData.sublist(startIdx, (endIdx + 1).clamp(startIdx, rawData.length));

        if (i > 0) {
          additionalAxes.add(
            NumericAxis(
              name: 'axis_${source.id}',
              opposedPosition: false,
              minimum: minValues[source.id],
              maximum: maxValues[source.id],
              labelStyle: TextStyle(color: source.color, fontSize: axisFontSize),
              title: AxisTitle(
                text: source.displayName, 
                textStyle: TextStyle(color: source.color, fontSize: axisFontSize)
              ),
            ),
          );
        }

        seriesList.add(
          LineSeries<ChartData, DateTime>(
            name: source.displayName, 
            dataSource: filteredData,
            xValueMapper: (d, _) => d.time,
            yValueMapper: (d, _) => d.value,
            yAxisName: i == 0 ? null : 'axis_${source.id}',
            color: source.color, 
            enableTooltip: true,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('chart_comparison_title')),
        actions: [IconButton(icon: const Icon(Icons.tune), onPressed: _showYAxisSettings)],
      ),
      body: Column(
        children: [
          // FILA DE FECHAS (SIN ICONO INTERMEDIO)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickStartDateTime, 
                    child: Text(DateFormat('dd/MM HH:mm').format(startDate), style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 16), // Espacio entre botones
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickEndDateTime, 
                    child: Text(DateFormat('dd/MM HH:mm').format(endDate), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : SfCartesianChart(
                  primaryXAxis: DateTimeAxis(dateFormat: DateFormat('HH:mm')),
                  primaryYAxis: NumericAxis(
                    minimum: firstSource != null ? minValues[firstSource.id] : null,
                    maximum: firstSource != null ? maxValues[firstSource.id] : null,
                    labelStyle: TextStyle(color: firstSource?.color, fontSize: axisFontSize),
                    title: AxisTitle(
                      text: firstSource?.displayName ?? '', 
                      textStyle: TextStyle(color: firstSource?.color, fontSize: axisFontSize)
                    ),
                  ),
                  axes: additionalAxes,
                  series: seriesList,
                  legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                  tooltipBehavior: TooltipBehavior(
                    enable: true, 
                    header: '', 
                    builder: (dynamic data, ChartPoint point, ChartSeries series, int pIdx, int sIdx) {
                      final ChartData d = data as ChartData;
                      final String dateStr = DateFormat('dd - HH:mm').format(d.time);
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: Text(
                          '$dateStr\n${series.name}: ${d.value.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.black, fontSize: 12),
                        ),
                      );
                    }
                  ),
                ),
          ),
          if (xRange != null && widestDataList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: sliders.SfRangeSlider(
                min: 0.0,
                max: (widestDataList.length - 1).toDouble(),
                values: xRange!,
                onChanged: (values) => setState(() => xRange = values),
              ),
            ),
        ],
      ),
    );
  }
}