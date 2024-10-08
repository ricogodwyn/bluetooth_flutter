import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_ble/flutter_bluetooth_serial_ble.dart';
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;
  String msg = ""; // Declare msg as a class-level variable
  final serialNumberController = TextEditingController();
  final itemNameController = TextEditingController();
  final priceController = TextEditingController();
  String url = 'http://192.168.88.36:5000/api/item/register-item';

  @override
  void initState() {
    super.initState();
    // serialNumberController.addListener(controllerToText);
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occurred');
      print(error);
    });
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  // void controllerToText(){
  //   final serialNumber=serialNumberController;
  // }

  @override
  Widget build(BuildContext context) {
    final serverName = widget.server.name ?? "Unknown";
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to ' + serverName + '...')
              : isConnected
                  ? Text('Connected with ' + serverName)
                  : Text('Disconnected with ' + serverName))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [Text("received QR: $msg")], // Display the msg variabl
            // ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("received RFID EPC: $part1")
              ], // Display the msg variabl
            ),
            SizedBox(
              height: 15,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("received SN: $part2")
              ], // Display the msg variabl
            ),

            SizedBox(
              height: 15.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: itemNameController,
                decoration: InputDecoration(
                    label: Text("Item Name"),
                    border: OutlineInputBorder(),
                    hintText: "Input Item Name",
                    hintStyle: TextStyle(
                      color: Colors.grey,
                    )),
              ),
            ),

            SizedBox(
              height: 15.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: priceController,
                decoration: InputDecoration(
                    label: Text("Price"),
                    border: OutlineInputBorder(),
                    hintText: "Input Price",
                    hintStyle: TextStyle(
                      color: Colors.grey,
                    )),
              ),
            ),

            SizedBox(
              height: 15.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () {
                      Map<String, dynamic> data = {
                        "serial_number": part2,
                        "rfid_tag": part1,
                        "item_name": itemNameController.text,
                        "price": int.parse(priceController.text),
                      };
                      sendData(url, data);
                      clearController();
                    },
                    child: Text("Send data"))
              ],
            )
          ],
        ),
      ),
    );
  }

  String part1 = '';
  String part2 = '';
  void clearController() {
    serialNumberController.clear();
    itemNameController.clear();
    priceController.clear();
  }

  Future<void> sendData(String url, Map<String, dynamic> data) async {
    try {
      // Convert the data map to a JSON string
      String jsonData = jsonEncode(data);
      print(jsonData);
      // Send the POST request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonData,
      );
      print(response.statusCode);
      print(response);
      // Check the response status code
      if (response.statusCode >= 200 && response.statusCode <= 299) {
        print('Request successful');

        print('Response body: ${response.body}');
      } else {
        print('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }
  }

  void _onDataReceived(Uint8List data) {
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        msg = backspacesCounter > 0
            ? _messageBuffer.substring(
                0, _messageBuffer.length - backspacesCounter)
            : _messageBuffer + dataString.substring(0, index);
        _messageBuffer = dataString.substring(index);
        msg = msg.trim();
        List<String> parts = msg.split(',');
        if (parts.length != 2) {
          print("Invalid msg format");
          return;
        }

        part1 = parts[0].trim();
        part2 = parts[1].trim();
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
    print(msg);
  }
}
