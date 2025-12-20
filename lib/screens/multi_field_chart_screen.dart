import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart' as sliders;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chart_data.dart';
import '../models/chart_source.dart';
import '../models/favorite_config.dart';
import '../services/thingspeak_service.dart';
import '../constants/app_constants.dart';
import '../localization/translations.dart';

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
  late DateTime startDate;
  late DateTime endDate;
  Map<String, List<ChartData>> multiData = {};
  sliders.SfRangeValues? xRange;
  List<ChartData> widestDataList = []; 
  bool _isLoadingData = true;
  final ThingSpeakService service = ThingSpeakService();
  late Translations t;

  // Control de Ejes Y
  final Map<String, double?> minValues = {};
  final Map<String, double?> maxValues = {};
  final Map<String, TextEditingController> minControllers = {};
  final Map<String, TextEditingController> maxControllers = {};

  // Configuración del Tooltip (Ventanita de valores)
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    startDate = widget.start;
    endDate = widget.end;
    t = Translations(widget.language); 
    
    // Configurar Tooltip con el formato Día/Mes Hora:Minuto
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      header: '', 
      canShowMarker: true,
      activationMode: ActivationMode.singleTap,
      format: 'point.x : point.y', // Muestra Fecha : Valor
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    );

    // Inicializar controladores con valores previos si vienen de un favorito
    for (var source in widget.sources) {
      double? initMin = widget.initialMin?[source.id];
      double? initMax = widget.initialMax?[source.id];

      minControllers[source.id] = TextEditingController(text: initMin?.toString() ?? "");
      maxControllers[source.id] = TextEditingController(text: initMax?.toString() ?? "");
      minValues[source.id] = initMin;
      maxValues[source.id] = initMax;
    }
    fetchData();
  }

  @override
  void dispose() {
    for (var c in minControllers.values) { c.dispose(); }
    for (var c in maxControllers.values) { c.dispose(); }
    super.dispose();
  }

  // --- SELECCIÓN DE FECHAS ---
  Future<void> pickStartDateTime() async {
    final date = await showDatePicker(
      context: context, 
      initialDate: startDate, 
      firstDate: DateTime.now().subtract(const Duration(days: 365)), 
      lastDate: endDate
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startDate));
    if (time == null) return;
    setState(() => startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    fetchData();
  }

  Future<void> pickEndDateTime() async {
    final date = await showDatePicker(
      context: context, 
      initialDate: endDate, 
      firstDate: startDate, 
      lastDate: DateTime.now()
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(endDate));
    if (time == null) return;
    setState(() => endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    fetchData();
  }

  // --- OBTENCIÓN DE DATOS ---
  Future<void> fetchData() async {
    setState(() { _isLoadingData = true; });
    try {
      for (var source in widget.sources) {
        final values = await service.getFieldValuesWithTime(
          source.channel, source.fieldX, start: startDate, end: endDate, results: maxResultsForChart,
        );
        if (mounted) setState(() { multiData[source.id] = values; });
      }
      setState(() {
        _isLoadingData = false;
        int maxLen = 0;
        for (var list in multiData.values) { if (list.length > maxLen) maxLen = list.length; }
        if (maxLen > 0) {
          xRange = sliders.SfRangeValues(0.0, (maxLen - 1).toDouble());
          widestDataList = multiData.values.firstWhere((list) => list.length == maxLen);
        }
      });
    } catch (e) {
      setState(() { _isLoadingData = false; });
    }
  }

  // --- GESTIÓN DE FAVORITOS ---
  void _showSaveFavoriteDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Guardar Favorito"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Nombre del favorito"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _saveToFavorites(nameController.text.trim());
                Navigator.pop(context);
              }
            }, 
            child: const Text("Guardar")
          ),
        ],
      ),
    );
  }

  Future<void> _saveToFavorites(String favName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sincronizar controladores de texto con los valores numéricos
      for (var source in widget.sources) {
        minValues[source.id] = double.tryParse(minControllers[source.id]!.text);
        maxValues[source.id] = double.tryParse(maxControllers[source.id]!.text);
      }

      final newFavorite = FavoriteConfig(
        name: favName,
        sources: widget.sources,
        minValues: Map.from(minValues),
        maxValues: Map.from(maxValues),
      );

      List<String> favList = prefs.getStringList('favorites_list') ?? [];
      favList.add(newFavorite.toJson());
      await prefs.setStringList('favorites_list', favList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorito guardado correctamente")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- DIÁLOGO DE EJES Y ---
  void _showYAxisSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ajustar Ejes Y"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.sources.length,
            itemBuilder: (context, index) {
              final source = widget.sources[index];
              return Column(
                children: [
                  Text(source.displayName, style: TextStyle(color: source.color, fontWeight: FontWeight.bold)),
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
              for (var s in widget.sources) {
                minValues[s.id] = double.tryParse(minControllers[s.id]!.text);
                maxValues[s.id] = double.tryParse(maxControllers[s.id]!.text);
              }
            });
            Navigator.pop(context);
          }, child: const Text("Aplicar")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<CartesianSeries> seriesList = [];
    final List<ChartAxis> additionalAxes = [];

    for (int i = 0; i < widget.sources.length; i++) {
      final source = widget.sources[i];
      final rawData = multiData[source.id] ?? [];
      
      if (xRange != null && rawData.isNotEmpty) {
        final startIdx = xRange!.start.round(); 
        final endIdx = xRange!.end.round();
        final filteredData = rawData.sublist(startIdx, (endIdx + 1).clamp(startIdx, rawData.length));
        
        // Ejes secundarios
        if (i > 0) {
          additionalAxes.add(NumericAxis(
            name: 'axis_${source.id}', 
            minimum: minValues[source.id], 
            maximum: maxValues[source.id],
            labelStyle: TextStyle(color: source.color, fontSize: 10),
          ));
        }

        // Series de datos
        seriesList.add(LineSeries<ChartData, DateTime>(
          name: source.displayName, 
          dataSource: filteredData,
          xValueMapper: (d, _) => d.time, 
          yValueMapper: (d, _) => d.value,
          yAxisName: i == 0 ? null : 'axis_${source.id}', 
          color: source.color,
          enableTooltip: true,
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Visor de Gráficas"),
        actions: [
          IconButton(icon: const Icon(Icons.star_border), onPressed: _showSaveFavoriteDialog),
          IconButton(icon: const Icon(Icons.tune), onPressed: _showYAxisSettings),
        ],
      ),
      body: Column(
        children: [
          // Fila de botones de fecha
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: pickStartDateTime, child: Text(DateFormat('dd/MM HH:mm').format(startDate)))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: pickEndDateTime, child: Text(DateFormat('dd/MM HH:mm').format(endDate)))),
              ],
            ),
          ),
          // Área del gráfico
          Expanded(
            child: _isLoadingData 
              ? const Center(child: CircularProgressIndicator()) 
              : SfCartesianChart(
                  tooltipBehavior: _tooltipBehavior,
                  primaryXAxis: DateTimeAxis(
                    dateFormat: DateFormat('dd/MM HH:mm'),
                    intervalType: DateTimeIntervalType.auto,
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: widget.sources.isNotEmpty ? minValues[widget.sources[0].id] : null,
                    maximum: widget.sources.isNotEmpty ? maxValues[widget.sources[0].id] : null,
                    labelStyle: TextStyle(color: widget.sources.isNotEmpty ? widget.sources[0].color : null),
                  ),
                  axes: additionalAxes,
                  series: seriesList,
                  legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                ),
          ),
          // Slider de rango temporal (Zoom inferior)
          if (xRange != null && widestDataList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: sliders.SfRangeSlider(
                min: 0.0, max: (widestDataList.length - 1).toDouble(),
                values: xRange!,
                onChanged: (v) => setState(() => xRange = v),
              ),
            ),
        ],
      ),
    );
  }
}