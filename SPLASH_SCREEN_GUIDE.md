# Splash Screen Implementation Guide for Foodyah Delivery App

## Overview

This guide explains how to implement and customize the splash screen for your Foodyah Delivery App on both Android and iOS platforms. A well-designed splash screen enhances the user experience by providing visual feedback during app initialization.

## Current Implementation Status

The app currently has basic placeholder splash screens:

- **Android**: Uses the default `launch_background.xml` files with a white background
- **iOS**: Uses a basic `LaunchImage` in the Assets catalog

## Implementation Options

### Option 1: Native Splash Screens (Recommended)

The most efficient approach is to use the `flutter_native_splash` package, which generates platform-specific splash screens.

#### Setup Steps:

1. **Add the package to your pubspec.yaml**:

```yaml
dev_dependencies:
  flutter_native_splash: ^2.3.1
```

2. **Create a configuration in pubspec.yaml**:

```yaml
flutter_native_splash:
  color: "#FF5722"  # Foodyah orange background color
  image: assets/splash_logo.png  # Your logo image (create this file)
  color_dark: "#121212"  # Optional: dark mode background
  image_dark: assets/splash_logo_dark.png  # Optional: dark mode logo
  
  android_12:
    image: assets/splash_logo_android12.png  # Higher resolution for Android 12
    icon_background_color: "#FF5722"
    image_dark: assets/splash_logo_android12_dark.png  # Optional
    icon_background_color_dark: "#121212"  # Optional
  
  web: false  # Set to true if you need web splash screen
  fullscreen: false  # Set to true for fullscreen splash
```

3. **Create the splash logo images** in the assets directory:
   - `splash_logo.png`: Recommended size 1152×1152px (will be scaled down)
   - `splash_logo_android12.png`: For Android 12+ (960×960px)

4. **Generate the splash screens**:

```bash
flutter pub run flutter_native_splash:create
```

5. **To remove the generated splash screen** (if needed):

```bash
flutter pub run flutter_native_splash:remove
```

### Option 2: Manual Implementation

#### Android Manual Implementation

1. **Update the launch_background.xml files**:

Edit `android/app/src/main/res/drawable/launch_background.xml` and `android/app/src/main/res/drawable-v21/launch_background.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash_image" />
    </item>
</layer-list>
```

2. **Add the splash image**:
   - Create a PNG image named `splash_image.png`
   - Place it in `android/app/src/main/res/drawable/`

3. **Add the background color**:
   - Create `android/app/src/main/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_background">#FF5722</color>
</resources>
```

#### iOS Manual Implementation

1. **Update the LaunchScreen.storyboard**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Navigate to `Runner > Runner > Base.lproj > LaunchScreen.storyboard`
   - Design your splash screen using Interface Builder

2. **Replace the LaunchImage**:
   - In Xcode, navigate to `Runner > Assets.xcassets > LaunchImage`
   - Replace the existing images with your custom splash images
   - Ensure you have images for all required resolutions (1x, 2x, 3x)

## Flutter-level Splash Screen (Optional Additional Screen)

You may want to add a Flutter-level splash screen that appears after the native splash screen for additional functionality like loading resources or checking authentication status.

1. **Create a SplashScreen widget**:

```dart
import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Add initialization logic here
    Timer(Duration(seconds: 2), () {
      // Navigate to the appropriate screen
      Navigator.of(context).pushReplacementNamed('/landing');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFF5722), // Foodyah orange
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/foodyah_logo.png',
              width: 200,
              height: 200,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 24),
            Text(
              'Foodyah Delivery',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

2. **Update your app's initial route**:

Modify your `main.dart` to show this splash screen first:

```dart
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
// Import other screens

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize services
  
  runApp(FoodyahApp());
}

class FoodyahApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodyah Delivery',
      theme: ThemeData(
        primaryColor: Color(0xFFFF5722),
        // Other theme settings
      ),
      home: SplashScreen(), // Set the splash screen as the initial screen
      routes: {
        '/landing': (context) => LandingPage(),
        // Other routes
      },
    );
  }
}
```

## Best Practices

1. **Keep it Simple**: The splash screen should be clean and focused on your brand
2. **Fast Loading**: Don't perform heavy operations during the splash screen
3. **Consistent Branding**: Use your brand colors and logo
4. **Test on Multiple Devices**: Ensure the splash screen looks good on various screen sizes
5. **Dark Mode Support**: Consider providing dark mode variants of your splash screen

## Troubleshooting

- **Splash Screen Not Showing**: Make sure the image paths are correct and the images exist
- **Splash Screen Flickers**: This might indicate slow initialization; optimize your app startup
- **Image Quality Issues**: Use high-resolution images and test on different devices

## Additional Resources

- [flutter_native_splash package](https://pub.dev/packages/flutter_native_splash)
- [Android Splash Screen Guide](https://developer.android.com/develop/ui/views/launch/splash-screen)
- [iOS Launch Screen Guidelines](https://developer.apple.com/design/human-interface-guidelines/launching)

---

By implementing a professional splash screen, you'll enhance the perceived quality of your Foodyah Delivery App and provide a smoother user experience during app startup.