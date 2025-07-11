import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  bool get isConnected => _connection?.isConnected ?? false;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  void disconnect() {
    _connection?.dispose();
    _connection = null;
  }

  Stream<String> getDataStream() {
    if (_connection == null) {
      return Stream.empty();
    }

    return _connection!.input!.map((Uint8List data) {
      return String.fromCharCodes(data).trim();
    });
  }

  Future<void> sendData(String data) async {
    if (_connection?.isConnected == true) {
      _connection!.output.add(Uint8List.fromList(utf8.encode(data + '\n')));
      await _connection!.output.allSent;
    }
  }
}
