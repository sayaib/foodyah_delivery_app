// lib/services/location_permission_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class LocationPermissionService {
  // Cache permission status to avoid repeated checks
  static PermissionStatus? _cachedLocationStatus;
  static PermissionStatus? _cachedBackgroundStatus;
  static DateTime? _lastPermissionCheck;
  
  // Cache duration (5 minutes)
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
  // Check if cache is still valid
  static bool _isCacheValid() {
    return _lastPermissionCheck != null &&
        DateTime.now().difference(_lastPermissionCheck!).compareTo(_cacheValidDuration) < 0;
  }
  
  // A helper function to show a dialog to the user
  static Future<void> _showPermissionDialog(
    BuildContext context,
    String title,
    String content,
    VoidCallback onGrant,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Open Settings"), // Changed text for clarity
            onPressed: onGrant,
          ),
        ],
      ),
    );
  }

  static Future<void> _requestFullAccuracy() async {
    if (Platform.isIOS) {
      try {
        debugPrint('Checking iOS location accuracy status...');
        final accuracy = await Geolocator.getLocationAccuracy();
        debugPrint('Current iOS location accuracy status: $accuracy');

        if (accuracy == LocationAccuracyStatus.reduced) {
          debugPrint(
            'iOS location accuracy is reduced, requesting temporary full accuracy',
          );
          // Request temporary full accuracy
          final result = await Geolocator.requestTemporaryFullAccuracy(
            purposeKey:
                "deliveryRouteAccuracy", // Must match the key in Info.plist
          );
          debugPrint('After request, iOS location accuracy status: $result');
        } else {
          debugPrint('iOS location accuracy is already precise');
        }
      } catch (e) {
        debugPrint('Error requesting full accuracy on iOS: $e');
        // Check if the error is related to the purposeKey
        if (e.toString().contains('purposeKey')) {
          debugPrint('Error might be related to the purposeKey in Info.plist');
        }
      }
    }
  }

  // Main function to handle location permission requests with caching
  static Future<bool> requestLocationPermission(BuildContext context) async {
    debugPrint("Requesting location permission...");
    
    // Use cached status if available and valid
    PermissionStatus status;
    if (_isCacheValid() && _cachedLocationStatus != null) {
      status = _cachedLocationStatus!;
      debugPrint("Using cached location permission status: $status");
    } else {
      status = await Permission.location.status;
      _cachedLocationStatus = status;
      _lastPermissionCheck = DateTime.now();
      debugPrint("Current location permission status: $status");
    }

    // FIXED: Use '==' for enum comparison instead of .isGranted
    if (status == PermissionStatus.granted) {
      // If permission is already granted, check for background permission
      debugPrint(
        "Location permission already granted, requesting full accuracy",
      );
      await _requestFullAccuracy();
      return requestBackgroundLocationPermission(context);
    }

    // FIXED: Use '==' for enum comparison instead of .isPermanentlyDenied
    if (status == PermissionStatus.permanentlyDenied) {
      // If permanently denied, show a dialog guiding user to settings
      await _showPermissionDialog(
        context,
        'Permission Required',
        'Location permission is permanently denied. Please enable it from the app settings to continue.',
        () {
          Navigator.of(context).pop();
          openAppSettings(); // Opens the app settings page
        },
      );
      return false;
    }

    // If denied or not determined, request it.
    debugPrint("Requesting location permission from system...");
    var newStatus = await Permission.location.request();
    debugPrint("After request, location permission status: $newStatus");

    // FIXED: Use '==' for enum comparison
    if (newStatus == PermissionStatus.granted) {
      // If granted, now request background permission
      debugPrint(
        "Location permission granted, now requesting background permission",
      );
      await _requestFullAccuracy();
      return requestBackgroundLocationPermission(context);
    } else if (newStatus == PermissionStatus.denied) {
      debugPrint("Location permission denied by user");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for tracking'),
        ),
      );
    } else if (newStatus == PermissionStatus.permanentlyDenied) {
      debugPrint("Location permission permanently denied");
      await _showPermissionDialog(
        context,
        'Permission Required',
        'Location permission is permanently denied. Please enable it from the app settings to continue.',
        () {
          Navigator.of(context).pop();
          openAppSettings(); // Opens the app settings page
        },
      );
    }

    return false;
  }

  // Function to handle the "Always" / Background location permission with caching
  static Future<bool> requestBackgroundLocationPermission(
    BuildContext context,
  ) async {
    debugPrint("Requesting background location permission...");
    
    // Use cached status if available and valid
    PermissionStatus status;
    if (_isCacheValid() && _cachedBackgroundStatus != null) {
      status = _cachedBackgroundStatus!;
      debugPrint("Using cached background location permission status: $status");
    } else {
      status = await Permission.locationAlways.status;
      _cachedBackgroundStatus = status;
      _lastPermissionCheck = DateTime.now();
      debugPrint("Current background location permission status: $status");
    }

    // FIXED: Use '==' for enum comparison
    if (status == PermissionStatus.granted) {
      debugPrint("Background location permission already granted");
      return true; // Already granted
    }

    // IMPORTANT: Show the prominent disclosure dialog BEFORE requesting the permission.
    bool userAgreed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Background Location"),
            content: const Text(
              "To provide continuous location updates to the customer, our app needs to track your location even when it's closed or not in use. Your location is only shared during an active delivery.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Deny"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Allow"),
              ),
            ],
          ),
        ) ??
        false;

    if (userAgreed) {
      // If user agrees in our dialog, then show the system dialog.
      debugPrint(
        "User agreed to background location disclosure, requesting system permission",
      );
      // FIXED: Awaited the request and then compared the resulting status.
      final newStatus = await Permission.locationAlways.request();
      _cachedBackgroundStatus = newStatus;
      _lastPermissionCheck = DateTime.now();
      debugPrint(
        "After request, background location permission status: $newStatus",
      );

      if (newStatus == PermissionStatus.granted) {
        debugPrint("Background location permission granted");
        return true;
      } else if (newStatus == PermissionStatus.denied) {
        debugPrint("Background location permission denied by user");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Background location permission is required for continuous tracking',
            ),
          ),
        );
      } else if (newStatus == PermissionStatus.permanentlyDenied) {
        debugPrint("Background location permission permanently denied");
        await _showPermissionDialog(
          context,
          'Permission Required',
          'Background location permission is permanently denied. Please enable it from the app settings to continue.',
          () {
            Navigator.of(context).pop();
            openAppSettings(); // Opens the app settings page
          },
        );
      }
      return false;
    } else {
      // User did not agree to the background permission disclosure.
      debugPrint("User declined background location disclosure dialog");
      return false;
    }
  }
}
