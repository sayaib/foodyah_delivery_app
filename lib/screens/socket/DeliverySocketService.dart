import 'dart:async';
import 'package:location/location.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliverySocketService {
  static final DeliverySocketService _instance =
      DeliverySocketService._internal();

  factory DeliverySocketService() => _instance;

  DeliverySocketService._internal();

  IO.Socket? _socket;
  Timer? _locationTimer;
  final Location _location = Location();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isConnected = false;
  bool _isOnline = false;
  bool _isDisposed = false;
  String? _partnerId;
  String? _cachedOrderId; // Cache the current order ID

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  void initialize({required String partnerId}) {
    _partnerId = partnerId;
    _isDisposed = false;
    // Initialize cached order ID asynchronously
    _updateCachedOrderId();
  }

  void goOnline() {
    if (_partnerId == null || _isDisposed) return;
    _isOnline = true;
    _connectSocket();
  }

  void goOffline() {
    _isOnline = false;
    _disconnectSocket();
  }

  void _connectSocket() {
    if (_socket != null && _socket!.connected) return;

    final uri = dotenv.env['SOCKET_SERVER_URL_ANDROID'];
    if (uri == null || _partnerId == null) {
      _log("❗️Socket URL or Partner ID is missing");
      return;
    }

    _socket = IO.io(
      uri,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setQuery({'partnerId': _partnerId})
          .build(),
    );

    _socket!.onConnect((_) {
      _log("✅ Socket Connected");
      _isConnected = true;
      _safeAddStatus("✅ Connected");
      _startSendingLocation();
    });

    _socket!.onDisconnect((_) {
      _log("❌ Socket Disconnected");
      _isConnected = false;
      _safeAddStatus("❌ Disconnected");
    });

    _socket!.on("delivery_request", (data) {
      _handleDeliveryRequest(data);
    });

    _socket!.connect();
  }

  void _disconnectSocket() {
    _locationTimer?.cancel();
    _socket?.off("delivery_request");
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _safeAddStatus("🔌 Offline");
    _log("🛑 Socket Fully Disconnected");
  }

  void _startSendingLocation() {
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isConnected || _socket?.connected != true || _isDisposed) return;

      final permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        await _location.requestPermission();
      }

      final locationData = await _location.getLocation();
      _log(
        "📍 Sending location: ${locationData.latitude}, ${locationData.longitude}",
      );

      _socket?.emit("delivery_response", {
        "partnerId": _partnerId,
        "latitude": locationData.latitude,
        "longitude": locationData.longitude,
      });
    });
  }

  void _handleDeliveryRequest(dynamic data) async {
    if (_isDisposed) return;

    // Check if there's already an active order
    await _updateCachedOrderId();

    if (_cachedOrderId != null && _cachedOrderId!.isNotEmpty) {
      _log(
        "🚫 Delivery request rejected - already have active order: $_cachedOrderId",
      );
      _log("📦 Rejected order from: ${data['restaurantName'] ?? 'Unknown'}");
      return; // Don't process the delivery request
    }

    _audioPlayer.play(AssetSource("audio/order.mp3"));
    _log(
      "📦 Delivery request received: ${data['restaurantName'] ?? 'Unknown'}",
    );
    // TODO: Use a callback or notification system to alert the UI
  }

  // Update cached order ID from SharedPreferences
  Future<void> _updateCachedOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOrderId = prefs.getString('currentOrderId');
  }

  // Method to notify socket service when order is completed
  Future<void> notifyOrderCompleted() async {
    await _updateCachedOrderId();
    _log("📋 Order completion notified - cache updated");
  }

  void dispose() {
    if (_isDisposed) return;
    _disconnectSocket();
    _locationTimer?.cancel();
    _audioPlayer.dispose();
    _statusController.close();
    _isDisposed = true;
  }

  void _safeAddStatus(String status) {
    if (!_isDisposed && !_statusController.isClosed) {
      try {
        _statusController.add(status);
      } catch (e) {
        _log("⚠️ Failed to emit status: $e");
      }
    }
  }

  void _log(String msg) {
    print("[DeliverySocketService] $msg");
  }
}
