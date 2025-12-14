import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart' as sliders;

import '../models/chart_data.dart';
import '../models/chart_source.dart';
import '../services/thingspeak_service.dart';
import '../constants/app_constants.dart';
import '../localization/translations.dart';


// ======================================================
// GRÁFICA MULTI-FUENTE CON SELECTOR DE FECHA/HORA Y RANGO (SOPORTE DUAL AXIS)
// ======================================================
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
  Map<String, List<ChartData>> multiData = {}; // {Source.id: [ChartData]}
  
  sliders.SfRangeValues? xRange;
  List<ChartData> widestDataList = []; 

  bool _isLoadingData = true;
  String? _dataErrorMessage; 

  final ThingSpeakService service = ThingSpeakService();
  late Translations t;

  @override
  void initState() {
    super.initState();
    startDate = widget.start;
    endDate = widget.end;
    // La instancia 't' se crea con el idioma pasado por el constructor
    t = Translations(widget.language); 
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoadingData = true;
      _dataErrorMessage = null;
      multiData = {};
      widestDataList = []; // Resetear también
    });

    try {
      // 1. Cargar todas las fuentes en paralelo
      List<Future<void>> futures = [];
      for (var source in widget.sources) {
        futures.add(() async {
          // Asumiendo que 'maxResultsForChart' está definido en app_constants.dart
          final values = await service.getFieldValuesWithTime(
            source.channel,
            source.fieldX,
            start: startDate,
            end: endDate,
            results: maxResultsForChart,
          );
          if (mounted) {
            setState(() {
              multiData[source.id] = values;
            });
          }
        }());
      }
      
      await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        
        // 2. Determinar el rango de datos más amplio para el slider
        int maxLen = 0;
        for (var dataList in multiData.values) {
          if (dataList.length > maxLen) {
            maxLen = dataList.length;
          }
        }
        
        // Encontrar la lista de datos más larga para usar como base del slider
        List<ChartData> currentWidestDataList = [];
        for (var dataList in multiData.values) {
            if (dataList.length == maxLen) {
                currentWidestDataList = dataList;
                break;
            }
        }
        
        // 3. Inicializar el rango
        if (maxLen > 0) {
          xRange = sliders.SfRangeValues(0.0, (maxLen - 1).toDouble());
        } else {
          xRange = null;
        }
        
        // Actualizar widestDataList para el tooltip del slider
        if (maxLen > 0) {
            widestDataList = currentWidestDataList;
        } else {
            widestDataList = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
        setState(() {
        // TRADUCIDO: Mensaje de error de carga
        _dataErrorMessage = t.get('error_data_load'); 
        _isLoadingData = false;
      });
      // El print es para el log de depuración, se mantiene en inglés o es una decisión de desarrollo.
      print('Error al obtener datos de la gráfica multi-fuente: $e'); 
    }
  }
  
  Future<DateTime?> _pickDateTime(DateTime initialDateTime, DateTime firstDate, DateTime lastDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> pickStartDateTime() async {
    final maxDate = endDate.isAfter(DateTime.now()) ? DateTime.now() : endDate;
    final newStart = await _pickDateTime(
      startDate, 
      DateTime.now().subtract(const Duration(days: 365)), 
      maxDate,
    );
    
    if (newStart == null) return;

    if (newStart.isAfter(endDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // TRADUCIDO: Mensaje de error de fecha de inicio
        SnackBar(content: Text(t.get('error_date_start'))),
      );
      return;
    }

    setState(() {
      startDate = newStart;
    });
    fetchData();
  }

  Future<void> pickEndDateTime() async {
    final newEnd = await _pickDateTime(
      endDate, 
      startDate,
      DateTime.now(),
    );
    
    if (newEnd == null) return;

    if (newEnd.isBefore(startDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // TRADUCIDO: Mensaje de error de fecha de fin
        SnackBar(content: Text(t.get('error_date_end'))),
      );
      return;
    }

    setState(() {
      endDate = newEnd;
    });
    fetchData();
  }
  
  
  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM HH:mm');
    
    final List<CartesianSeries> seriesList = [];
    int maxLen = 0;
    
    // 1. Encontrar la lista de datos más larga y su longitud para el slider
    for (var dataList in multiData.values) {
        if (dataList.length > maxLen) {
            maxLen = dataList.length;
        }
    }
    
    // 2. Asignación de Ejes: El primer elemento usa el Eje Primario, el resto el Secundario
    final ChartSource? primarySource = widget.sources.isNotEmpty ? widget.sources.first : null;
    final List<ChartSource> secondarySources = widget.sources.skip(1).toList();
    
    // --- Lógica de Generación de Series ---
    
    if (xRange != null) {
      final startIdx = xRange!.start.round(); 
      final endIdx = xRange!.end.round();
      
      // 3. Eje Primario
      if (primarySource != null) {
        final rawData = multiData[primarySource.id];
        if (rawData != null && rawData.isNotEmpty) {
          final filteredData = rawData.sublist(startIdx, (endIdx + 1).clamp(startIdx, rawData.length));
          
          seriesList.add(
            LineSeries<ChartData, DateTime>(
              name: primarySource.displayName, 
              dataSource: filteredData,
              xValueMapper: (d, _) => d.time,
              yValueMapper: (d, _) => d.value,
              color: primarySource.color, 
              markerSettings: const MarkerSettings(isVisible: false),
              enableTooltip: true,
            ),
          );
        }
      }

      // 4. Eje Secundario (si hay más de una fuente)
      if (secondarySources.isNotEmpty) {
        for (var source in secondarySources) {
          final rawData = multiData[source.id];
          if (rawData != null && rawData.isNotEmpty) {
            final filteredData = rawData.sublist(startIdx, (endIdx + 1).clamp(startIdx, rawData.length));
            
            seriesList.add(
              LineSeries<ChartData, DateTime>(
                name: source.displayName, 
                dataSource: filteredData,
                xValueMapper: (d, _) => d.time,
                yValueMapper: (d, _) => d.value,
                yAxisName: 'secondaryYAxis', // ¡Clave! Asigna al eje secundario
                color: source.color, 
                markerSettings: const MarkerSettings(isVisible: false),
                enableTooltip: true,
              ),
            );
          }
        }
      }
    }
    
    double sliderInterval = 1;
    if (maxLen > 5) {
      sliderInterval = ((maxLen - 1) / 5).ceilToDouble();
    }


    return Scaffold(
      // CORRECCIÓN 1: Título del AppBar usando traducción
      appBar: AppBar(title: Text(t.get('chart_comparison_title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: pickStartDateTime,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  // TRADUCIDO: 'start'
                  label: Text('${t.get('start')}: ${formatter.format(startDate)}'),
                ),
                ElevatedButton.icon(
                  onPressed: pickEndDateTime,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  // TRADUCIDO: 'end'
                  label: Text('${t.get('end')}: ${formatter.format(endDate)}'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : _dataErrorMessage != null
                  ? Center(child: Text(_dataErrorMessage!))
                  : seriesList.isEmpty
                      // CORRECCIÓN 2: Mensaje de "No hay datos" usando traducción
                      ? Center(child: Text(t.get('no_data_available'))) 
                      : SfCartesianChart(
                          primaryXAxis: DateTimeAxis(
                            dateFormat: DateFormat('HH:mm\ndd/MM'),
                          ),
                          // Eje Y Primario (Izquierda)
                          primaryYAxis: NumericAxis(
                            title: AxisTitle(
                              text: primarySource != null 
                                ? primarySource.displayName 
                                : '', // Usa un string vacío si no hay fuente.
                            ),
                          ),
                          // Ejes Y Secundarios (Solo creamos uno a la Derecha)
                          axes: secondarySources.isNotEmpty
                            ? <ChartAxis>[
                                NumericAxis(
                                  name: 'secondaryYAxis', // Nombre usado en la serie
                                  opposedPosition: true, // Lo coloca a la derecha
                                  title: AxisTitle(
                                    text: secondarySources.map((s) => s.fieldName).join(' / '), // Muestra los nombres de los campos agrupados
                                  ),
                                )
                              ]
                            : <ChartAxis>[],
                          
                          legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                          
                          // ---------------------------------------------------------
                          // TOOLTIP (No contiene texto fijo que requiera 't.get()')
                          // ---------------------------------------------------------
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            header: '', 
                            
                            builder: (
                              dynamic data, 
                              ChartPoint<dynamic> point, 
                              ChartSeries<dynamic, dynamic> series, 
                              int pointIndex, 
                              int seriesIndex 
                            ) {
                              // El 'data' es el objeto ChartData
                              final ChartData chartData = data as ChartData; 
                              
                              // Formato de Fecha/Hora: dd/MM/yyyy HH:mm
                              final String dateTimeFormatted = DateFormat('dd/MM/yyyy HH:mm').format(chartData.time);

                              // Formato de Valor (a dos decimales)
                              final String valueFormatted = chartData.value.toStringAsFixed(2);
                              
                              // Obtener el nombre de la serie (ej. "Temperatura")
                              final String seriesName = series.name ?? t.get('default_value_label'); // Uso t.get aquí por si el nombre de la serie es null
                              
                              // Devolver un WIDGET (Container) con el contenido
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$dateTimeFormatted\n$seriesName: $valueFormatted',
                                  style: const TextStyle(fontSize: 12, color: Colors.black),
                                ),
                              );
                            },
                          ),
                          // ---------------------------------------------------------

                          series: seriesList, 
                        ),
          ),
          // Slider de rango para el zoom/filtrado
          if (xRange != null && widestDataList.isNotEmpty) // Usa widestDataList
            Padding(
              padding: const EdgeInsets.all(16),
              child: sliders.SfRangeSlider(
                min: 0.0,
                max: (maxLen - 1).toDouble(),
                values: xRange!,
                showLabels: false,
                interval: sliderInterval,
                enableTooltip: true,
                tooltipTextFormatterCallback: (actualValue, formattedText) {
                    final index = actualValue.round();
                    if (index >= 0 && index < widestDataList.length) { // Usa widestDataList
                        return DateFormat('HH:mm').format(widestDataList[index].time); 
                    }
                    return formattedText;
                },
                onChanged: (values) {
                  setState(() {
                    xRange = values;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}