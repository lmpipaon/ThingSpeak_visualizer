// Copyright 2025 Luis Pipaon.
//
// Licensed under the MIT license. See LICENSE file in the project root for details.


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart' as sliders;
import 'package:shared_preferences/shared_preferences.dart';

// ======================================================
// MODELO DE CANAL
// ======================================================
class Channel {
  final String id;
  final String readApiKey;
  final String name;

  Channel({required this.id, required this.readApiKey, required this.name});
}

// ======================================================
// SERVICIO THINGSPEAK
// ======================================================
class ThingSpeakService {
  Future<List<Channel>> getUserChannels(String userApiKey) async {
    final url =
        Uri.parse('https://api.thingspeak.com/channels.json?api_key=$userApiKey');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error al cargar canales');
    }

    final List data = json.decode(response.body);
    List<Channel> channels = [];

    for (var channelJson in data) {
      String id = channelJson['id'].toString();
      String name = channelJson['name'] ?? 'Sin nombre';
      String? readApiKey;

      for (var key in channelJson['api_keys']) {
        if (key['write_flag'] == false) {
          readApiKey = key['api_key'];
          break;
        }
      }

      if (readApiKey != null) {
        channels.add(Channel(id: id, readApiKey: readApiKey, name: name));
      }
    }

    return channels;
  }

  Future<Map<String, String>> getLastFeed(
      Channel channel, Map<String, String> fieldNameToFieldX) async {
    final url = Uri.parse(
        'https://api.thingspeak.com/channels/${channel.id}/feeds.json?api_key=${channel.readApiKey}&results=1');
    final response = await http.get(url);

    final data = json.decode(response.body);
    final feeds = data['feeds'];
    final channelInfo = data['channel'];

    if (feeds == null || feeds.isEmpty) return {};

    final lastFeed = feeds[0] as Map<String, dynamic>;
    Map<String, String> fields = {};

    lastFeed.forEach((key, value) {
      if (key.startsWith('field') && value != null) {
        final fieldName = channelInfo[key] ?? key;
        fields[fieldName] = value.toString();
        fieldNameToFieldX[fieldName] = key;
      }
    });

    return fields;
  }

  Future<List<ChartData>> getFieldValuesWithTime(
      Channel channel, String fieldX,
      {DateTime? start, DateTime? end, int results = 100}) async {
    String urlStr =
        'https://api.thingspeak.com/channels/${channel.id}/feeds.json?api_key=${channel.readApiKey}&results=$results';

    if (start != null && end != null) {
      final startStr = Uri.encodeComponent(start.toIso8601String());
      final endStr = Uri.encodeComponent(end.toIso8601String());
      urlStr += '&start=$startStr&end=$endStr';
    }

    final url = Uri.parse(urlStr);
    final response = await http.get(url);

    final data = json.decode(response.body);
    final feeds = data['feeds'] as List<dynamic>;
    List<ChartData> values = [];

    for (var feed in feeds) {
      if (feed[fieldX] != null && feed['created_at'] != null) {
        final val = double.tryParse(feed[fieldX].toString());
        final time = DateTime.tryParse(feed['created_at']);
        if (val != null && time != null) {
          values.add(ChartData(time, val));
        }
      }
    }

    return values;
  }
}

// ======================================================
// MODELO DE DATOS PARA LA GRÁFICA
// ======================================================
class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

// ======================================================
// TRADUCCIONES EN DART
// ======================================================
class Translations {
  final String lang;
  Translations(this.lang);

  static const Map<String, Map<String, String>> _data = {
    'es': {
      'initial_config': 'Configuración inicial',
      'api_keys': 'API keys (separadas por coma)',
      'save': 'Guardar',
      'select_channel': 'Seleccionar canal',
      'choose_channel': 'Elige un canal',
      'reset': 'Resetear configuración',
    },
    'en': {
      'initial_config': 'Initial Configuration',
      'api_keys': 'API keys (comma separated)',
      'save': 'Save',
      'select_channel': 'Select channel',
      'choose_channel': 'Choose a channel',
      'reset': 'Reset Config',
    },
    'eu': {
      'initial_config': 'Hasierako konfigurazioa',
      'api_keys': 'API giltzak (komaz bereizita)',
      'save': 'Gorde',
      'select_channel': 'Kanal hautatu',
      'choose_channel': 'Hautatu kanal bat',
      'reset': 'Konfigurazioa berrezarri',
    },
  };

  String get(String key) {
    return _data[lang]?[key] ?? key;
  }
}

// ======================================================
// APP PRINCIPAL
// ======================================================
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: InitialLoader(),
  ));
}

// ======================================================
// LOADER INICIAL + CONFIG DIALOG
// ======================================================
class InitialLoader extends StatefulWidget {
  const InitialLoader({super.key});

  @override
  State<InitialLoader> createState() => _InitialLoaderState();
}

class _InitialLoaderState extends State<InitialLoader> {
  String language = 'es';
  List<String> userApiKeys = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'es';
    userApiKeys = prefs.getStringList('apiKeys') ?? [];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userApiKeys.isEmpty) {
        _showInitialConfig();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChannelSelectorScreen(
              language: language,
              userApiKeys: userApiKeys,
            ),
          ),
        );
      }
    });
  }

  Future<void> _showInitialConfig() async {
    final apiController = TextEditingController(text: userApiKeys.join(','));
    String tempLang = language;
    final t = Translations(language);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t.get('initial_config')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: apiController,
                  decoration: InputDecoration(labelText: t.get('api_keys')),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Español'),
                      value: 'es',
                      groupValue: tempLang,
                      onChanged: (v) {
                        setDialogState(() {
                          tempLang = v!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('English'),
                      value: 'en',
                      groupValue: tempLang,
                      onChanged: (v) {
                        setDialogState(() {
                          tempLang = v!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Euskara'),
                      value: 'eu',
                      groupValue: tempLang,
                      onChanged: (v) {
                        setDialogState(() {
                          tempLang = v!;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                language = tempLang;
                userApiKeys = apiController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList('apiKeys', userApiKeys);
                await prefs.setString('language', language);

                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelSelectorScreen(
                      language: language,
                      userApiKeys: userApiKeys,
                    ),
                  ),
                );
              },
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ======================================================
// SELECTOR DE CANAL CON BOTÓN RESET
// ======================================================
class ChannelSelectorScreen extends StatefulWidget {
  final String language;
  final List<String> userApiKeys;

  const ChannelSelectorScreen({super.key, required this.language, required this.userApiKeys});

  @override
  State<ChannelSelectorScreen> createState() => _ChannelSelectorScreenState();
}

class _ChannelSelectorScreenState extends State<ChannelSelectorScreen> {
  final ThingSpeakService service = ThingSpeakService();
  List<Channel> channels = [];
  Channel? selectedChannel;
  Map<String, String> lastFields = {};
  Map<String, String> fieldNameToFieldX = {};
  bool loading = true;
  bool loadingFields = false;
  late Translations t;

  @override
  void initState() {
    super.initState();
    t = Translations(widget.language);
    loadAllChannels();
  }

  Future<void> loadAllChannels() async {
    List<Channel> allChannels = [];
    for (var apiKey in widget.userApiKeys) {
      final userChannels = await service.getUserChannels(apiKey);
      allChannels.addAll(userChannels);
    }
    setState(() {
      channels = allChannels;
      loading = false;
    });
  }

  Future<void> loadLastFields(Channel channel) async {
    setState(() {
      loadingFields = true;
      lastFields = {};
      fieldNameToFieldX = {};
    });
    final fields = await service.getLastFeed(channel, fieldNameToFieldX);
    setState(() {
      lastFields = fields;
      loadingFields = false;
    });
  }

  Future<void> resetConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKeys');
    await prefs.remove('language');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const InitialLoader()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('select_channel')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.get('reset'),
            onPressed: resetConfig,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButton<Channel>(
                    isExpanded: true,
                    hint: Text(t.get('choose_channel')),
                    value: selectedChannel,
                    items: channels.map((channel) {
                      return DropdownMenuItem(
                        value: channel,
                        child: Text(channel.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedChannel = value;
                        lastFields = {};
                        fieldNameToFieldX = {};
                      });
                      if (value != null) loadLastFields(value);
                    },
                  ),
                  const SizedBox(height: 20),
                  loadingFields
                      ? const CircularProgressIndicator()
                      : Expanded(
                          child: ListView(
                            children: lastFields.entries.map((e) {
                              return ListTile(
                                title: Text('${e.key}: ${e.value}'),
                                onTap: () async {
                                  final fieldX = fieldNameToFieldX[e.key]!;
                                  final now = DateTime.now();
                                  final sixHoursAgo = now.subtract(const Duration(hours: 6));
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FieldChartScreen(
                                        channel: selectedChannel!,
                                        fieldName: e.key,
                                        fieldX: fieldX,
                                        start: sixHoursAgo,
                                        end: now,
                                        language: widget.language,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}

// ======================================================
// GRÁFICA CON SELECTOR DE FECHA/HORA Y RANGO
// ======================================================
class FieldChartScreen extends StatefulWidget {
  final Channel channel;
  final String fieldName;
  final String fieldX;
  final DateTime start;
  final DateTime end;
  final String language;

  const FieldChartScreen({
    super.key,
    required this.channel,
    required this.fieldName,
    required this.fieldX,
    required this.start,
    required this.end,
    required this.language,
  });

  @override
  State<FieldChartScreen> createState() => _FieldChartScreenState();
}

class _FieldChartScreenState extends State<FieldChartScreen> {
  late DateTime startDate;
  late DateTime endDate;
  List<ChartData> data = [];
  sliders.SfRangeValues? xRange;

  final ThingSpeakService service = ThingSpeakService();

  late Translations t;

  @override
  void initState() {
    super.initState();
    startDate = widget.start;
    endDate = widget.end;
    t = Translations(widget.language);
    fetchData();
  }

  Future<void> fetchData() async {
    final values = await service.getFieldValuesWithTime(
      widget.channel,
      widget.fieldX,
      start: startDate,
      end: endDate,
      results: 8000,
    );

    setState(() {
      data = values;
      xRange = sliders.SfRangeValues(0, (data.length - 1).toDouble());
    });
  }

  Future<void> pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: endDate,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startDate),
    );
    if (time == null) return;

    final newStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (newStart.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de inicio no puede ser posterior a la fecha final')),
      );
      return;
    }

    setState(() {
      startDate = newStart;
    });
    fetchData();
  }

  Future<void> pickEndDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(endDate),
    );
    if (time == null) return;

    final newEnd = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (newEnd.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha final no puede ser anterior a la fecha de inicio')),
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

    final chartData = <ChartData>[];
    if (data.isNotEmpty && xRange != null) {
      final startIdx = xRange!.start.toInt();
      final endIdx = xRange!.end.toInt();
      for (int i = startIdx; i <= endIdx && i < data.length; i++) {
        chartData.add(data[i]);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Gráfica ${widget.fieldName}')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: pickStartDateTime,
                child: Text('Inicio: ${formatter.format(startDate)}'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: pickEndDateTime,
                child: Text('Fin: ${formatter.format(endDate)}'),
              ),
            ],
          ),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: DateTimeAxis(),
              primaryYAxis: NumericAxis(),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                  final ChartData d = data;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${formatter.format(d.time)}\nValor: ${d.value}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
              series: <CartesianSeries>[
                LineSeries<ChartData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (d, _) => d.time,
                  yValueMapper: (d, _) => d.value,
                  markerSettings: const MarkerSettings(isVisible: false),
                  enableTooltip: true,
                ),
              ],
            ),
          ),
          if (xRange != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: sliders.SfRangeSlider(
                min: 0,
                max: (data.length - 1).toDouble(),
                values: xRange!,
                showLabels: true,
                interval: ((data.length - 1) / 5).ceilToDouble(),
                enableTooltip: true,
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

