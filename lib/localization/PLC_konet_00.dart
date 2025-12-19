import 'dart:io';
import 'package:s7client/s7client.dart';

void main() async {
  // Configuración de los PLCs
  var plc1 = S7Client(host: '192.168.0.80', rack: 0, slot: 2);
  var plc2 = S7Client(host: '192.168.0.81', rack: 0, slot: 2);
  var plc3 = S7Client(host: '192.168.0.82', rack: 0, slot: 2);

  print("Iniciando monitoreo de PLCs en Dart... (Ctrl+C para salir)");

  while (true) {
    // --- PLC 1 ---
    await procesarPLC(plc1, "PLC 1", 19, 136, 2, (data) {
      int value = data.getInt16(0); // get_int equivalente
      return value * 5040.0 / 27648.0;
    });

    // --- PLC 2 ---
    await procesarPLC(plc2, "PLC 2", 19, 136, 2, (data) {
      int value = data.getInt16(0);
      return value * 5040.0 / 27648.0;
    });

    // --- PLC 3 ---
    await procesarPLC(plc3, "PLC 3", 60, 400, 4, (data) {
      int value = data.getInt32(0); // get_dint equivalente
      return value / 100.0;
    });

    print("-------------------------------------------------------");
    await Future.delayed(Duration(seconds: 5));
  }
}

// Función genérica para manejar la lógica de cada PLC
Future<void> procesarPLC(S7Client client, String nombre, int db, int start, int size, double Function(ByteData) calculo) async {
  try {
    if (!client.connected) {
      print("Conectando a $nombre...");
      await client.connect();
    }

    if (client.connected) {
      var data = await client.readDB(db, start, size);
      double caudal = calculo(data);
      print("$nombre - Caudal: ${caudal.toStringAsFixed(2)} m³/h");
    }
  } catch (e) {
    print("Error en $nombre: $e");
    client.disconnect(); // Limpiar conexión si falla
  }
}