import 'package:flutter/material.dart';

class OrderInProgressPage extends StatefulWidget {
  const OrderInProgressPage({super.key});

  @override
  State<OrderInProgressPage> createState() => _OrderInProgressPageState();
}

class _OrderInProgressPageState extends State<OrderInProgressPage> {
  bool isOnline = false;

  void _handleSwitch(bool value) {
    setState(() {
      isOnline = value;
    });
    print(isOnline ? "Online" : "Offline");
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
      body: Column(
        children: [
          const TabBarHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: OrderDetailsCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TabBarHeader extends StatelessWidget {
  const TabBarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: const [
          Text("In Progress",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.brown)),
          SizedBox(width: 20),
          Text("History", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class OrderDetailsCard extends StatelessWidget {
  const OrderDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      "2 X Paniyaram",
      "2 X Godhuma Dosa",
      "2 X Stuffed Chicken Idly",
      "2 X Mutton Biryani",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order ID and Payment
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Order ID | #15253-65757",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.brown,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "COD",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text("16-04-2022", style: TextStyle(color: Colors.black54)),
        const Divider(height: 24),

        // Order Progress
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            OrderStatus(title: "Order placed", time: "07:30AM", isDone: true),
            OrderStatus(title: "Picked UP", time: "08:00AM", isDone: true),
            OrderStatus(title: "Delivered", time: "", isDone: false),
          ],
        ),
        const SizedBox(height: 16),

        // Distance
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("08 km"),
            Icon(Icons.delivery_dining, color: Colors.orange),
            Text("07 km"),
          ],
        ),
        const Divider(height: 32),

        // Customer Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                CircleAvatar(child: Icon(Icons.person)),
                SizedBox(width: 8),
                Text("Praba\nCustomer Name"),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () {
                // handle call action here
              },
            ),
          ],
        ),
        const Divider(height: 32),

        // Order Items
        const Text("Order Details",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.brown)),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.check_box_outline_blank,
                    size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(item),
              ],
            ),
          ))
              .toList(),
        ),
        const Divider(height: 32),

        // Kitchen Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("Geetha Kitchen\n4 orders From Kitchen"),
            Text("Total Cost : ₹ 380.00",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 20),

        // Navigation + Drop Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'nav',
              onPressed: () {},
              backgroundColor: Colors.blue,
              child: const Icon(Icons.navigation),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text("Reached Drop Location",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}

class OrderStatus extends StatelessWidget {
  final String title;
  final String time;
  final bool isDone;

  const OrderStatus({
    super.key,
    required this.title,
    required this.time,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isDone ? Colors.green : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
        if (time.isNotEmpty)
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
