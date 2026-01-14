// ignore_for_file: deprecated_member_use

import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import '../models/chart_data.dart';
import '../models/chart_source.dart';
import '../models/favorite_config.dart';
import '../services/thingspeak_service.dart';
import '../localization/translations.dart';

import 'multi_chart/chart_widgets.dart';
import 'multi_chart/settings_dialog.dart';

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
  bool _isFullScreen = false;
  bool _showYAxes = true;
  final ThingSpeakService service = ThingSpeakService();
  Map<String, List<ChartData>> multiData = {};
  RangeValues? xRange;
  
  final Map<String, double?> minValues = {};
  final Map<String, double?> maxValues = {};
  final Map<String, TextEditingController> minControllers = {};
  final Map<String, TextEditingController> maxControllers = {};
  Map<String, bool> serieVisible = {};
  
  // La variable de traducciones
  late Translations t;

  void _toggleFullScreen() {
  setState(() {
    _isFullScreen = !_isFullScreen;
  });
}

  @override
  void initState() {
    super.initState();
    // INICIALIZACIÓN: Usamos el idioma que viene del selector
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
    // Restauramos orientación al salir
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    for (var c in minControllers.values) c.dispose();
    for (var c in maxControllers.values) c.dispose();
    super.dispose();
  }

  // ... (Métodos _toggleFullScreen y fetchData se mantienen igual)

  Future<void> fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      multiData.clear();
      xRange = null;
    });
    try {
      for (var s in widget.sources) {
        final data = await service.getFieldValuesWithTime(
          s.channel, 
          s.fieldX, 
          start: startDate, 
          end: endDate, 
          results: 8000
        );
        multiData[s.id] = data;
      }
      
      final allTimes = multiData.values
          .expand((list) => list.map((e) => e.time.millisecondsSinceEpoch))
          .toList();
          
      if (allTimes.isNotEmpty) {
        final minX = allTimes.reduce(min).toDouble();
        final maxX = allTimes.reduce(max).toDouble();
        setState(() => xRange = RangeValues(minX, maxX));
      }
    } catch (e) {
      debugPrint("Error cargando datos: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        t: t, // Pasamos la instancia t ya inicializada
        startDate: startDate,
        endDate: endDate,
        sources: widget.sources,
        minControllers: minControllers,
        maxControllers: maxControllers,
        onSelectDate: _selectDate,
        onApply: () {
          setState(() {
            for (var s in widget.sources) {
              minValues[s.id] = double.tryParse(minControllers[s.id]!.text);
              maxValues[s.id] = double.tryParse(maxControllers[s.id]!.text);
            }
          });
          fetchData();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // RE-ASIGNACIÓN: Por seguridad, actualizamos t con el idioma del widget
    t = Translations(widget.language);

    return Scaffold(
      appBar: _isFullScreen 
        ? null 
        : PreferredSize(
            preferredSize: const Size.fromHeight(32.0),
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              color: Theme.of(context).primaryColor,
              child: SizedBox(
                height: 32.0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        t.get('thingSpeakMulti'), // Clave en el JSON
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildCompactAction(
                      icon: _showYAxes ? Icons.align_horizontal_left : Icons.dehaze,
                      onTap: () => setState(() => _showYAxes = !_showYAxes),
                    ),
                    _buildCompactAction(
                      icon: Icons.fullscreen,
                      onTap: _toggleFullScreen,
                    ),
                    _buildCompactAction(
                      icon: Icons.favorite_border,
                      onTap: _saveAsFavorite,
                    ),
                    _buildCompactAction(
                      icon: Icons.tune,
                      onTap: _showSettings,
                    ),
                    _buildCompactAction(
                      icon: Icons.refresh,
                      onTap: fetchData,
                    ),
                  ],
                ),
              ),
            ),
          ),
      
      floatingActionButton: _isFullScreen 
        ? FloatingActionButton.small(
            backgroundColor: Colors.black.withOpacity(0.4),
            onPressed: _toggleFullScreen,
            child: const Icon(Icons.fullscreen_exit, color: Colors.white),
          )
        : null,

      body: SafeArea(
        child: Column(children: [
          if (!_isFullScreen) _buildVisibilityToggles(),
          
          Expanded(
            child: (_isLoadingData || xRange == null)
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: ChartView(
                      language: widget.language,
                      sources: widget.sources,
                      multiData: multiData,
                      xRange: xRange!,
                      serieVisible: serieVisible,
                      minValues: minValues,
                      maxValues: maxValues,
                      boundaryKey: _boundaryKey,
                      isFullScreen: _isFullScreen,
                      showYAxes: _showYAxes,
                    ),
                  ),
          ),
          if (xRange != null) _buildZoomSlider(),
        ]),
      ),
    );
  }

  // ... (Los widgets auxiliares _buildCompactAction, _buildVisibilityToggles, _buildZoomSlider se mantienen igual)

  Widget _buildCompactAction({required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, size: 18, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildVisibilityToggles() {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: widget.sources.length,
        itemBuilder: (context, index) {
          final s = widget.sources[index];
          final isSelected = serieVisible[s.id] ?? true;
          return Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: GestureDetector(
              onTap: () => setState(() => serieVisible[s.id] = !isSelected),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? s.color : s.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : s.color,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildZoomSlider() {
    if (xRange == null) return const SizedBox.shrink();
    
    final allTimes = multiData.values
        .expand((l) => l.map((e) => e.time.millisecondsSinceEpoch))
        .toList();
    if (allTimes.isEmpty) return const SizedBox.shrink();
    
    final minT = allTimes.reduce(min).toDouble();
    final maxT = allTimes.reduce(max).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 20, 
          vertical: _isFullScreen ? 0 : 2 
      ),
      child: SizedBox(
        height: 30,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: RangeSlider(
            values: xRange!,
            min: minT,
            max: maxT <= minT ? minT + 1 : maxT,
            onChanged: (v) => setState(() => xRange = v),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(bool start) async {
    final d = await showDatePicker(
        context: context,
        initialDate: start ? startDate : endDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (d == null) return;
    final tPick = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(start ? startDate : endDate));
    if (tPick == null) return;
    setState(() {
      final nd = DateTime(d.year, d.month, d.day, tPick.hour, tPick.minute);
      if (start) startDate = nd; else endDate = nd;
    });
  }

  Future<void> _saveAsFavorite() async {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('saveFavorite')),
        content: TextField(
          controller: nameController, 
          decoration: InputDecoration(hintText: t.get('configurationName'))
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.get('cancel'))),
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
                  SnackBar(content: Text('"${nameController.text}" ${t.get('saved')}'))
                );
              }
            },
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
  }
}