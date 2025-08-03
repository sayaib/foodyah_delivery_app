import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'orderInProgressPage.dart';
import 'PayoutPage.dart';
import 'ProfilePage.dart';
import '../SettingsPage.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    OrderInProgressPage(),
    PayoutPage(),
    ProfilePage(),
    SettingsPage(),
  ];
  void initState() {
    super.initState();
    // Start listening for events from the background service as soon as
    // the dashboard is visible.
    listenToBackgroundService();
  }
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  void listenToBackgroundService() {
    // Listen for the 'showDialog' event from the background service
    FlutterBackgroundService().on('showDialog').listen((event) {
      if (event == null) return;

      // When the event is received, call the function to show the dialog
      // and pass the data from the background service.
      showDeliveryDialog(event);
    });
  }

  void showDeliveryDialog(Map<String, dynamic> data) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? "New Delivery Request"),
          content: Text(data['body'] ?? "You have a new delivery offer."),
          actions: <Widget>[
            TextButton(
              child: const Text('View Details'),
              onPressed: () async {
                // ✅ Signal background to start emitting location
                FlutterBackgroundService().invoke("startLocationTracking");
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.blue[900], // Darker background for better contrast
        selectedItemColor: Colors.orangeAccent, // Highlighted tab
        unselectedItemColor: Colors.white70, // Non-selected tabs
        type: BottomNavigationBarType.fixed, // Keeps all items visible
        selectedFontSize: 14,
        unselectedFontSize: 12,
        iconSize: 28,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet),
            label: "Payout",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Setting",
          ),
        ],
      ),
    );
  }

}
