// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../localization/translations.dart';
import '../chart_source_selector_screen.dart';

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
    // Inicializamos el motor de traducciones con el idioma del widget
    t = Translations(widget.language);
    
    // LÓGICA DE EJEMPLO: Si la lista está vacía, ponemos el ID de demo de ThingSpeak
    if (widget.userApiKeys.isEmpty) {
      _apiController = TextEditingController(text: "2813413");
    } else {
      _apiController = TextEditingController(text: widget.userApiKeys.join('\n'));
    }
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKeys() async {
    // Procesamos el texto para limpiar espacios y líneas vacías
    final keys = _apiController.text
        .split(RegExp(r'[,\n]')) 
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.get('error_empty_keys'))),
      );
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('apiKeys', keys);

    if (!mounted) return;

    // Si venimos de la pantalla de Ajustes, hacemos pop devolviendo 'true' (necesita recarga)
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      // Si es el primer inicio de la App, navegamos a la pantalla principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChartSourceSelectorScreen(
            language: widget.language,
            userApiKeys: keys,
          ),
        ),
      );
    }
  }

  void _showApiHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.help_center, color: Colors.blue),
            const SizedBox(width: 10),
            Text(t.get('help_title')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.get('help_subtitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _helpItem(t.get('help_user_key_title'), t.get('help_user_key_desc')),
              _helpItem(t.get('help_channel_id_title'), t.get('help_channel_id_desc')),
              _helpItem(t.get('help_private_id_title'), t.get('help_private_id_desc')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.get('close')),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          Text(desc, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFirstTime = widget.userApiKeys.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(t.get('api_keys_config'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFirstTime) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.get('banner_help_text'),
                          style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],

              TextField(
                controller: _apiController,
                decoration: InputDecoration(
                  labelText: t.get('api_keys'),
                  helperText: t.get('edit_helper'), 
                  hintText: "2813413\nUser_API_Key\nChannel_ID:Read_API_Key",
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.blue, size: 28),
                    onPressed: _showApiHelpDialog,
                  ),
                ),
                minLines: 8,
                maxLines: null, 
                keyboardType: TextInputType.multiline,
              ),
              
              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: _saveApiKeys,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  t.get('save'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}