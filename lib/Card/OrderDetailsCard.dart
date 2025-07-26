import 'package:flutter/material.dart';

class OrderDetailsCard extends StatelessWidget {
  const OrderDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("Order ID: #15253-65757", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("16-04-2022", style: TextStyle(color: Colors.grey)),
        SizedBox(height: 8),
        Text("Items:"),
        Text("- 2 x Paniyaram"),
        Text("- 2 x Godhuma Dosa"),
        Text("- 2 x Stuffed Chicken Idly"),
        Text("- 2 x Mutton Biryani"),
        SizedBox(height: 12),
        Text("Total: ₹380.00", style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
