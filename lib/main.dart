// import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'screens/initial_loader.dart';

// No importamos 'services.dart' aquí para evitar que Windows lo analice
// Si necesitas servicios de sistema, lo ideal es hacerlo dentro de un widget
// que solo se use en móvil, pero para tu caso, lo más sencillo es esto:

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: InitialLoader(),
    );
  }
}
