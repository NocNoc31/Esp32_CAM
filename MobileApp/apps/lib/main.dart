import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(EyesProtectApp());
}

class EyesProtectApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: EyesProtectScreen(),
    );
  }
}

class EyesProtectScreen extends StatefulWidget {
  @override
  _EyesProtectScreenState createState() => _EyesProtectScreenState();
}

class _EyesProtectScreenState extends State<EyesProtectScreen> {
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  List<FlSpot> distanceData = [];
  double threshold = 20.0;
  int violationTime = 10;
  int violationCounter = 0;
  double currentDistance = 0;
  int wrong_time = 0;
  int time_sit = 0;
  bool isConnected = false;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    connectToWebSocket();
  }

  void connectToWebSocket() {
    try {
      // Replace with your ESP32's IP address and WebSocket port
      final wsUrl = Uri.parse('ws://192.168.4.1:81'); // Example: ESP32 AP IP
      _channel = WebSocketChannel.connect(wsUrl);

      setState(() {
        isConnected = true;
      });

      _channel!.stream.listen((data) {
        // Parse the incoming data
        String distanceString = data.toString().trim();
        distanceString = distanceString.replaceAll(RegExp(r'[^0-9.]'), '');
        double newDistance = double.tryParse(distanceString) ?? 0.0;
        print("Distance is $newDistance");

        setState(() {
          currentDistance = newDistance;


          distanceData.add(FlSpot(distanceData.length.toDouble(), currentDistance));

          // Check for violations
          if (currentDistance < threshold) {
            violationCounter++;
            if (violationCounter > violationTime) {
              showWarningPopup();
              wrong_time += 1;
            }
          } else {
            violationCounter = 0;
          }
        });
      }, onError: (error) {
        print("WebSocket error: $error");
        setState(() {
          isConnected = false;
        });
      }, onDone: () {
        print("WebSocket connection closed");
        setState(() {
          isConnected = false;
        });
      });
    } catch (e) {
      print("Error connecting to WebSocket: $e");
      setState(() {
        isConnected = false;
      });
    }
  }


  void showWarningPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.redAccent, size: 30),
              SizedBox(width: 10), // Fixed: Named argument for width
              Text(
                "CẢNH BÁO!",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Khoảng cách hiện tại quá gần!",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 10), // Fixed: Named argument for height
              Text(
                "Khoảng cách: ${currentDistance.toStringAsFixed(2)} cm",
                style: TextStyle(color: Colors.greenAccent, fontSize: 16),
              ),
              Text(
                "Số lần vi phạm: ${wrong_time} lần",
                style: TextStyle(color: const Color.fromARGB(255, 2, 48, 26), fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void setThreshold() {
    setState(() {
      threshold = double.tryParse(distanceController.text) ?? 50.0;
      violationTime = int.tryParse(timeController.text) ?? 3;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Cài đặt thành công: Ngưỡng $threshold cm, Thời gian $violationTime s  "),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Center(
          child: Text(
            "Eyes Protect Systems",
            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cài đặt ngưỡng
            Text(
              "Cài đặt ngưỡng",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: distanceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white), // Correct: style is part of TextField
                    decoration: InputDecoration(
                      labelText: "Set distance (cm)",
                      filled: true,
                      fillColor: Colors.white10,
                      labelStyle: TextStyle(color: Colors.greenAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                SizedBox(width: 10), // Fixed: Named argument for width
                Expanded(
                  child: TextField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white), // Correct: style is part of TextField
                    decoration: InputDecoration(
                      labelText: "Set time (s)",
                      filled: true,
                      fillColor: Colors.white10,
                      labelStyle: TextStyle(color: Colors.greenAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                ),
                ),
                SizedBox(width: 10), // Fixed: Named argument for width
                ElevatedButton(
                  onPressed: setThreshold,
                  child: Text("Cài đặt"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20), // Fixed: Named argument for height

            // Monitor
            Text(
              "Monitor",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Khoảng cách hiện tại: ${currentDistance.toStringAsFixed(2)} cm",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                Text(
                  "Thời gian ngồi: ${time_sit} s",
                  style: TextStyle(fontSize: 16, color: const Color.fromARGB(255, 146, 214, 223)),
                ),
              ],
            ),

            SizedBox(height: 20), // Fixed: Named argument for height

            Row(
              children: [
                // Text nằm bên trái
                Text(
                  "Thời gian vi phạm: $violationCounter s",
                  style: TextStyle(
                    fontSize: 16,
                    color: violationCounter > 0 ? Colors.red : Colors.greenAccent,
                  ),
                ),

                // Spacer để đẩy nút về giữa
                Spacer(),

                // Nút kết nối WebSocket
                ElevatedButton(
                  onPressed: connectToWebSocket,
                  child: Text(isConnected ? "Đã kết nối" : "Kết nối WebSocket"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20), // Fixed: Named argument for height

            // Biểu đồ khoảng cách
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 10),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 5),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: distanceData,
                        isCurved: true,
                        gradient: LinearGradient(colors: [Colors.greenAccent, Colors.black]),
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [Colors.green.withOpacity(0.3), Colors.black.withOpacity(0.1)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// void main() {
//   runApp(EyesProtectApp());
// }

// class EyesProtectApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.dark(),
//       home: EyesProtectScreen(),
//     );
//   }
// }

// class EyesProtectScreen extends StatefulWidget {
//   @override
//   _EyesProtectScreenState createState() => _EyesProtectScreenState();
// }

// class _EyesProtectScreenState extends State<EyesProtectScreen> {
//   final TextEditingController distanceController = TextEditingController();
//   final TextEditingController timeController = TextEditingController();
//   List<FlSpot> distanceData = [];
//   double threshold = 20.0;
//   int violationTime = 10;
//   int violationCounter = 0;
//   double currentDistance = 0;
//   int wrong_time = 0;
//   int time_sit = 0;
//   bool isConnected = false;
//   BluetoothConnection? _connection;
//   FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

//   @override
//   void initState() {
//     super.initState();
//     connectToBluetooth();
//   }

//   void readDistanceFromBluetooth() {
//     double previousDistance = currentDistance; // Lưu giá trị trước đó
//     Timer.periodic(Duration(seconds: 1), (timer) async {
//       if (_connection != null && _connection!.isConnected) {
//         _connection!.input!.listen((data) {
//           String distanceString = utf8.decode(data).trim();
//           distanceString = distanceString.replaceAll(RegExp(r'[^0-9.]'), '');
//           double newDistance = double.tryParse(distanceString) ?? 0.0;
//           double diff = (newDistance - previousDistance).abs(); // Sai số khoảng cách
//           previousDistance = newDistance; // Lưu giá trị trước
//           setState(() {
//             currentDistance = newDistance;
//             distanceData.add(FlSpot(distanceData.length.toDouble(), currentDistance));
//             // Kiểm tra nếu sai số trong 10s < 10cm thì đếm time_sit
//             if (diff < 10) {
//               time_sit++;
//             } else {
//               time_sit = 0;
//             }

//             // Kiểm tra nếu vi phạm khoảng cách
//             if (currentDistance < threshold) {
//               violationCounter++;
//               if (violationCounter > violationTime) {
//                 showWarningPopup();
//                 wrong_time += 1;
//               }
//             } else {
//               violationCounter = 0;
//             }
//           });
//         });
//       }
//     });
//   }

//   void showWaringLong() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.black87,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           title: Row(
//             children: [
//               Icon(Icons.warning, color: Colors.redAccent, size: 30),
//               SizedBox(width: 10),
//               Text(
//                 "CẢNH BÁO!",
//                 style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 "Bạn đã ngồi quá lâu một tư thế hãy thay đổi",
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 "Thời gian ngồi: ${time_sit} s",
//                 style: TextStyle(color: Colors.greenAccent, fontSize: 16),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               style: TextButton.styleFrom(backgroundColor: Colors.redAccent),
//               child: Text("OK", style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void showWarningPopup() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.black87,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           title: Row(
//             children: [
//               Icon(Icons.warning, color: Colors.redAccent, size: 30),
//               SizedBox(width: 10),
//               Text(
//                 "CẢNH BÁO!",
//                 style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 "Khoảng cách hiện tại quá gần!",
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 "Khoảng cách: ${currentDistance.toStringAsFixed(2)} cm",
//                 style: TextStyle(color: Colors.greenAccent, fontSize: 16),
//               ),
//               Text(
//                 "Số lần vi phạm: ${wrong_time} lần",
//                 style: TextStyle(color: const Color.fromARGB(255, 2, 48, 26), fontSize: 16),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               style: TextButton.styleFrom(backgroundColor: Colors.redAccent),
//               child: Text("OK", style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void setThreshold() {
//     setState(() {
//       threshold = double.tryParse(distanceController.text) ?? 50.0;
//       violationTime = int.tryParse(timeController.text) ?? 3;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text("Cài đặt thành công: Ngưỡng $threshold cm, Thời gian $violationTime s  "),
//         backgroundColor: Colors.green[700],
//       ),
//     );
//   }

//   Future<void> connectToBluetooth() async {
//     try {
//       // Lấy danh sách thiết bị Bluetooth đã ghép nối
//       List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();

//       // Tìm thiết bị có địa chỉ "00:23:11:01:34:75"
//       BluetoothDevice? targetDevice;
//       for (var device in devices) {
//         if (device.address == "00:23:11:01:34:75") {
//           targetDevice = device;
//           break;
//         }
//       }

//       if (targetDevice != null) {
//         // Kết nối đến thiết bị
//         _connection = await BluetoothConnection.toAddress(targetDevice.address);
//         setState(() {
//           isConnected = true;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Đã kết nối đến ${targetDevice.name}"),
//             backgroundColor: Colors.green[700],
//           ),
//         );
//         readDistanceFromBluetooth();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Không tìm thấy thiết bị"),
//             backgroundColor: Colors.red[700],
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Lỗi kết nối: $e"),
//           backgroundColor: Colors.red[700],
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black87,
//       appBar: AppBar(
//         title: Center(
//           child: Text(
//             "Eyes Protect Systems",
//             style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
//           ),
//         ),
//         backgroundColor: Colors.black,
//         elevation: 5,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Cài đặt ngưỡng
//             Text(
//               "Cài đặt ngưỡng",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
//             ),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: distanceController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: "Set distance (cm)",
//                       filled: true,
//                       fillColor: Colors.white10,
//                       labelStyle: TextStyle(color: Colors.greenAccent),
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                     ),
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 Expanded(
//                   child: TextField(
//                     controller: timeController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: "Set time (s)",
//                       filled: true,
//                       fillColor: Colors.white10,
//                       labelStyle: TextStyle(color: Colors.greenAccent),
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                     ),
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: setThreshold,
//                   child: Text("Cài đặt"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green[800],
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 20),

//             // Monitor
//             Text(
//               "Monitor",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   "Khoảng cách hiện tại: ${currentDistance.toStringAsFixed(2)} cm",
//                   style: TextStyle(fontSize: 16, color: Colors.white),
//                 ),
//                 Text(
//                   "Thời gian ngồi: ${time_sit} s",
//                   style: TextStyle(fontSize: 16, color: const Color.fromARGB(255, 146, 214, 223)),
//                 ),
//               ],
//             ),

//             SizedBox(height: 20),

//             Row(
//               children: [
//                 // Text nằm bên trái
//                 Text(
//                   "Thời gian vi phạm: $violationCounter s",
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: violationCounter > 0 ? Colors.red : Colors.greenAccent,
//                   ),
//                 ),

//                 // Spacer để đẩy nút về giữa
//                 Spacer(),

//                 // Nút kết nối Bluetooth
//                 ElevatedButton(
//                   onPressed: connectToBluetooth,
//                   child: Text(isConnected ? "Đã kết nối" : "Kết nối Bluetooth"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: isConnected ? Colors.green : Colors.blue,
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 20),

//             // Biểu đồ khoảng cách
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: LineChart(
//                   LineChartData(
//                     gridData: FlGridData(show: true, drawVerticalLine: false),
//                     titlesData: FlTitlesData(
//                       show: true,
//                       leftTitles: AxisTitles(
//                         sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 10),
//                       ),
//                       bottomTitles: AxisTitles(
//                         sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 5),
//                       ),
//                     ),
//                     borderData: FlBorderData(show: true),
//                     lineBarsData: [
//                       LineChartBarData(
//                         spots: distanceData,
//                         isCurved: true,
//                         gradient: LinearGradient(colors: [Colors.greenAccent, Colors.black]),
//                         barWidth: 3,
//                         belowBarData: BarAreaData(
//                           show: true,
//                           gradient: LinearGradient(
//                             colors: [Colors.green.withOpacity(0.3), Colors.black.withOpacity(0.1)],
//                             begin: Alignment.topCenter,
//                             end: Alignment.bottomCenter,
//                           ),
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }