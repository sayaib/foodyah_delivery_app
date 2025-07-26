import 'package:flutter/material.dart';

class PayoutPage extends StatelessWidget {
  const PayoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payout Details"),
        automaticallyImplyLeading: false, // Hides the back button
      ),
      body: const Center(
        child: Text("No payouts yet.", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
