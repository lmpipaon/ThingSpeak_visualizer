import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../localization/translations.dart';

// ======================================================
// PANTALLA ACERCA DE (Versión con Email y GitHub)
// ======================================================
class AboutScreen extends StatelessWidget {
  final String language;

  // --- CONFIGURACIÓN DE TU INFORMACIÓN ---
  static const String authorName = 'Luis Pipaon';
  static const String contactEmail = 'koldo.noa406@barbarbu.fr';
  static const String githubUrl = 'https://github.com/lmpipaon/ThingSpeak_visualizer';
  static const String appDescription = 
      'ThingSpeak Visualizer is an open-source tool designed to monitor and display '
      'real-time data from IoT sensors. Easily connect to your channels and '
      'visualize your fields with clean, intuitive charts.';

  const AboutScreen({super.key, required this.language});

  // Función para abrir URLs (GitHub)
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir $url');
    }
  }

  // Función para enviar Email
  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: contactEmail,
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Regarding ThingSpeak Visualizer',
      }),
    );

    if (!await launchUrl(emailLaunchUri)) {
      debugPrint('No se pudo abrir la aplicación de correo');
    }
  }

  // Auxiliar para formatear correctamente los parámetros del email
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations(language);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('about_title')),
        centerTitle: true,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final String version = snapshot.data?.version ?? '1.0.0';
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icono representativo
                  const Icon(Icons.analytics_outlined, size: 85, color: Colors.blue),
                  const SizedBox(height: 16),
                  
                  Text(
                    'ThingSpeak Visualizer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  
                  Text(
                    'Version $version',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  
                  const SizedBox(height: 20),

                  // Descripción técnica
                  const Text(
                    appDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                  ),
                  
                  const Divider(height: 40, thickness: 1),

                  // --- SECCIÓN: AUTOR ---
                  _buildHeader(context, t.get('author')),
                  const SizedBox(height: 4),
                  Text(authorName, style: Theme.of(context).textTheme.titleMedium),
                  
                  const SizedBox(height: 25),

                  // --- SECCIÓN: CONTACTO (Email) ---
                  _buildHeader(context, 'Contact'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Send me an email'),
                  ),

                  const SizedBox(height: 25),

                  // --- SECCIÓN: CÓDIGO FUENTE (GitHub) ---
                  _buildHeader(context, t.get('github_link')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _launchUrl(githubUrl),
                    icon: const Icon(Icons.code),
                    label: const Text('View on GitHub'),
                  ),

                  const SizedBox(height: 40),

                  // --- BOTÓN DE LICENCIAS ---
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      elevation: 0,
                    ),
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'ThingSpeak Visualizer',
                        applicationVersion: version,
                        applicationLegalese: '© 2025 $authorName',
                        applicationIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(Icons.bar_chart, size: 48, color: Colors.blue),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Open Source Licenses'),
                  ),
                  
                  const SizedBox(height: 15),
                  const Text(
                    'Licensed under MIT License',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Estilo para los títulos de sección
  Widget _buildHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
    );
  }
}