import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Necesario para el Timer

import '../models/channel.dart';
import '../models/chart_source.dart';
import '../models/favorite_config.dart'; 
import '../services/thingspeak_service.dart';
import '../localization/translations.dart';



import 'multi_field_chart_screen.dart';
import 'settings/settings_screen.dart';

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
  Map<String, Map<String, String>> channelFields = {}; 
  List<ChartSource> selectedSources = [];
  List<FavoriteConfig> favorites = []; 
  
  bool loading = true;
  late Translations t;
  String? errorMessage; 
  
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

  // --- LÓGICA DE FAVORITOS (SOLUCIÓN DEFINITIVA SNACKBAR) ---

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    final List<String> favJsonList = prefs.getStringList('favorites_list') ?? [];
    
    setState(() {
      favorites = favJsonList.map((json) => FavoriteConfig.fromJson(json)).toList();
    });
  }

  Future<void> _deleteFavorite(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedFav = favorites[index];

    // 1. Limpieza absoluta antes de mostrar nada
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    setState(() {
      favorites.removeAt(index);
      _syncFavoritesToPrefs(prefs);
    });

    if (mounted) {
      // 2. Creamos el SnackBar
      final snack = SnackBar(
        content: Text("${t.get('deleted')}: ${deletedFav.name}"),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: t.get('undo'),
          onPressed: () {
            setState(() {
              favorites.insert(index, deletedFav);
              _syncFavoritesToPrefs(prefs);
            });
            messenger.hideCurrentSnackBar();
          },
        ),
      );

      // 3. Lo mostramos y programamos un cierre forzado por si el sistema falla
      messenger.showSnackBar(snack);

      // FORZADO MANUAL: Si a los 3.5 segundos sigue ahí, lo matamos por código
      Timer(const Duration(milliseconds: 3500), () {
        if (mounted) {
          messenger.hideCurrentSnackBar();
        }
      });
    }
  }

  void _syncFavoritesToPrefs(SharedPreferences prefs) {
    List<String> favJsonList = favorites.map((f) => f.toJson()).toList();
    prefs.setStringList('favorites_list', favJsonList);
  }

  Future<void> _loadFavoriteIntoChart(FavoriteConfig favorite) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiFieldChartScreen(
          sources: favorite.sources,
          start: DateTime.now().subtract(const Duration(hours: 6)),
          end: DateTime.now(),
          language: widget.language,
          initialMin: favorite.minValues, 
          initialMax: favorite.maxValues, 
        ),
      ),
    );
    _loadFavorites(); 
  }

  // --- FIN LÓGICA ---

  Future<void> _reloadConfigAndChannels() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
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
      
      List<Future<void>> fieldFutures = [];
      for (var channel in allChannels) {
          fieldFutures.add(() async {
              try {
                  Map<String, String> fieldNameToFieldX = {};
                  await service.getLastFeed(channel, fieldNameToFieldX); 
                  if (fieldNameToFieldX.isNotEmpty) {
                    channelFields[channel.id] = fieldNameToFieldX;
                  }
              } catch (e) {
                  print('Error en canal ${channel.name}: $e');
              }
          }());
      }
      await Future.wait(fieldFutures);
      
      if (!mounted) return;
      setState(() {
        channels = allChannels.where((c) => channelFields.containsKey(c.id)).toList(); 
        loading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '${t.get('error_loading_channels')}\n$e';
        loading = false;
      });
    }
  }

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
              title: Text(t.get('add_source_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Channel>(
                    isExpanded: true,
                    hint: Text(t.get('select_channel_hint')),
                    value: selectedChannel,
                    items: channels.map((channel) => DropdownMenuItem(value: channel, child: Text(channel.name))).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedChannel = value;
                        selectedField = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (selectedChannel != null && fields != null)
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: Text(t.get('select_field_hint')),
                      value: selectedField,
                      items: fields.keys.map((fieldName) => DropdownMenuItem(value: fieldName, child: Text(fieldName))).toList(),
                      onChanged: (value) => setDialogState(() => selectedField = value),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(t.get('cancel'))),
                ElevatedButton(
                  onPressed: selectedChannel != null && selectedField != null
                      ? () {
                          final fieldX = channelFields[selectedChannel!.id]![selectedField]!;
                          final color = availableColors[selectedSources.length % availableColors.length];
                          
                          setState(() {
                            selectedSources.add(ChartSource(
                              channel: selectedChannel!,
                              fieldName: selectedField!,
                              fieldX: fieldX,
                              color: color,
                            ));
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

  void _removeSource(String id) {
    setState(() => selectedSources.removeWhere((source) => source.id == id));
  }

  Future<void> _goToChart() async {
    final now = DateTime.now();
    final sixHoursAgo = now.subtract(const Duration(hours: 24)); 
    await Navigator.push(
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
    _loadFavorites(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('select_channel')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final bool? needsReload = await Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    language: widget.language, 
                    userApiKeys: widget.userApiKeys
                  )
                )
              );
              if (needsReload == true && mounted) {
                _reloadConfigAndChannels();
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (favorites.isNotEmpty)
                  ExpansionTile(
                    initiallyExpanded: true, 
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text("${t.get('favorites')} (${favorites.length})"),
                    children: favorites.asMap().entries.map((entry) {
                      int idx = entry.key;
                      FavoriteConfig fav = entry.value;
                      return ListTile(
                        key: ValueKey(fav.name + idx.toString()),
                        title: Text(fav.name),
                        subtitle: Text("${fav.sources.length} ${t.get('sources')}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteFavorite(idx),
                        ),
                        onTap: () => _loadFavoriteIntoChart(fav),
                      );
                    }).toList(),
                  ),
                
                const Divider(),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(t.get('sources_to_compare'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...selectedSources.map((source) => ListTile(
                        leading: Icon(Icons.circle, color: source.color),
                        title: Text(source.displayName),
                        trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => _removeSource(source.id)),
                      )).toList(),
                      
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _addSource,
                        icon: const Icon(Icons.add),
                        label: Text(t.get('add_new_source')),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: selectedSources.isNotEmpty ? _goToChart : null,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: Text(t.get('generate_chart_button')),
                  ),
                ),
              ],
            ),
    );
  }
}