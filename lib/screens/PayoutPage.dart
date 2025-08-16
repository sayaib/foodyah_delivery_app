import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class PayoutPage extends StatefulWidget {
  const PayoutPage({super.key});

  @override
  State<PayoutPage> createState() => _PayoutPageState();
}

class _PayoutPageState extends State<PayoutPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _driverId = '';

  @override
  void initState() {
    super.initState();
    _loadDriverIdAndFetchPayouts();
  }

  Future<void> _loadDriverIdAndFetchPayouts() async {
    try {
      final driverId = await _storage.read(key: 'user_id') ?? 'driver_007';
      setState(() {
        _driverId = driverId;
      });
      await _fetchPayouts();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load driver information';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPayouts() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      debugPrint('💰 Fetching payouts for driver: $_driverId');

      final response = await ApiClient.post('/delivery/get-delivery-amount', {
        'driverId': _driverId,
      });

      debugPrint('💰 Payout response: $response');

      if (response != null) {
        List<Map<String, dynamic>> payouts;

        if (response is List) {
          payouts = response.cast<Map<String, dynamic>>();
        } else if (response is Map<String, dynamic> &&
            response['payouts'] is List) {
          payouts = (response['payouts'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Invalid response format');
        }

        setState(() {
          _payouts = payouts;
          _isLoading = false;
          _hasError = false;
        });

        debugPrint('💰 Successfully loaded ${_payouts.length} payouts');
      } else {
        throw Exception('No response received');
      }
    } catch (e) {
      debugPrint('💰 Error fetching payouts: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load payout data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _fetchPayouts,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              sliver: _isLoading
                  ? _buildLoadingState()
                  : _hasError
                  ? _buildErrorState()
                  : _buildPayoutContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: AppTheme.textOnPrimary,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: FlexibleSpaceBar(
          title: Text(
            'Earnings & Payouts',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.textOnPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
          titlePadding: const EdgeInsets.only(
            left: AppTheme.spacingL,
            bottom: AppTheme.spacingM,
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppTheme.spacingM),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchPayouts,
            tooltip: 'Refresh payouts',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.textOnPrimary.withOpacity(0.2),
              foregroundColor: AppTheme.textOnPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Loading your earnings...',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Unable to load earnings',
              style: AppTheme.headingSmall.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _errorMessage,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: _fetchPayouts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: AppTheme.primaryButtonStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutContent() {
    if (_payouts.isEmpty) {
      return _buildEmptyState();
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        _buildEarningsSummary(),
        const SizedBox(height: AppTheme.spacingL),
        _buildPayoutsList(),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No Earnings Yet',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Complete deliveries to start earning',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsSummary() {
    final totalEarnings = _payouts.fold<double>(
      0.0,
      (sum, payout) => sum + (payout['deliveryAmount']?.toDouble() ?? 0.0),
    );

    final totalOrders = _payouts.length;
    final avgEarningsPerOrder = totalOrders > 0
        ? totalEarnings / totalOrders
        : 0.0;

    return Container(
      decoration: AppTheme.elevatedCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: AppTheme.successColor,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Earnings Summary',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),

            // Total Earnings Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: AppTheme.successGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total Earnings',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textOnPrimary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '₹${totalEarnings.toStringAsFixed(2)}',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.textOnPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.delivery_dining_rounded,
                    AppTheme.infoColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    'Avg per Order',
                    '₹${avgEarningsPerOrder.toStringAsFixed(2)}',
                    Icons.analytics_rounded,
                    AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.headingSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            title,
            style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Recent Deliveries',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.primaryColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              ),
              child: Text(
                '${_payouts.length} orders',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),

        ..._payouts.map((payout) => _buildPayoutCard(payout)).toList(),
      ],
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    final deliveryAmount = payout['deliveryAmount']?.toDouble() ?? 0.0;
    final finalTotal = payout['finalTotal']?.toDouble() ?? 0.0;
    final status = payout['status']?.toString() ?? 'unknown';
    final orderId = payout['orderId']?.toString() ?? 'N/A';
    final customerEmail = payout['customerEmail']?.toString() ?? 'N/A';
    final restaurantAddress = payout['restaurantAddress']?.toString() ?? 'N/A';
    final userAddress = payout['userAddress']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}...',
                        style: AppTheme.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        customerEmail,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
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
                    gradient: AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '₹$deliveryAmount',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingM),

            Row(
              children: [
                Icon(
                  Icons.receipt_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Order Total: ₹${finalTotal.toStringAsFixed(2)}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AppTheme.labelSmall.copyWith(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (restaurantAddress != 'N/A' || userAddress != 'N/A') ...[
              const SizedBox(height: AppTheme.spacingM),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingM),

              if (restaurantAddress != 'N/A') ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      size: 16,
                      color: AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        restaurantAddress,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
              ],

              if (userAddress != 'N/A') ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        userAddress,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppTheme.successColor;
      case 'placed':
      case 'confirmed':
        return AppTheme.infoColor;
      case 'preparing':
      case 'ready':
        return AppTheme.warningColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}
