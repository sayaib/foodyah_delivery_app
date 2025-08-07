import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class OrderDetailsCard extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const OrderDetailsCard({super.key, required this.orderData});

  // Helper method to get color based on order status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.blue;
      case 'picked up':
      case 'pickedup':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug print to see what data we're receiving
    debugPrint('OrderDetailsCard received data: $orderData');

    // Extract items from orderData if available
    List<dynamic> items = [];
    if (orderData['items'] != null) {
      if (orderData['items'] is List) {
        items = orderData['items'];
      } else {
        debugPrint('Items is not a List: ${orderData['items']}');
      }
    }

    String formattedDate = 'N/A';
    if (orderData['createdAt'] != null) {
      try {
        formattedDate = DateTime.parse(
          orderData['createdAt'],
        ).toString().substring(0, 16);
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    String orderId = orderData['_id']?.toString() ?? 'N/A';
    String total = orderData['total_amount']?.toString() ?? 'N/A';
    String status = orderData['status']?.toString() ?? 'N/A';
    String customerAddress = orderData['userFullAddress']?.toString() ?? 'N/A';
    String restaurantAddress =
        orderData['restaurantFullAddress']?.toString() ?? 'N/A';

    // Debug print for extracted values
    debugPrint(
      'OrderDetailsCard extracted values: orderId=$orderId, status=$status, total=$total, items=${items.length}',
    );

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order ID: #$orderId",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            const Text("Items:", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            if (items.isEmpty)
              const Text(
                "- No items found",
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              )
            else
              ...items.map((item) {
                // Safely extract item properties
                final quantity = item is Map
                    ? (item['quantity']?.toString() ?? '1')
                    : '1';
                final name = item is Map
                    ? (item['name']?.toString() ?? 'Unknown Item')
                    : 'Unknown Item';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    "- $quantity x $name",
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
            const SizedBox(height: 12),
            Text(
              "Total: ₹$total",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              "Customer Address:",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(customerAddress, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text(
              "Restaurant Address:",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(restaurantAddress, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
