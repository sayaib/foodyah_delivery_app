// lib/services/shared_preferences_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton class to manage SharedPreferences data and provide streams for real-time updates
class SharedPreferencesManager {
  // Singleton instance
  static final SharedPreferencesManager _instance = SharedPreferencesManager._internal();
  factory SharedPreferencesManager() => _instance;
  SharedPreferencesManager._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Stream controllers for real-time updates with lazy initialization
  StreamController<bool>? _isTrackingController;
  StreamController<String?>? _currentOrderIdController;
  StreamController<String?>? _currentRestaurantIdController;
  StreamController<String?>? _currentRestaurantAddressController;
  StreamController<String?>? _currentCustomerAddressController;
  StreamController<String?>? _driverIdController;
  StreamController<String?>? _socketServerUrlAndroidController;
  StreamController<String?>? _socketServerUrlIosController;
  StreamController<bool>? _serviceRunningController;

  // Lazy getters for stream controllers
  StreamController<bool> get _isTrackingControllerInstance {
    _isTrackingController ??= StreamController<bool>.broadcast();
    return _isTrackingController!;
  }

  StreamController<String?> get _currentOrderIdControllerInstance {
    _currentOrderIdController ??= StreamController<String?>.broadcast();
    return _currentOrderIdController!;
  }

  StreamController<String?> get _currentRestaurantIdControllerInstance {
    _currentRestaurantIdController ??= StreamController<String?>.broadcast();
    return _currentRestaurantIdController!;
  }

  StreamController<String?> get _currentRestaurantAddressControllerInstance {
    _currentRestaurantAddressController ??= StreamController<String?>.broadcast();
    return _currentRestaurantAddressController!;
  }

  StreamController<String?> get _currentCustomerAddressControllerInstance {
    _currentCustomerAddressController ??= StreamController<String?>.broadcast();
    return _currentCustomerAddressController!;
  }

  StreamController<String?> get _driverIdControllerInstance {
    _driverIdController ??= StreamController<String?>.broadcast();
    return _driverIdController!;
  }

  StreamController<String?> get _socketServerUrlAndroidControllerInstance {
    _socketServerUrlAndroidController ??= StreamController<String?>.broadcast();
    return _socketServerUrlAndroidController!;
  }

  StreamController<String?> get _socketServerUrlIosControllerInstance {
    _socketServerUrlIosController ??= StreamController<String?>.broadcast();
    return _socketServerUrlIosController!;
  }

  StreamController<bool> get _serviceRunningControllerInstance {
    _serviceRunningController ??= StreamController<bool>.broadcast();
    return _serviceRunningController!;
  }

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

  // Streams for external access with lazy initialization
  Stream<bool> get isTrackingStream => _isTrackingControllerInstance.stream;
  Stream<String?> get currentOrderIdStream => _currentOrderIdControllerInstance.stream;
  Stream<String?> get currentRestaurantIdStream => _currentRestaurantIdControllerInstance.stream;
  Stream<String?> get currentRestaurantAddressStream => _currentRestaurantAddressControllerInstance.stream;
  Stream<String?> get currentCustomerAddressStream => _currentCustomerAddressControllerInstance.stream;
  Stream<String?> get driverIdStream => _driverIdControllerInstance.stream;
  Stream<String?> get socketServerUrlAndroidStream => _socketServerUrlAndroidControllerInstance.stream;
  Stream<String?> get socketServerUrlIosStream => _socketServerUrlIosControllerInstance.stream;
  Stream<bool> get serviceRunningStream => _serviceRunningControllerInstance.stream;

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

  /// Initialize SharedPreferences and load all values
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent multiple initializations
    
    _prefs = await SharedPreferences.getInstance();
    await _loadAllValues();
    _isInitialized = true;
    debugPrint('SharedPreferencesManager: Initialized successfully');
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

    // Emit initial values only if controllers are initialized
    if (_isTrackingController != null) _isTrackingController!.add(_isTracking);
    if (_currentOrderIdController != null) _currentOrderIdController!.add(_currentOrderId);
    if (_currentRestaurantIdController != null) _currentRestaurantIdController!.add(_currentRestaurantId);
    if (_currentRestaurantAddressController != null) _currentRestaurantAddressController!.add(_currentRestaurantAddress);
    if (_currentCustomerAddressController != null) _currentCustomerAddressController!.add(_currentCustomerAddress);
    if (_driverIdController != null) _driverIdController!.add(_driverId);
    if (_socketServerUrlAndroidController != null) _socketServerUrlAndroidController!.add(_socketServerUrlAndroid);
    if (_socketServerUrlIosController != null) _socketServerUrlIosController!.add(_socketServerUrlIos);
    if (_serviceRunningController != null) _serviceRunningController!.add(_serviceRunning);

    debugPrint('SharedPreferencesManager: All values loaded and emitted');
  }

  /// Force reload all values from SharedPreferences (useful for background services)
  Future<void> reloadValues() async {
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

    // Emit initial values only if controllers are initialized
    if (_isTrackingController != null) _isTrackingController!.add(_isTracking);
    if (_currentOrderIdController != null) _currentOrderIdController!.add(_currentOrderId);
    if (_currentRestaurantIdController != null) _currentRestaurantIdController!.add(_currentRestaurantId);
    if (_currentRestaurantAddressController != null) _currentRestaurantAddressController!.add(_currentRestaurantAddress);
    if (_currentCustomerAddressController != null) _currentCustomerAddressController!.add(_currentCustomerAddress);
    if (_driverIdController != null) _driverIdController!.add(_driverId);
    if (_socketServerUrlAndroidController != null) _socketServerUrlAndroidController!.add(_socketServerUrlAndroid);
    if (_socketServerUrlIosController != null) _socketServerUrlIosController!.add(_socketServerUrlIos);
    if (_serviceRunningController != null) _serviceRunningController!.add(_serviceRunning);

    debugPrint('SharedPreferencesManager: All values loaded and emitted');
  }

  /// Update tracking status
  Future<void> setIsTracking(bool value) async {
    if (_prefs == null) return;
    
    _isTracking = value;
    await _prefs!.setBool('isTracking', value);
    _isTrackingControllerInstance.add(value);
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
    _currentOrderIdControllerInstance.add(value);
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
    _currentRestaurantIdControllerInstance.add(value);
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
    _currentRestaurantAddressControllerInstance.add(value);
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
    _currentCustomerAddressControllerInstance.add(value);
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
    _driverIdControllerInstance.add(value);
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
    _socketServerUrlAndroidControllerInstance.add(value);
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
    _socketServerUrlIosControllerInstance.add(value);
    debugPrint('SharedPreferencesManager: SOCKET_SERVER_URL_IOS updated to $value');
  }

  /// Update service running status
  Future<void> setServiceRunning(bool value) async {
    if (_prefs == null) return;
    
    _serviceRunning = value;
    await _prefs!.setBool('serviceRunning', value);
    _serviceRunningControllerInstance.add(value);
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
    _isTrackingController?.close();
    _currentOrderIdController?.close();
    _currentRestaurantIdController?.close();
    _currentRestaurantAddressController?.close();
    _currentCustomerAddressController?.close();
    _driverIdController?.close();
    _socketServerUrlAndroidController?.close();
    _socketServerUrlIosController?.close();
    _serviceRunningController?.close();
    
    _isTrackingController = null;
    _currentOrderIdController = null;
    _currentRestaurantIdController = null;
    _currentRestaurantAddressController = null;
    _currentCustomerAddressController = null;
    _driverIdController = null;
    _socketServerUrlAndroidController = null;
    _socketServerUrlIosController = null;
    _serviceRunningController = null;
    
    _isInitialized = false;
  }
}