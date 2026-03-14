import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../models/channel.dart';
import '../models/chart_source.dart';
import '../models/favorite_config.dart'; 
import '../services/thingspeak_service.dart';
import '../localization/translations.dart';

import 'multi_field_chart_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/about_screen.dart';

class ChartSourceSelectorScreen extends StatefulWidget {
  final String language;
  final List<String> userApiKeys;

  const ChartSourceSelectorScreen({super.key, required this.language, required this.userApiKeys});

  @override
  State<ChartSourceSelectorScreen> createState() => _ChartSourceSelectorScreenState();
}

class _ChartSourceSelectorScreenState extends State<ChartSourceSelectorScreen> {
  final ThingSpeakService service = ThingSpeakService();
  
  // Variables de estado
  List<Channel> channels = [];
  Map<String, Map<String, String>> channelFields = {}; 
  List<ChartSource> selectedSources = [];
  List<FavoriteConfig> favorites = []; 
  
  bool loading = true;
  String? errorMessage; // Para capturar el error de la consola
  late Translations t;
  
  final List<Color> availableColors = [
    Colors.blue, Colors.red, Colors.green, Colors.purple, 
    Colors.orange, Colors.teal, Colors.brown, Colors.pink
  ];

  @override
  void initState() {
    super.initState();
    t = Translations(widget.language);
    loadAllChannelsAndFields();
    _loadFavorites(); 
  }

  // --- LÓGICA DE CARGA CON CAPTURA DE ERROR ---
  Future<void> loadAllChannelsAndFields() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = null; // Limpiar errores previos
    });

    try {
      List<Channel> allChannels = [];

      for (String entry in widget.userApiKeys) {
        try {
          if (entry.contains(':')) {
            final parts = entry.split(':');
            allChannels.add(Channel(id: parts[0].trim(), readApiKey: parts[1].trim(), name: 'ID: ${parts[0].trim()}'));
          } else if (RegExp(r'^[0-9]+$').hasMatch(entry)) {
            allChannels.add(Channel(id: entry, readApiKey: '', name: 'Public ID: $entry'));
          } else {
            final userChannels = await service.getUserChannels(entry);
            allChannels.addAll(userChannels);
          }
        } catch (e) {
          rethrow; // Dejamos que el catch principal lo atrape
        }
      }

      List<Channel> validatedChannels = [];
      for (var channel in allChannels) {
        Map<String, String> fieldMap = {};
        final dynamic data = await service.getLastFeed(channel, fieldMap);
        if (fieldMap.isNotEmpty) {
          if (data != null && data is Map && data['channel'] != null) {
            channel.name = data['channel']['name'].toString();
          }
          channelFields[channel.id] = fieldMap;
          validatedChannels.add(channel);
        }
      }
      
      if (!mounted) return;
      setState(() {
        channels = validatedChannels;
        loading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      
      // Capturamos el mensaje que lanza el servicio
      String cleanError = e.toString().replaceAll('Exception: ', '');
      
      setState(() {
        loading = false;
        errorMessage = cleanError;
      });

      // Mostramos el diálogo de error inmediatamente
      _showErrorDialog(cleanError);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 10),
            Text("Error de Conexión"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.get('cancel') ?? "Cerrar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              loadAllChannelsAndFields(); // Reintentar
            },
            child: const Text("Reintentar"),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE FAVORITOS (Sin cambios) ---
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    final List<String> favJsonList = prefs.getStringList('favorites_list') ?? [];
    setState(() {
      favorites = favJsonList.map((json) => FavoriteConfig.fromJson(json)).toList();
    });
  }

  Future<void> _deleteFavorite(int index) async {
    final deletedFav = favorites[index];
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('confirm_delete') ?? "Confirmar"),
        content: Text("${t.get('delete_question') ?? '¿Borrar?'} \n\n${deletedFav.name}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.get('cancel') ?? "No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('delete') ?? "Sí", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        favorites.removeAt(index);
        prefs.setStringList('favorites_list', favorites.map((f) => f.toJson()).toList());
      });
    }
  }

  Future<void> _loadFavoriteIntoChart(FavoriteConfig favorite) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiFieldChartScreen(
          sources: favorite.sources,
          start: DateTime.now().subtract(const Duration(hours: 24)),
          end: DateTime.now(),
          language: widget.language,
          initialMin: favorite.minValues, 
          initialMax: favorite.maxValues, 
        ),
      ),
    );
    _loadFavorites(); 
  }

  Future<void> _reloadConfigAndChannels() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChartSourceSelectorScreen( 
          language: prefs.getString('selected_language') ?? 'en', 
          userApiKeys: prefs.getStringList('apiKeys') ?? [], 
        ),
      ),
    );
  }

  void _removeSource(String id) {
    setState(() => selectedSources.removeWhere((source) => source.id == id));
  }

  Future<void> _addSource() async {
    Channel? selectedChannel;
    String? selectedField;

    if (channels.isEmpty) return;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final fields = selectedChannel != null ? channelFields[selectedChannel!.id] : null;
          return AlertDialog(
            title: Text(t.get('add_source_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<Channel>(
                  isExpanded: true,
                  hint: Text(t.get('select_channel_hint')),
                  value: selectedChannel,
                  items: channels.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setDialogState(() { selectedChannel = v; selectedField = null; }),
                ),
                if (selectedChannel != null && fields != null)
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(t.get('select_field_hint')),
                    value: selectedField,
                    items: fields.keys.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setDialogState(() => selectedField = v),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(t.get('cancel'))),
              ElevatedButton(
                onPressed: selectedChannel != null && selectedField != null ? () {
                  setState(() {
                    selectedSources.add(ChartSource(
                      channel: selectedChannel!,
                      fieldName: selectedField!,
                      fieldX: channelFields[selectedChannel!.id]![selectedField]!,
                      color: availableColors[selectedSources.length % availableColors.length],
                    ));
                  });
                  Navigator.pop(context);
                } : null,
                child: Text(t.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _goToChart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiFieldChartScreen(
          sources: selectedSources,
          start: DateTime.now().subtract(const Duration(hours: 24)),
          end: DateTime.now(),
          language: widget.language,
        ),
      ),
    );
    _loadFavorites(); 
  }

  // --- INTERFAZ ---
  @override
 @override
  Widget build(BuildContext context) {
    t = Translations(widget.language);

    return Scaffold(
appBar: PreferredSize(
        preferredSize: const Size.fromHeight(32.0),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: Theme.of(context).primaryColor,
          child: Row(
            children: [
              const SizedBox(width: 12),
              // Título de la App
              Expanded(
                child: Text(
                  t.get('select_channel'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // ICONO DE INFORMACIÓN (i) - Corregido con lenguaje
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AboutScreen(language: widget.language), // <--- Argumento añadido
                    ),
                  );
                },
              ),
              const SizedBox(width: 12), 
              // ICONO DE AJUSTES
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.settings, size: 18, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        language: widget.language,
                        userApiKeys: widget.userApiKeys,
                      ),
                    ),
                  );
                  _reloadConfigAndChannels();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? _buildErrorView() // Mostrar error si existe (sin conexión)
                : _buildMainContent(), // Mostrar lista normal (favoritos y canales)
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_connected_no_internet_4, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: loadAllChannelsAndFields, 
              icon: const Icon(Icons.refresh), 
              label: const Text("Reintentar carga"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        if (favorites.isNotEmpty)
          ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.star, color: Colors.amber, size: 20),
            title: Text("${t.get('favorites')} (${favorites.length})", style: const TextStyle(fontSize: 13)),
            children: favorites.asMap().entries.map((entry) => ListTile(
              dense: true,
              title: Text(entry.value.name, style: const TextStyle(fontSize: 13)),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _deleteFavorite(entry.key)),
              onTap: () => _loadFavoriteIntoChart(entry.value),
            )).toList(),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(t.get('sources_to_compare'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ...selectedSources.map((source) => ListTile(
                dense: true,
                leading: Icon(Icons.circle, color: source.color, size: 12),
                title: Text(source.displayName, style: const TextStyle(fontSize: 13)),
                trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeSource(source.id)),
              )),
              TextButton.icon(onPressed: _addSource, icon: const Icon(Icons.add, size: 18), label: Text(t.get('add_new_source'), style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: selectedSources.isNotEmpty ? _goToChart : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            child: Text(t.get('generate_chart_button')),
          ),
        ),
      ],
    );
  }
}