import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'socket/DeliverySocketService.dart';

class OrderInProgressPage extends StatefulWidget {
  const OrderInProgressPage({Key? key}) : super(key: key);

  @override
  State<OrderInProgressPage> createState() => _OrderInProgressPageState();
}

class _OrderInProgressPageState extends State<OrderInProgressPage> {
  bool isOnline = false;
  final DeliverySocketService _deliveryService = DeliverySocketService();

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
    _deliveryService.initialize(partnerId: "partner_123");
  }

  Future<void> _loadOnlineStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final status = prefs.getBool('isOnline') ?? false;
    setState(() {
      isOnline = status;
    });
    if (status) {
      _deliveryService.goOnline();
    }
  }

  Future<void> _handleSwitch(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnline', value);
    setState(() {
      isOnline = value;
    });

    if (value) {
      _deliveryService.goOnline();
    } else {
      _deliveryService.goOffline();
    }
  }

  Future<void> _openGoogleMapDirections({
    required double lat,
    required double lng,
  }) async {
    final Uri googleMapUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );

    if (!await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication)) {
      throw "Could not launch Google Maps.";
    }
  }

  @override
  void dispose() {
    _deliveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Switch(
            value: isOnline,
            onChanged: _handleSwitch,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
            inactiveTrackColor: Colors.red.shade200,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.all(12.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.help, color: Colors.brown),
            ),
          )
        ],
      ),
      body: const Center(
        child: Text("Delivery Content Goes Here"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.map),
        label: const Text("Open Google Maps"),
        onPressed: () {
          _openGoogleMapDirections(lat: 22.5726, lng: 88.3639); // Example location
        },
      ),
    );
  }
}
