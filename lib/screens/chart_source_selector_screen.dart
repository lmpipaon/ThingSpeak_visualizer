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

  // --- LÓGICA DE FAVORITOS ---
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    setState(() {
      favorites.removeAt(index);
      _syncFavoritesToPrefs(prefs);
    });

    if (mounted) {
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
      messenger.showSnackBar(snack);
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
          language: prefs.getString('language') ?? 'es', 
          userApiKeys: prefs.getStringList('apiKeys') ?? [], 
        ),
      ),
    );
  }

  // ======================================================
  // LÓGICA DE CARGA ACTUALIZADA (SOPORTA ID:KEY Y PUBLICOS)
  // ======================================================
  Future<void> loadAllChannelsAndFields() async {
    setState(() {
      loading = true;
      errorMessage = null; 
      channels = [];
      channelFields = {};
    });

    try {
      List<Channel> allChannels = [];

      // 1. Procesar cada entrada de la lista configurada
      for (String entry in widget.userApiKeys) {
        try {
          if (entry.contains(':')) {
            // FORMATO CANAL PRIVADO (ID:READ_KEY)
            final parts = entry.split(':');
            final channelId = parts[0].trim();
            final readKey = parts[1].trim();
            // Creamos un objeto Channel temporal para validarlo
            allChannels.add(Channel(id: channelId, readApiKey: readKey, name: 'ID: $channelId'));
          } 
          else if (RegExp(r'^[0-9]+$').hasMatch(entry)) {
            // FORMATO CANAL PÚBLICO (Solo ID numérico)
            allChannels.add(Channel(id: entry, readApiKey: '', name: 'Public ID: $entry'));
          } 
          else {
            // FORMATO USER API KEY (Traer todos sus canales)
            final userChannels = await service.getUserChannels(entry);
            allChannels.addAll(userChannels);
          }
        } catch (e) {
          print('Error procesando entrada $entry: $e');
        }
      }

      // 2. Descubrir campos (Fields) y nombres reales para cada canal encontrado
      List<Future<void>> fieldFutures = [];
      List<Channel> validatedChannels = [];

      for (var channel in allChannels) {
        fieldFutures.add(() async {
          try {
            Map<String, String> fieldNameToFieldX = {};
            // getLastFeed nos sirve para validar que la Key es correcta y obtener el nombre real del canal
            final url = Uri.parse(
              'https://api.thingspeak.com/channels/${channel.id}/feeds.json?api_key=${channel.readApiKey}&results=1'
            );
            final response = await service.getLastFeed(channel, fieldNameToFieldX);
            
            // Si el canal responde correctamente, lo actualizamos con su nombre real
            if (fieldNameToFieldX.isNotEmpty) {
              channelFields[channel.id] = fieldNameToFieldX;
              validatedChannels.add(channel);
            }
          } catch (e) {
            print('Canal ${channel.id} no disponible o Key inválida: $e');
          }
        }());
      }
      await Future.wait(fieldFutures);
      
      if (!mounted) return;
      setState(() {
        channels = validatedChannels;
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(32.0),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: Theme.of(context).primaryColor,
          child: SizedBox(
            height: 32.0,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.get('select_channel'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AboutScreen(language: widget.language),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.settings, size: 18, color: Colors.white),
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
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (favorites.isNotEmpty)
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      initiallyExpanded: true, 
                      leading: const Icon(Icons.star, color: Colors.amber, size: 20),
                      title: Text("${t.get('favorites')} (${favorites.length})", 
                        style: const TextStyle(fontSize: 13)),
                      children: favorites.asMap().entries.map((entry) {
                        int idx = entry.key;
                        FavoriteConfig fav = entry.value;
                        return ListTile(
                          dense: true, 
                          key: ValueKey(fav.name + idx.toString()),
                          title: Text(fav.name, style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () => _deleteFavorite(idx),
                          ),
                          onTap: () => _loadFavoriteIntoChart(fav),
                        );
                      }).toList(),
                    ),
                  
                  const Divider(height: 1),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Text(t.get('sources_to_compare'), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ...selectedSources.map((source) => ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: Icon(Icons.circle, color: source.color, size: 12),
                          title: Text(source.displayName, style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18), 
                            onPressed: () => _removeSource(source.id)
                          ),
                        )).toList(),
                        
                        TextButton.icon(
                          onPressed: _addSource,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(t.get('add_new_source'), style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ElevatedButton(
                      onPressed: selectedSources.isNotEmpty ? _goToChart : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(t.get('generate_chart_button')),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}