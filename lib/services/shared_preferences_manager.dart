// lib/services/shared_preferences_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A global state management service for SharedPreferences
/// Provides real-time updates across the entire application
class SharedPreferencesManager {
  // Singleton instance
  static final SharedPreferencesManager _instance = SharedPreferencesManager._internal();
  factory SharedPreferencesManager() => _instance;
  SharedPreferencesManager._internal();

  SharedPreferences? _prefs;
  
  // Stream controllers for real-time updates
  final StreamController<bool> _isTrackingController = StreamController<bool>.broadcast();
  final StreamController<String?> _currentOrderIdController = StreamController<String?>.broadcast();
  final StreamController<String?> _currentRestaurantIdController = StreamController<String?>.broadcast();
  final StreamController<String?> _currentRestaurantAddressController = StreamController<String?>.broadcast();
  final StreamController<String?> _currentCustomerAddressController = StreamController<String?>.broadcast();
  final StreamController<String?> _driverIdController = StreamController<String?>.broadcast();
  final StreamController<String?> _socketServerUrlAndroidController = StreamController<String?>.broadcast();
  final StreamController<String?> _socketServerUrlIosController = StreamController<String?>.broadcast();
  final StreamController<bool> _serviceRunningController = StreamController<bool>.broadcast();

  // Cached values for immediate access
  bool _isTracking = false;
  String? _currentOrderId;
  String? _currentRestaurantId;
  String? _currentRestaurantAddress;
  String? _currentCustomerAddress;
  String? _driverId;
  String? _socketServerUrlAndroid;
  String? _socketServerUrlIos;
  bool _serviceRunning = false;

  // Getters for streams
  Stream<bool> get isTrackingStream => _isTrackingController.stream;
  Stream<String?> get currentOrderIdStream => _currentOrderIdController.stream;
  Stream<String?> get currentRestaurantIdStream => _currentRestaurantIdController.stream;
  Stream<String?> get currentRestaurantAddressStream => _currentRestaurantAddressController.stream;
  Stream<String?> get currentCustomerAddressStream => _currentCustomerAddressController.stream;
  Stream<String?> get driverIdStream => _driverIdController.stream;
  Stream<String?> get socketServerUrlAndroidStream => _socketServerUrlAndroidController.stream;
  Stream<String?> get socketServerUrlIosStream => _socketServerUrlIosController.stream;
  Stream<bool> get serviceRunningStream => _serviceRunningController.stream;

  // Getters for cached values
  bool get isTracking => _isTracking;
  String? get currentOrderId => _currentOrderId;
  String? get currentRestaurantId => _currentRestaurantId;
  String? get currentRestaurantAddress => _currentRestaurantAddress;
  String? get currentCustomerAddress => _currentCustomerAddress;
  String? get driverId => _driverId;
  String? get socketServerUrlAndroid => _socketServerUrlAndroid;
  String? get socketServerUrlIos => _socketServerUrlIos;
  bool get serviceRunning => _serviceRunning;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAllValues();
  }

  /// Load all values from SharedPreferences and emit initial values
  Future<void> _loadAllValues() async {
    if (_prefs == null) return;

    _isTracking = _prefs!.getBool('isTracking') ?? false;
    _currentOrderId = _prefs!.getString('currentOrderId');
    _currentRestaurantId = _prefs!.getString('currentRestaurantId');
    _currentRestaurantAddress = _prefs!.getString('currentRestaurantAddress');
    _currentCustomerAddress = _prefs!.getString('currentCustomerAddress');
    _driverId = _prefs!.getString('driverId');
    _socketServerUrlAndroid = _prefs!.getString('SOCKET_SERVER_URL_ANDROID');
    _socketServerUrlIos = _prefs!.getString('SOCKET_SERVER_URL_IOS');
    _serviceRunning = _prefs!.getBool('serviceRunning') ?? false;

    // Emit initial values
    _isTrackingController.add(_isTracking);
    _currentOrderIdController.add(_currentOrderId);
    _currentRestaurantIdController.add(_currentRestaurantId);
    _currentRestaurantAddressController.add(_currentRestaurantAddress);
    _currentCustomerAddressController.add(_currentCustomerAddress);
    _driverIdController.add(_driverId);
    _socketServerUrlAndroidController.add(_socketServerUrlAndroid);
    _socketServerUrlIosController.add(_socketServerUrlIos);
    _serviceRunningController.add(_serviceRunning);

    debugPrint('SharedPreferencesManager: All values loaded and emitted');
  }

  /// Update tracking status
  Future<void> setIsTracking(bool value) async {
    if (_prefs == null) return;
    
    _isTracking = value;
    await _prefs!.setBool('isTracking', value);
    _isTrackingController.add(value);
    debugPrint('SharedPreferencesManager: isTracking updated to $value');
  }

  /// Update current order ID
  Future<void> setCurrentOrderId(String? value) async {
    if (_prefs == null) return;
    
    _currentOrderId = value;
    if (value != null) {
      await _prefs!.setString('currentOrderId', value);
    } else {
      await _prefs!.remove('currentOrderId');
    }
    _currentOrderIdController.add(value);
    debugPrint('SharedPreferencesManager: currentOrderId updated to $value');
  }

  /// Update current restaurant ID
  Future<void> setCurrentRestaurantId(String? value) async {
    if (_prefs == null) return;
    
    _currentRestaurantId = value;
    if (value != null) {
      await _prefs!.setString('currentRestaurantId', value);
    } else {
      await _prefs!.remove('currentRestaurantId');
    }
    _currentRestaurantIdController.add(value);
    debugPrint('SharedPreferencesManager: currentRestaurantId updated to $value');
  }

  /// Update current restaurant address
  Future<void> setCurrentRestaurantAddress(String? value) async {
    if (_prefs == null) return;
    
    _currentRestaurantAddress = value;
    if (value != null) {
      await _prefs!.setString('currentRestaurantAddress', value);
    } else {
      await _prefs!.remove('currentRestaurantAddress');
    }
    _currentRestaurantAddressController.add(value);
    debugPrint('SharedPreferencesManager: currentRestaurantAddress updated to $value');
  }

  /// Update current customer address
  Future<void> setCurrentCustomerAddress(String? value) async {
    if (_prefs == null) return;
    
    _currentCustomerAddress = value;
    if (value != null) {
      await _prefs!.setString('currentCustomerAddress', value);
    } else {
      await _prefs!.remove('currentCustomerAddress');
    }
    _currentCustomerAddressController.add(value);
    debugPrint('SharedPreferencesManager: currentCustomerAddress updated to $value');
  }

  /// Update driver ID
  Future<void> setDriverId(String? value) async {
    if (_prefs == null) return;
    
    _driverId = value;
    if (value != null) {
      await _prefs!.setString('driverId', value);
    } else {
      await _prefs!.remove('driverId');
    }
    _driverIdController.add(value);
    debugPrint('SharedPreferencesManager: driverId updated to $value');
  }

  /// Update Android socket server URL
  Future<void> setSocketServerUrlAndroid(String? value) async {
    if (_prefs == null) return;
    
    _socketServerUrlAndroid = value;
    if (value != null) {
      await _prefs!.setString('SOCKET_SERVER_URL_ANDROID', value);
    } else {
      await _prefs!.remove('SOCKET_SERVER_URL_ANDROID');
    }
    _socketServerUrlAndroidController.add(value);
    debugPrint('SharedPreferencesManager: SOCKET_SERVER_URL_ANDROID updated to $value');
  }

  /// Update iOS socket server URL
  Future<void> setSocketServerUrlIos(String? value) async {
    if (_prefs == null) return;
    
    _socketServerUrlIos = value;
    if (value != null) {
      await _prefs!.setString('SOCKET_SERVER_URL_IOS', value);
    } else {
      await _prefs!.remove('SOCKET_SERVER_URL_IOS');
    }
    _socketServerUrlIosController.add(value);
    debugPrint('SharedPreferencesManager: SOCKET_SERVER_URL_IOS updated to $value');
  }

  /// Update service running status
  Future<void> setServiceRunning(bool value) async {
    if (_prefs == null) return;
    
    _serviceRunning = value;
    await _prefs!.setBool('serviceRunning', value);
    _serviceRunningController.add(value);
    debugPrint('SharedPreferencesManager: serviceRunning updated to $value');
  }

  /// Clear all order-related data
  Future<void> clearOrderData() async {
    await setCurrentOrderId(null);
    await setCurrentRestaurantId(null);
    await setCurrentRestaurantAddress(null);
    await setCurrentCustomerAddress(null);
    debugPrint('SharedPreferencesManager: All order data cleared');
  }

  /// Set order data in batch
  Future<void> setOrderData({
    String? orderId,
    String? restaurantId,
    String? restaurantAddress,
    String? customerAddress,
  }) async {
    await setCurrentOrderId(orderId);
    await setCurrentRestaurantId(restaurantId);
    await setCurrentRestaurantAddress(restaurantAddress);
    await setCurrentCustomerAddress(customerAddress);
    debugPrint('SharedPreferencesManager: Order data set in batch');
  }

  /// Get socket server URL based on platform
  String getSocketServerUrl({bool isAndroid = true}) {
    if (isAndroid) {
      return _socketServerUrlAndroid ?? 'https://api.foodyah.com';
    } else {
      return _socketServerUrlIos ?? 'https://api.foodyah.com';
    }
  }

  /// Dispose all stream controllers
  void dispose() {
    _isTrackingController.close();
    _currentOrderIdController.close();
    _currentRestaurantIdController.close();
    _currentRestaurantAddressController.close();
    _currentCustomerAddressController.close();
    _driverIdController.close();
    _socketServerUrlAndroidController.close();
    _socketServerUrlIosController.close();
    _serviceRunningController.close();
  }
}