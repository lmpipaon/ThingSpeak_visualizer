import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/chart_source.dart';
import '../services/thingspeak_service.dart';
import '../localization/translations.dart';
import '../constants/app_constants.dart';

import '../screens/settings/api_keys_config_screen.dart';


import 'multi_field_chart_screen.dart';
import 'settings/settings_screen.dart';


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
            child: Text(t.get('ok')), // CORREGIDO: Usando 'ok'
          ),
        ],
      ),
    );
  }
  
  // Funcion para manejar la navegacion a Settings y la recarga
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
              title: Text(t.get('add_source_title')), // CORREGIDO
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Channel>(
                    isExpanded: true,
                    hint: Text(t.get('select_channel_hint')), // CORREGIDO
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
                      hint: Text(t.get('select_field_hint')), // CORREGIDO
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
                  child: Text(t.get('cancel')), // CORREGIDO
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
                            Text(t.get('sources_to_compare'), style: Theme.of(context).textTheme.titleMedium), // CORREGIDO
                            ...selectedSources.map((source) => ListTile(
                              leading: Icon(Icons.circle, color: source.color),
                              title: Text(source.displayName),
                              subtitle: Text('${t.get('channel_id_label')}: ${source.channel.id}'), // CORREGIDO
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeSource(source.id),
                              ),
                            )).toList(),
                            
                            // Botón para añadir una nueva fuente
                            TextButton.icon(
                              onPressed: channels.isEmpty ? null : _addSource,
                              icon: const Icon(Icons.add),
                              label: Text(t.get('add_new_source')), // CORREGIDO
                            ),
                            // Indicación de ejes (Importante para la versión con Ejes Duales)
                            if (selectedSources.length > 1) 
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  t.get('dual_axis_note'), // CORREGIDO
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
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
                          child: Text(t.get('generate_chart_button'), style: const TextStyle(fontSize: 18)), // CORREGIDO
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}