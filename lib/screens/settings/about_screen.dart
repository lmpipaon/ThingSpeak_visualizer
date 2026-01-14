// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../localization/translations.dart';
import '../../constants/app_constants.dart'; 

class AboutScreen extends StatelessWidget {
  final String language;

  static const String githubUrl = 'https://github.com/lmpipaon/ThingSpeak_visualizer';
  static const String mitLicenseUrl = 'https://opensource.org/licenses/MIT';

  const AboutScreen({super.key, required this.language});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir $url');
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: contactEmail, 
      query: _encodeQueryParameters(<String, String>{
        'subject': 'ThingSpeak Visualizer - Luis Pipaon',
        'body': 'Kaixo Luis,\n\n', 
      }),
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    // Inicializamos las traducciones con el idioma actual
    final t = Translations(language);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('about_title')), // Clave: about_title
        centerTitle: true,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final String version = snapshot.data?.version ?? '1.2.0';
          final String buildNumber = snapshot.data?.buildNumber ?? '1';
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_outlined, size: 85, color: Colors.blue),
                  const SizedBox(height: 16),
                  
                  Text(
                    'ThingSpeak Visualizer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  
                  Text(
                    '${t.get('version_label')} $version+$buildNumber', // Clave: version_label
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  
                  const SizedBox(height: 20),

                  Text(
                    t.get('app_description'), // Clave: app_description
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                  ),
                  
                  const Divider(height: 40, thickness: 1),

                  _buildHeader(context, t.get('author')), // Clave: author
                  const SizedBox(height: 4),
                  Text(authorName, style: Theme.of(context).textTheme.titleMedium),
                  
                  const SizedBox(height: 25),

                  _buildHeader(context, t.get('contact_label')), // Clave: contact_label
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: Text(t.get('send_email')), // Clave: send_email
                  ),
                  Text(contactEmail, style: const TextStyle(fontSize: 11, color: Colors.grey)),

                  const SizedBox(height: 25),

                  _buildHeader(context, t.get('github_link')), // Clave: github_link
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _launchUrl(githubUrl),
                    icon: const Icon(Icons.code),
                    label: Text(t.get('view_github')), // Clave: view_github
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      elevation: 0,
                    ),
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'ThingSpeak Visualizer',
                        applicationVersion: '$version+$buildNumber',
                        applicationLegalese: '© 2026 $authorName',
                        applicationIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(Icons.bar_chart, size: 48, color: Colors.blue),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: Text(t.get('licenses_label')), // Clave: licenses_label
                  ),
                  
                  const SizedBox(height: 25),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Licensed under ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      GestureDetector(
                        onTap: () => _launchUrl(mitLicenseUrl),
                        child: const Text(
                          'MIT License',
                          style: TextStyle(
                            color: Colors.blue, 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    '© 2026 $authorName',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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