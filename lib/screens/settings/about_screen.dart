import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/translations.dart';


// ======================================================
// PANTALLA ACERCA DE
// ======================================================
class AboutScreen extends StatelessWidget {
  final String language;

  // REEMPLAZA ESTOS VALORES CON TU INFORMACIÓN REAL
  static const String authorName = 'Luis Pipaon';
  static const String githubUrl = 'https://github.com/lmpipaon/ThingSpeak_visualizer';

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