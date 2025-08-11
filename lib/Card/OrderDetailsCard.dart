import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_preferences_manager.dart';

class OrderDetailsCard extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final VoidCallback? onOrderDelivered;

  const OrderDetailsCard({
    super.key,
    required this.orderData,
    this.onOrderDelivered,
  });

  // Cache commonly used values to avoid repeated map lookups
  String get _orderId => orderData['_id'] ?? 'N/A';
  String get _status => orderData['status'] ?? 'unknown';
  String get _customerName =>
      orderData['customer']?['name'] ?? 'Unknown Customer';
  String get _customerPhone => orderData['customer']?['phone'] ?? 'No phone';
  String get _customerAddress =>
      orderData['customer']?['address'] ?? 'No address';
  String get _restaurantName =>
      orderData['restaurant']?['name'] ?? 'Unknown Restaurant';
  String get _restaurantAddress =>
      orderData['restaurant']?['address'] ?? 'No address';
  double get _totalAmount => (orderData['totalAmount'] ?? 0).toDouble();
  List<dynamic> get _items => orderData['items'] ?? [];

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

  // Method to handle delivered button press
  Future<void> _handleDelivered(BuildContext context) async {
    try {
      final prefsManager = SharedPreferencesManager();
      await prefsManager.initialize();
      debugPrint('📋 About to clear order data...');
      await prefsManager.clearOrderData();
      debugPrint('📋 Order data cleared, verifying...');

      // Verify the data was actually cleared
      final verifyOrderId = prefsManager.currentOrderId;
      debugPrint(
        '📋 Verification: currentOrderId after clear = $verifyOrderId',
      );
      debugPrint('📋 Order marked as delivered and data cleared');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as delivered!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Call the callback if provided to trigger UI refresh
        onOrderDelivered?.call();
        
        // Force a small delay to ensure SharedPreferences changes propagate
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('Error marking order as delivered: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark order as delivered'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Optimized helper method to build info cards with const widgets where possible
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Optimize layout
        children: [
          Row(
            mainAxisSize: MainAxisSize.min, // Optimize layout
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug print to see what data we're receiving
    debugPrint('OrderDetailsCard received data: $orderData');

    // Extract items from orderData if available
    final List<dynamic> items = orderData['items'] is List
        ? orderData['items']
        : [];
    if (orderData['items'] != null && orderData['items'] is! List) {
      debugPrint('Warning: "items" field is not a List: ${orderData['items']}');
    }

    String formattedDate = 'N/A';
    if (orderData['createdAt'] != null) {
      try {
        // Using the intl package for safer and more readable date formatting
        final DateTime parsedDate = DateTime.parse(orderData['createdAt']);
        formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(parsedDate);
      } catch (e) {
        debugPrint(
          'Error parsing date: $e. Value was: ${orderData['createdAt']}',
        );
        formattedDate = 'Invalid Date'; // Provide feedback on error
      }
    }

    final String orderId = orderData['_id']?.toString() ?? 'N/A';
    final String total = orderData['total_amount']?.toString() ?? 'N/A';
    final String status = orderData['status']?.toString() ?? 'N/A';
    final String customerAddress =
        orderData['userFullAddress']?.toString() ?? 'N/A';
    final String restaurantAddress =
        orderData['restaurantFullAddress']?.toString() ?? 'N/A';

    // Debug print for extracted values
    debugPrint(
      'OrderDetailsCard extracted values: orderId=$orderId, status=$status, total=$total, items=${items.length}',
    );

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.orange.withOpacity(0.05),
              Colors.deepOrange.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with order ID and status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange, Colors.orange],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order ID',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '#$orderId',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Order details section
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.access_time,
                      title: 'Order Time',
                      value: formattedDate,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.currency_rupee,
                      title: 'Total Amount',
                      value: '₹$total',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              // Items section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          color: Colors.deepOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Order Items',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${items.length} items',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "No items found",
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...items.map((item) {
                        final String quantity = item is Map
                            ? (item['quantity']?.toString() ?? '1')
                            : '1';
                        final String name = item is Map
                            ? (item['name']?.toString() ?? 'Unknown Item')
                            : 'Unknown Item';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.deepOrange, Colors.orange],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    quantity,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Addresses section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Delivery Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Customer Address
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.home, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'Customer Address',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            customerAddress,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Restaurant Address
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store, color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'Restaurant Address',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            restaurantAddress,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Delivered button (show for active orders)
              if (status.toLowerCase() == 'picked up' ||
                  status.toLowerCase() == 'pickedup' ||
                  status.toLowerCase() == 'placed' ||
                  status.toLowerCase() == 'confirmed')
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.green.shade600],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _handleDelivered(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Mark as Delivered',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
