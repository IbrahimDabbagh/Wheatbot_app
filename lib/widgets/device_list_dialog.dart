import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class DeviceListDialog extends StatelessWidget {
  final List<BluetoothDevice> devices;

  const DeviceListDialog({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Arduino Device'),
      content: SizedBox(
        width: double.maxFinite,
        child: devices.isEmpty
            ? const Text('No paired devices found. Please pair your HC-05 module first.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.address),
                    onTap: () => Navigator.of(context).pop(device),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
