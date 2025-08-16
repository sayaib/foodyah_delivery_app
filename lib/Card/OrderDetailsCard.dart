import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_preferences_manager.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

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

  // Helper method to get color based on order status using app theme
  Color _getStatusColor(String status) {
    return StatusColors.getStatusColor(status);
  }

  // Method to handle delivered button press
  Future<void> _handleDelivered(BuildContext context) async {
    // Show OTP verification dialog first
    final otpVerified = await _showOtpVerificationDialog(context);

    if (!otpVerified) {
      debugPrint('📋 OTP verification failed or cancelled');
      return;
    }

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

  // Method to show OTP verification dialog
  Future<bool> _showOtpVerificationDialog(BuildContext context) async {
    final TextEditingController otpController = TextEditingController();
    bool isLoading = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.security, color: Colors.orange, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Delivery Verification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Please enter the 4-digit OTP provided by the customer to confirm delivery:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: '0000',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.orange,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        enabled: !isLoading,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop(false);
                            },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final otp = otpController.text.trim();
                              if (otp.length != 4) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a valid 4-digit OTP',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                isLoading = true;
                              });

                              try {
                                final verified = await _verifyOtpWithBackend(
                                  otp,
                                );
                                if (verified) {
                                  Navigator.of(dialogContext).pop(true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Invalid OTP. Please try again.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Verification failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Verify'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  // Method to verify OTP with backend API
  Future<bool> _verifyOtpWithBackend(String otp) async {
    try {
      final currentOrderId = _orderId; // Use the cached order ID getter

      debugPrint('📋 Verifying OTP: $otp for order: $currentOrderId');

      final response = await ApiClient.post('/delivery/verify-otp', {
        'orderId': currentOrderId,
        'otp': otp,
      });

      debugPrint('📋 OTP verification response: $response');

      // Check if the response contains success: true
      if (response is Map<String, dynamic>) {
        return response['success'] == true;
      }

      return false;
    } catch (e) {
      debugPrint('📋 OTP verification error: $e');
      return false;
    }
  }

  // Optimized helper method to build info cards with app theme styling
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
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
      elevation: AppTheme.elevationL,
      margin: const EdgeInsets.symmetric(
        vertical: AppTheme.spacingM,
        horizontal: AppTheme.spacingM,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with order ID and status
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
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
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusS,
                              ),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: AppTheme.textOnPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order ID',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.textOnPrimary.withOpacity(
                                      0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingXS),
                                Text(
                                  '#$orderId',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textOnPrimary,
                                    fontWeight: FontWeight.w700,
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
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCircular,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textOnPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Order details section
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.access_time_rounded,
                      title: 'Order Time',
                      value: formattedDate,
                      color: AppTheme.infoColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.currency_rupee_rounded,
                      title: 'Total Amount',
                      value: '₹$total',
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Items section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppTheme.secondaryColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Text(
                          'Order Items',
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.secondaryColor,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingS,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                          ),
                          child: Text(
                            '${items.length} items',
                            style: AppTheme.labelSmall.copyWith(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        decoration: BoxDecoration(
                          color: AppTheme.textHint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: AppTheme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.textHint,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Text(
                              "No items found",
                              style: AppTheme.bodyMedium.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textHint,
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
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.spacingS,
                          ),
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: AppTheme.cardDecoration,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.secondaryColor
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    quantity,
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textOnPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
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
              // Addresses section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(
                    color: AppTheme.infoColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.infoColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Text(
                          'Delivery Information',
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.infoColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingL),

                    // Customer Address
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusS,
                                  ),
                                ),
                                child: Icon(
                                  Icons.home_rounded,
                                  color: AppTheme.successColor,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'Customer Address',
                                style: AppTheme.labelSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            customerAddress,
                            style: AppTheme.bodyMedium.copyWith(
                              height: 1.4,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Restaurant Address
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusS,
                                  ),
                                ),
                                child: Icon(
                                  Icons.store_rounded,
                                  color: AppTheme.secondaryColor,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'Restaurant Address',
                                style: AppTheme.labelSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            restaurantAddress,
                            style: AppTheme.bodyMedium.copyWith(
                              height: 1.4,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Delivered button (show for active orders)
              if (status.toLowerCase() == 'picked up' ||
                  status.toLowerCase() == 'pickedup' ||
                  status.toLowerCase() == 'placed' ||
                  status.toLowerCase() == 'confirmed')
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successColor.withOpacity(0.3),
                        blurRadius: 12,
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.textOnPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Text(
                          'Mark as Delivered',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textOnPrimary,
                            fontWeight: FontWeight.w700,
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
