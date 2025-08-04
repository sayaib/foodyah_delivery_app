// lib/services/location_permission_service.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class LocationPermissionService {
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
      final accuracy = await Geolocator.getLocationAccuracy();
      if (accuracy == LocationAccuracyStatus.reduced) {
        // Request temporary full accuracy
        await Geolocator.requestTemporaryFullAccuracy(
          // --- THIS IS THE FIX ---
          purposeKey: "deliveryRouteAccuracy", // Must match the key in Info.plist
        );
      }
    }
  }
  // Main function to handle location permission requests.
  static Future<bool> requestLocationPermission(BuildContext context) async {
    var status = await Permission.location.status;

    // FIXED: Use '==' for enum comparison instead of .isGranted
    if (status == PermissionStatus.granted) {
      // If permission is already granted, check for background permission
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
    var newStatus = await Permission.location.request();

    // FIXED: Use '==' for enum comparison
    if (newStatus == PermissionStatus.granted) {
      // If granted, now request background permission
      return requestBackgroundLocationPermission(context);
    }

    return false;
  }

  // Function to handle the "Always" / Background location permission
  static Future<bool> requestBackgroundLocationPermission(
      BuildContext context) async {
    var status = await Permission.locationAlways.status;

    // FIXED: Use '==' for enum comparison
    if (status == PermissionStatus.granted) {
      return true; // Already granted
    }

    // IMPORTANT: Show the prominent disclosure dialog BEFORE requesting the permission.
    bool userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Background Location"),
        content: const Text(
            "To provide continuous location updates to the customer, our app needs to track your location even when it's closed or not in use. Your location is only shared during an active delivery."),
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
      // FIXED: Awaited the request and then compared the resulting status.
      final newStatus = await Permission.locationAlways.request();
      return newStatus == PermissionStatus.granted;
    } else {
      // User did not agree to the background permission disclosure.
      return false;
    }
  }
}