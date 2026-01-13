import 'package:flutter/material.dart';

void showApiHelp(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 10),
          Text('¿Dónde están las llaves?'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('1. Channel ID', 'En la pestaña "Channel Settings". Es el número identificador.'),
            _section('2. Read API Key', 'En la pestaña "API Keys". Solo si el canal es privado.'),
            _section('3. User API Key', 'En tu perfil (My Profile). Sirve para ver todos tus canales.'),
            const Divider(),
            const Text(
              'Nota: Zekuiano es público, no necesita Read API Key.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Widget _section(String title, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}