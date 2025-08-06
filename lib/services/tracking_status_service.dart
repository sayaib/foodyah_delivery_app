// lib/services/tracking_status_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to manage tracking status across the app
/// This provides a centralized way to update and listen to tracking status changes
class TrackingStatusService {
  // Singleton instance
  static final TrackingStatusService _instance = TrackingStatusService._internal();
  factory TrackingStatusService() => _instance;
  TrackingStatusService._internal();

  // Stream controller for tracking status changes
  final _trackingStatusController = StreamController<bool>.broadcast();
  Stream<bool> get trackingStatusStream => _trackingStatusController.stream;

  // Stream controller for service running status changes
  final _serviceRunningController = StreamController<bool>.broadcast();
  Stream<bool> get serviceRunningStream => _serviceRunningController.stream;

  // Current status
  bool _isTracking = false;
  bool _isServiceRunning = false;

  bool get isTracking => _isTracking;
  bool get isServiceRunning => _isServiceRunning;

  // Initialize the service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isTracking = prefs.getBool('isTracking') ?? false;
    // Emit initial value
    _trackingStatusController.add(_isTracking);
  }

  // Update tracking status
  Future<void> updateTrackingStatus(bool isTracking) async {
    _isTracking = isTracking;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking', isTracking);
    _trackingStatusController.add(isTracking);
  }

  // Update service running status
  void updateServiceRunningStatus(bool isRunning) {
    // Only update and broadcast if the status has changed
    if (_isServiceRunning != isRunning) {
      _isServiceRunning = isRunning;
      _serviceRunningController.add(isRunning);
      debugPrint('TrackingStatusService: Service running status updated to $isRunning');
    }
  }

  // Dispose resources
  void dispose() {
    _trackingStatusController.close();
    _serviceRunningController.close();
  }
}