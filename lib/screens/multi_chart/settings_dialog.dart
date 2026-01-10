import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chart_source.dart';
import '../../localization/translations.dart';

class SettingsDialog extends StatelessWidget {
  final Translations t;
  final DateTime startDate;
  final DateTime endDate;
  final List<ChartSource> sources;
  final Map<String, TextEditingController> minControllers;
  final Map<String, TextEditingController> maxControllers;
  final Function(bool) onSelectDate;
  final VoidCallback onApply;

  const SettingsDialog({
    super.key,
    required this.t,
    required this.startDate,
    required this.endDate,
    required this.sources,
    required this.minControllers,
    required this.maxControllers,
    required this.onSelectDate,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(t.get('settings') ?? 'Configuración'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rango de tiempo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text("Inicio: ${DateFormat('dd/MM HH:mm').format(startDate)}"),
                  onTap: () async {
                    await onSelectDate(true);
                    setDialogState(() {});
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text("Fin: ${DateFormat('dd/MM HH:mm').format(endDate)}"),
                  onTap: () async {
                    await onSelectDate(false);
                    setDialogState(() {});
                  },
                ),
                const Divider(height: 30),
                Text(t.get('adjustYScales'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ...sources.map((s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.displayName, style: TextStyle(color: s.color, fontWeight: FontWeight.bold)),
                    Row(children: [
                      Expanded(child: TextField(controller: minControllers[s.id], decoration: InputDecoration(labelText: t.get('min')), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: maxControllers[s.id], decoration: InputDecoration(labelText: t.get('max')), keyboardType: TextInputType.number)),
                    ]),
                  ],
                )).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.get('cancel'))),
          ElevatedButton(onPressed: onApply, child: Text(t.get('apply'))),
        ],
      ),
    );
  }
}