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
import 'package:url_launcher/url_launcher.dart';

// ======================================================
// CONSTANTES GLOBALES
// ======================================================
const int maxResultsForChart = 8000;
const int defaultResultsForChart = 100;

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
// MODELO DE DATOS PARA LA GRÁFICA
// ======================================================
class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

// ======================================================
// MODELO DE FUENTE DE DATOS PARA LA GRÁFICA
// ======================================================
class ChartSource {
  final Channel channel;
  final String fieldName;
  final String fieldX;
  final Color color; // Color para diferenciar en la gráfica

  ChartSource({
    required this.channel,
    required this.fieldName,
    required this.fieldX,
    required this.color,
  });

  String get id => '${channel.id}_$fieldX';
  String get displayName => '${channel.name} / $fieldName';
}

// ======================================================
// SERVICIO THINGSPEAK
// ======================================================
class ThingSpeakService {
  Future<List<Channel>> getUserChannels(String userApiKey) async {
    final url =
        Uri.parse('https://api.thingspeak.com/channels.json?api_key=$userApiKey');
    
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Error ${response.statusCode}: No se pudo cargar canales para la API Key proporcionada.');
      }

      final List data = json.decode(response.body);
      List<Channel> channels = [];

      for (var channelJson in data) {
        String id = channelJson['id'].toString();
        String name = channelJson['name'] ?? 'Sin nombre';
        String? readApiKey;

        // Búsqueda de la clave de API de solo lectura
        for (var key in channelJson['api_keys']) {
          // El campo 'write_flag' es un booleano, si es false, es de lectura.
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
    } catch (e) {
      // Re-lanzar una excepción con más contexto si la llamada falla.
      throw Exception('Fallo en la conexión o formato de datos: $e');
    }
  }

  Future<Map<String, String>> getLastFeed(
      Channel channel, Map<String, String> fieldNameToFieldX) async {
    final url = Uri.parse(
        'https://api.thingspeak.com/channels/${channel.id}/feeds.json?api_key=${channel.readApiKey}&results=1');
    final response = await http.get(url);

    // Mejora: Comprobar el código de estado antes de decodificar
    if (response.statusCode != 200) {
      throw Exception('Error al obtener la última lectura del canal');
    }

    final data = json.decode(response.body);
    final feeds = data['feeds'];
    final channelInfo = data['channel'];

    if (feeds == null || feeds.isEmpty) return {};

    final lastFeed = feeds[0] as Map<String, dynamic>;
    Map<String, String> fields = {};

    lastFeed.forEach((key, value) {
      if (key.startsWith('field') && value != null) {
        // Usa el nombre del campo definido en ThingSpeak si existe
        final fieldName = channelInfo[key] ?? key; 
        fields[fieldName] = value.toString();
        fieldNameToFieldX[fieldName] = key;
      }
    });

    return fields;
  }

  Future<List<ChartData>> getFieldValuesWithTime(
      Channel channel, String fieldX,
      {DateTime? start, DateTime? end, int results = defaultResultsForChart}) async {
    String urlStr =
        'https://api.thingspeak.com/channels/${channel.id}/feeds.json?api_key=${channel.readApiKey}&results=$results';

    if (start != null && end != null) {
      // Mejora: La API de ThingSpeak usa 'start'/'end' para los parámetros
      final startStr = Uri.encodeComponent(start.toIso8601String());
      final endStr = Uri.encodeComponent(end.toIso8601String());
      urlStr += '&start=$startStr&end=$endStr';
    }

    final url = Uri.parse(urlStr);
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error al cargar datos del campo para la gráfica');
    }

    final data = json.decode(response.body);
    final feeds = data['feeds'] as List<dynamic>;
    List<ChartData> values = [];

    for (var feed in feeds) {
      // Mejora: Uso de null-aware operators y casting seguro
      final rawValue = feed[fieldX];
      final rawTime = feed['created_at'];

      if (rawValue != null && rawTime != null) {
        final val = double.tryParse(rawValue.toString());
        final time = DateTime.tryParse(rawTime);
        if (val != null && time != null) {
          values.add(ChartData(time.toLocal(), val)); // Convertir a hora local
        }
      }
    }

    return values;
  }
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
      'select_channel': 'Seleccionar canales y campos',
      'choose_channel': 'Elige un canal',
      'reset': 'Resetear configuración',
      'error_loading_channels': 'Error al cargar canales.',
      'error_config_title': 'Error de Configuración',
      'error_config_message': 'Por favor, comprueba tus API keys e inténtalo de nuevo.',
      'error_date_start': 'La fecha de inicio no puede ser posterior a la fecha final',
      'error_date_end': 'La fecha final no puede ser anterior a la fecha de inicio',
      'chart_title': 'Gráfica',
      'start': 'Inicio',
      'end': 'Fin',
      'error_data_load': 'Error al cargar los datos del gráfico.',
      'settings_title': 'Ajustes', 
      'api_keys_config': 'Configuración de API Keys', 
      'language_config': 'Configuración de Idioma', 
      'about_title': 'Acerca de', 
      'author': 'Autor', 
      'github_link': 'Código Fuente (GitHub)', 
      'reset_config_full': 'Resetear TODA la Configuración (API Keys y Idioma)', 
      'reset_config_warning': 'Esto eliminará tus API Keys e idioma guardados y te llevará a la configuración inicial.', 
    },
    'en': {
      'initial_config': 'Initial Configuration',
      'api_keys': 'API keys (comma separated)',
      'save': 'Save',
      'select_channel': 'Select Channels and Fields',
      'choose_channel': 'Choose a channel',
      'reset': 'Reset Config',
      'error_loading_channels': 'Error loading channels.',
      'error_config_title': 'Configuration Error',
      'error_config_message': 'Please check your API keys and try again.',
      'error_date_start': 'Start date cannot be after the end date',
      'error_date_end': 'End date cannot be before the start date',
      'chart_title': 'Chart',
      'start': 'Start',
      'end': 'End',
      'error_data_load': 'Error loading chart data.',
      'settings_title': 'Settings', 
      'api_keys_config': 'API Keys Configuration', 
      'language_config': 'Language Configuration', 
      'about_title': 'About', 
      'author': 'Author', 
      'github_link': 'Source Code (GitHub)', 
      'reset_config_full': 'Reset ALL Configuration (API Keys and Language)', 
      'reset_config_warning': 'This will remove your saved API Keys and language and take you to the initial setup.', 
    },
    'eu': {
      'initial_config': 'Hasierako konfigurazioa',
      'api_keys': 'API giltzak (komaz bereizita)',
      'save': 'Gorde',
      'select_channel': 'Kanalak eta eremuak hautatu',
      'choose_channel': 'Hautatu kanal bat',
      'reset': 'Konfigurazioa berrezarri',
      'error_loading_channels': 'Errorea kanalak kargatzean.',
      'error_config_title': 'Konfigurazio-errorea',
      'error_config_message': 'Mesedez, egiaztatu zure API giltzak eta saiatu berriro.',
      'error_date_start': 'Hasierako data ezin da amaierako data baino beranduagoa izan',
      'error_date_end': 'Amaierako data ezin da hasierako data baino lehenagoa izan',
      'chart_title': 'Grafikoa',
      'start': 'Hasiera',
      'end': 'Amaiera',
      'error_data_load': 'Errorea grafikoaren datuak kargatzean.',
      'settings_title': 'Ezarpenak', 
      'api_keys_config': 'API Giltzen Konfigurazioa', 
      'language_config': 'Hizkuntza Konfigurazioa', 
      'about_title': 'Honi Buruz', 
      'author': 'Egilea', 
      'github_link': 'Iturburu Kodea (GitHub)', 
      'reset_config_full': 'Konfigurazio GUZTIA berrezarri (API Giltzak eta Hizkuntza)', 
      'reset_config_warning': 'Honek gordetako API Giltzak eta hizkuntza ezabatuko ditu eta hasierako konfiguraziora eramango zaitu.', 
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
  bool _isLoading = true; 

  late final TextEditingController _apiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'es';
    userApiKeys = prefs.getStringList('apiKeys') ?? [];
    _apiController.text = userApiKeys.join(','); 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (userApiKeys.isEmpty) {
        setState(() { _isLoading = false; });
        _showInitialConfig();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChartSourceSelectorScreen(
              language: language,
              userApiKeys: userApiKeys,
            ),
          ),
        );
      }
    });
  }

  Future<void> _showInitialConfig() async {
    String tempLang = language;
    
    Translations t = Translations(tempLang);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          t = Translations(tempLang); 
          return AlertDialog(
            title: Text(t.get('initial_config')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _apiController,
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
                onPressed: () {
                  final keys = _apiController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  
                  Navigator.of(context).pop({
                    'apiKeys': keys,
                    'language': tempLang,
                  });
                },
                child: Text(t.get('save')),
              ),
            ],
          );
        }
      ),
    );

    // Lógica de guardado y navegación después de cerrar el diálogo
    if (result != null && mounted) {
      userApiKeys = result['apiKeys'];
      language = result['language'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('apiKeys', userApiKeys);
      await prefs.setString('language', language);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChartSourceSelectorScreen(
            language: language,
            userApiKeys: userApiKeys,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading ? const CircularProgressIndicator() : Container(),
      ),
    );
  }
}

// ======================================================
// SELECTOR DE FUENTES DE GRÁFICA (MULTI-CANAL)
// ======================================================
class ChartSourceSelectorScreen extends StatefulWidget {
  final String language;
  final List<String> userApiKeys;

  const ChartSourceSelectorScreen({super.key, required this.language, required this.userApiKeys});

  @override
  State<ChartSourceSelectorScreen> createState() => _ChartSourceSelectorScreenState();
}

class _ChartSourceSelectorScreenState extends State<ChartSourceSelectorScreen> {
  final ThingSpeakService service = ThingSpeakService();
  List<Channel> channels = [];
  Map<String, Map<String, String>> channelFields = {}; // {Channel.id: {FieldName: FieldX}}
  List<ChartSource> selectedSources = [];
  
  bool loading = true;
  late Translations t;
  String? errorMessage; 
  
  // Lista de colores para asignar a cada nueva fuente
  final List<Color> availableColors = [
    Colors.blue, Colors.red, Colors.green, Colors.purple, 
    Colors.orange, Colors.teal, Colors.brown, Colors.pink
  ];

  @override
  void initState() {
    super.initState();
    t = Translations(widget.language);
    loadAllChannelsAndFields();
  }
  
  // Función auxiliar para recargar la configuración del widget y los canales
  Future<void> _reloadConfigAndChannels() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!mounted) return;
    // Esto es vital para resetear completamente el estado si hay cambios
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChartSourceSelectorScreen( 
          language: prefs.getString('language') ?? 'es', 
          userApiKeys: prefs.getStringList('apiKeys') ?? [], 
        ),
      ),
    );
  }

  // Carga todos los canales y sus campos disponibles
  Future<void> loadAllChannelsAndFields() async {
    setState(() {
      loading = true;
      errorMessage = null; 
      channels = [];
      channelFields = {};
    });

    try {
      final futures = widget.userApiKeys.map((apiKey) => service.getUserChannels(apiKey));
      final results = await Future.wait(futures); 
      
      List<Channel> allChannels = [];
      for (var userChannels in results) {
          allChannels.addAll(userChannels);
      }
      
      // Ahora, cargar los campos de cada canal (necesitamos la última lectura para los nombres)
      List<Future<void>> fieldFutures = [];
      
      for (var channel in allChannels) {
          fieldFutures.add(() async {
              try {
                  Map<String, String> fieldNameToFieldX = {};
                  // getLastFeed rellena fieldNameToFieldX
                  await service.getLastFeed(channel, fieldNameToFieldX); 
                  if (fieldNameToFieldX.isNotEmpty) {
                    channelFields[channel.id] = fieldNameToFieldX;
                  }
              } catch (e) {
                  print('Advertencia: No se pudieron cargar los campos para el canal ${channel.name}: $e');
              }
          }());
      }
      await Future.wait(fieldFutures);
      
      if (!mounted) return;
      setState(() {
        // Solo incluimos canales para los que pudimos cargar al menos un campo
        channels = allChannels.where((c) => channelFields.containsKey(c.id)).toList(); 
        loading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      final detailedError = e.toString().contains(':') 
        ? e.toString().split(':')[1].trim()
        : e.toString();
        
      setState(() {
        errorMessage = '${t.get('error_loading_channels')}\n$detailedError';
        loading = false;
      });
      _showErrorDialog(t.get('error_config_title'), errorMessage!);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            // Opción para ir a la configuración a corregir las keys
            onPressed: () {
              Navigator.of(context).pop(); 
              // Llama directamente a la configuración para corregir las keys
              _handleSettingsNavigation(context, navigateToApiKeys: true);
            },
            child: Text(t.get('settings_title')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Función para manejar la navegación a Settings y la recarga
  Future<void> _handleSettingsNavigation(BuildContext context, {bool navigateToApiKeys = false}) async {
    
    // CORRECCIÓN DE TIPO: Especificamos <bool> en MaterialPageRoute
    final initialRoute = navigateToApiKeys
      ? MaterialPageRoute<bool>(
          builder: (_) => ApiKeysConfigScreen(
            language: widget.language,
            userApiKeys: widget.userApiKeys,
          ),
        )
      : MaterialPageRoute<bool>(
          builder: (_) => SettingsScreen(
            language: widget.language,
            userApiKeys: widget.userApiKeys,
          ),
        );
        
    final bool? configChanged = await Navigator.push(
      context,
      initialRoute,
    );

    // Si se cambiaron las API Keys o el idioma, recarga ChartSourceSelectorScreen
    if (configChanged == true) {
      _reloadConfigAndChannels();
    }
  }

  // Diálogo para añadir una nueva fuente de datos
  Future<void> _addSource() async {
    Channel? selectedChannel;
    String? selectedField;

    if (channels.isEmpty) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Map<String, String>? fields = selectedChannel != null 
                ? channelFields[selectedChannel!.id] 
                : null;
            
            return AlertDialog(
              title: const Text('Añadir Fuente de Datos'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Channel>(
                    isExpanded: true,
                    hint: const Text('Seleccionar Canal'),
                    value: selectedChannel,
                    items: channels.map((channel) {
                      return DropdownMenuItem(
                        value: channel,
                        child: Text(channel.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedChannel = value;
                        selectedField = null; // Resetear campo al cambiar de canal
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (selectedChannel != null && fields != null)
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Seleccionar Campo'),
                      value: selectedField,
                      items: fields.keys.map((fieldName) {
                        return DropdownMenuItem(
                          value: fieldName,
                          child: Text(fieldName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedField = value;
                        });
                      },
                    ),
                ],
              ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedChannel != null && selectedField != null
                      ? () {
                          // Buscar el FieldX correspondiente
                          final fieldX = channelFields[selectedChannel!.id]![selectedField]!;
                          
                          // Asignar el siguiente color disponible
                          final colorIndex = selectedSources.length % availableColors.length;
                          final color = availableColors[colorIndex];
                          
                          final newSource = ChartSource(
                            channel: selectedChannel!,
                            fieldName: selectedField!,
                            fieldX: fieldX,
                            color: color,
                          );
                          
                          setState(() {
                            selectedSources.add(newSource);
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(t.get('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // Función para eliminar una fuente
  void _removeSource(String id) {
    setState(() {
      selectedSources.removeWhere((source) => source.id == id);
    });
  }

  // Función para ir a la gráfica
  void _goToChart() {
    final now = DateTime.now();
    final sixHoursAgo = now.subtract(const Duration(hours: 6)); 
    
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiFieldChartScreen(
          sources: selectedSources,
          start: sixHoursAgo,
          end: now,
          language: widget.language,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('select_channel')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: t.get('settings_title'),
            onPressed: () => _handleSettingsNavigation(context),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _reloadConfigAndChannels();
                          },
                          child: Text(t.get('reset')),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Lista de Fuentes Seleccionadas
                      Expanded(
                        child: ListView(
                          children: [
                            Text('Fuentes a comparar:', style: Theme.of(context).textTheme.titleMedium),
                            ...selectedSources.map((source) => ListTile(
                              leading: Icon(Icons.circle, color: source.color),
                              title: Text(source.displayName),
                              subtitle: Text('Canal ID: ${source.channel.id}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeSource(source.id),
                              ),
                            )).toList(),
                            
                            // Botón para añadir una nueva fuente
                            TextButton.icon(
                              onPressed: channels.isEmpty ? null : _addSource,
                              icon: const Icon(Icons.add),
                              label: const Text('Añadir Nueva Fuente'),
                            ),
                            // Indicación de ejes (Importante para la versión con Ejes Duales)
                            if (selectedSources.length > 1) 
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Nota: El primer campo (arriba) usará el eje Y izquierdo. Los demás usarán el eje Y derecho.',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // Botón para generar la gráfica
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: selectedSources.isNotEmpty ? _goToChart : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Generar Gráfica de Comparación', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ======================================================
// PANTALLA DE AJUSTES
// ======================================================
class SettingsScreen extends StatelessWidget {
  final String language;
  final List<String> userApiKeys;

  const SettingsScreen({super.key, required this.language, required this.userApiKeys});

  // Función para manejar el reseteo completo
  Future<void> _resetConfig(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKeys');
    await prefs.remove('language');

    // Navegar de vuelta al loader/configurador inicial (reconstruye todo)
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const InitialLoader()),
      (Route<dynamic> route) => false,
    );
  }

  // Función que navega a una subpantalla. Si la subpantalla devuelve 'true',
  // SettingsScreen debe devolver 'true' al ChartSourceSelectorScreen para forzar la recarga.
  Future<void> _navigateAndPropagateChange(BuildContext context, Widget screen) async {
    // Especificamos el tipo de retorno de la ruta como <bool>
    final bool? result = await Navigator.push<bool>( 
      context,
      MaterialPageRoute<bool>(builder: (_) => screen),
    );
    
    // Si la pantalla hija devolvió true (indicando cambio), hacemos pop de
    // SettingsScreen con true también, lo que forzará la recarga en el padre.
    if (result == true && context.mounted) {
      // Devolvemos true para que el ChartSourceSelectorScreen sepa que debe recargar
      Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations(language);
    
    return Scaffold(
      appBar: AppBar(title: Text(t.get('settings_title'))),
      body: ListView(
        children: [
          // Opción 1: Configuración de API Keys
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(t.get('api_keys_config')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateAndPropagateChange(
              context,
              ApiKeysConfigScreen(
                language: language,
                userApiKeys: userApiKeys,
              ),
            ),
          ),
          const Divider(),
          // Opción 2: Configuración de Idioma
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(t.get('language_config')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateAndPropagateChange(
              context,
              LanguageConfigScreen(language: language),
            ),
          ),
          const Divider(),
          // Opción 3: Acerca de
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(t.get('about_title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // No necesita propagar el cambio, solo navega
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AboutScreen(language: language)),
              );
            },
          ),
          const Divider(),
          // Opción 4: Resetear Configuración
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  label: Text(t.get('reset_config_full')),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.get('reset')),
                        content: Text(t.get('reset_config_warning')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(); // Cerrar el diálogo
                              _resetConfig(context); // Ejecutar el reseteo
                            },
                            child: const Text('Resetear'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ======================================================
// PANTALLA DE CONFIGURACIÓN DE API KEYS
// ======================================================
class ApiKeysConfigScreen extends StatefulWidget {
  final String language;
  final List<String> userApiKeys;

  const ApiKeysConfigScreen({
    super.key,
    required this.language,
    required this.userApiKeys,
  });

  @override
  State<ApiKeysConfigScreen> createState() => _ApiKeysConfigScreenState();
}

class _ApiKeysConfigScreenState extends State<ApiKeysConfigScreen> {
  late final TextEditingController _apiController;
  late final Translations t;

  @override
  void initState() {
    super.initState();
    t = Translations(widget.language);
    _apiController = TextEditingController(text: widget.userApiKeys.join(','));
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKeys() async {
    final keys = _apiController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (keys.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce al menos una API Key.')),
      );
      return;
    }
    
    // Verificar si las claves realmente cambiaron
    final bool changed = !listEquals(keys, widget.userApiKeys);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('apiKeys', keys);

    if (!mounted) return;
    // Devolvemos 'true' solo si hubo un cambio real.
    Navigator.pop(context, changed); 
  }
  
  // Función de ayuda para comparar listas
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.get('api_keys_config'))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _apiController,
              decoration: InputDecoration(
                labelText: t.get('api_keys'),
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveApiKeys,
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// PANTALLA DE CONFIGURACIÓN DE IDIOMA
// ======================================================
class LanguageConfigScreen extends StatefulWidget {
  final String language;

  const LanguageConfigScreen({super.key, required this.language});

  @override
  State<LanguageConfigScreen> createState() => _LanguageConfigScreenState();
}

class _LanguageConfigScreenState extends State<LanguageConfigScreen> {
  late String _tempLang;
  late Translations t;

  @override
  void initState() {
    super.initState();
    _tempLang = widget.language;
    t = Translations(_tempLang);
  }

  Future<void> _saveLanguage() async {
    final bool changed = _tempLang != widget.language;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _tempLang);

    if (!mounted) return;
    // Devolvemos 'true' solo si hubo un cambio real.
    Navigator.pop(context, changed); 
  }

  @override
  Widget build(BuildContext context) {
    t = Translations(_tempLang);

    return Scaffold(
      appBar: AppBar(title: Text(t.get('language_config'))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'es',
              groupValue: _tempLang,
              onChanged: (v) {
                setState(() {
                  _tempLang = v!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _tempLang,
              onChanged: (v) {
                setState(() {
                  _tempLang = v!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Euskara'),
              value: 'eu',
              groupValue: _tempLang,
              onChanged: (v) {
                setState(() {
                  _tempLang = v!;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveLanguage,
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// PANTALLA ACERCA DE
// ======================================================
class AboutScreen extends StatelessWidget {
  final String language;

  // REEMPLAZA ESTOS VALORES CON TU INFORMACIÓN REAL
  static const String authorName = 'Luis Pipaon';
  static const String githubUrl = 'https://github.com/LuisPipaon';

  const AboutScreen({super.key, required this.language});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (url.startsWith('http')) {
        throw 'No se pudo abrir $url';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations(language);

    return Scaffold(
      appBar: AppBar(title: Text(t.get('about_title'))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.get('author'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              authorName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            Text(
              t.get('github_link'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _launchUrl(githubUrl),
              child: const Text(
                githubUrl,
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Versión: 1.0.0', 
              style: TextStyle(color: Colors.grey),
            ),
            const Text(
              'Licencia: MIT', 
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
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
  // ¡CORRECCIÓN! Declaración de la lista faltante
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
            widestDataList = currentWidestDataList; // AHORA FUNCIONA
        } else {
            widestDataList = []; // AHORA FUNCIONA
        }
      });
    } catch (e) {
      if (!mounted) return;
        setState(() {
        _dataErrorMessage = t.get('error_data_load');
        _isLoadingData = false;
      });
      print('Error al obtener datos de la gráfica multi-fuente: $e');
    }
  }
  
  // (Resto de métodos como _pickDateTime, pickStartDateTime, pickEndDateTime, build...)
  
// ... el resto de métodos y el método build no necesitan cambios en su lógica.
// Los copio a continuación para que tengas la clase completa sin tener que buscar
// las líneas exactas, pero la clave era la línea 1297 (o similar)

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
        SnackBar(content: Text(t.get('error_date_end'))),
      );
      return;
    }

    setState(() {
      endDate = newEnd;
    });
    fetchData();
  }
  
  // -----------------------------------------------------------------------
  
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
    
    // Ya no es necesario recalcular currentWidestDataList aquí, usamos widestDataList
    // que se calcula en fetchData()
    
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
      appBar: AppBar(title: const Text('Gráfica de Comparación')),
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
                  label: Text('${t.get('start')}: ${formatter.format(startDate)}'),
                ),
                ElevatedButton.icon(
                  onPressed: pickEndDateTime,
                  icon: const Icon(Icons.calendar_today, size: 16),
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
                        ? const Center(child: Text('No hay datos disponibles para el rango seleccionado.'))
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
                            tooltipBehavior: TooltipBehavior(
                              enable: true,
                              header: 'Datos', 
                              format: 'series.name : point.y', 
                            ),
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