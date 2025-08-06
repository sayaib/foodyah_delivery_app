# App Icon Guide for Foodyah Delivery App

## Overview

This guide explains how to replace the placeholder app icons with your custom branded icons for both Android and iOS platforms.

## Icon Requirements

### Android

#### Standard Icons
Android requires multiple icon sizes for different screen densities:

- `mipmap-mdpi/ic_launcher.png`: 48x48 px
- `mipmap-hdpi/ic_launcher.png`: 72x72 px
- `mipmap-xhdpi/ic_launcher.png`: 96x96 px
- `mipmap-xxhdpi/ic_launcher.png`: 144x144 px
- `mipmap-xxxhdpi/ic_launcher.png`: 192x192 px

#### Adaptive Icons (Android 8.0+)
For modern Android devices, adaptive icons consist of:

1. **Background Layer**: A solid color or simple pattern
2. **Foreground Layer**: Your logo or icon with transparent areas

Files:
- `mipmap-anydpi-v26/ic_launcher.xml`: XML configuration for the adaptive icon
- `mipmap-anydpi-v26/ic_launcher_round.xml`: XML configuration for round adaptive icon
- `drawable/ic_launcher_foreground.xml`: Vector drawable for the foreground layer
- `values/ic_launcher_background.xml`: Color resource for the background layer

### iOS

The iOS app icon set is located in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and includes:

- `Icon-App-20x20@1x.png`: 20x20 px
- `Icon-App-20x20@2x.png`: 40x40 px
- `Icon-App-20x20@3x.png`: 60x60 px
- `Icon-App-29x29@1x.png`: 29x29 px
- `Icon-App-29x29@2x.png`: 58x58 px
- `Icon-App-29x29@3x.png`: 87x87 px
- `Icon-App-40x40@1x.png`: 40x40 px
- `Icon-App-40x40@2x.png`: 80x80 px
- `Icon-App-40x40@3x.png`: 120x120 px
- `Icon-App-60x60@2x.png`: 120x120 px
- `Icon-App-60x60@3x.png`: 180x180 px
- `Icon-App-76x76@1x.png`: 76x76 px
- `Icon-App-76x76@2x.png`: 152x152 px
- `Icon-App-83.5x83.5@2x.png`: 167x167 px
- `Icon-App-1024x1024@1x.png`: 1024x1024 px (App Store icon)

## Creating Custom Icons

### Design Guidelines

1. **Keep it Simple**: Use a simple, recognizable design that works at small sizes
2. **Maintain Padding**: Leave appropriate padding around your icon (about 10-15%)
3. **Use Brand Colors**: Maintain consistency with your brand's color scheme
4. **Test on Devices**: Check how your icon looks on actual devices with different backgrounds
5. **Follow Platform Guidelines**:
   - [Android Adaptive Icon Guidelines](https://developer.android.com/guide/practices/ui_guidelines/icon_design_adaptive)
   - [iOS Human Interface Guidelines for App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)

### Tools for Creating Icons

- **Adobe Illustrator/Photoshop**: Professional design tools
- **Sketch/Figma**: Modern UI design tools with export capabilities
- **[Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/index.html)**: Web tool for generating Android icons
- **[MakeAppIcon](https://makeappicon.com/)**: Web tool that generates all required icon sizes
- **[AppIcon](https://appicon.co/)**: Simple web tool for generating iOS app icons

## Replacing Icons

### Android

#### Standard Icons

1. Create your icon in the required sizes
2. Replace the existing PNG files in the respective `mipmap-*` folders

#### Adaptive Icons

1. Design your foreground layer as a vector drawable or PNG
2. If using a vector drawable, update `drawable/ic_launcher_foreground.xml`
3. If using PNGs, create foreground images and place them in the appropriate mipmap folders
4. Update the background color in `values/ic_launcher_background.xml`

### iOS

#### Using Xcode (Recommended)

1. Open your Flutter project in Xcode: `open ios/Runner.xcworkspace`
2. In the Project Navigator, select `Runner > Assets.xcassets > AppIcon`
3. Replace each icon by dragging your custom icons onto the appropriate slots

#### Manual Replacement

1. Generate all required icon sizes
2. Replace the PNG files in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
3. Ensure the filenames match exactly as listed in `Contents.json`

## Testing Icons

After replacing the icons:

1. Build and run your app on both Android and iOS devices or emulators
2. Check how the icon appears on the home screen, app drawer, and recent apps list
3. Verify that the icon looks good on different device models and screen densities

## Troubleshooting

- **Icons Not Updating**: Clear your build cache and rebuild
  ```
  flutter clean
  flutter pub get
  flutter run
  ```

- **Adaptive Icons Not Working**: Ensure your `minSdkVersion` is at least 26 in `android/app/build.gradle.kts`

- **iOS Icons Not Showing**: Verify that the `Contents.json` file correctly references your icon files

## Additional Resources

- [Flutter Launcher Icons Package](https://pub.dev/packages/flutter_launcher_icons): A package to simplify updating app icons
- [Icon Guidelines for App Stores](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)
- [Material Design Icons](https://material.io/resources/icons/)

---

By following this guide, you can replace the placeholder icons with your custom branded icons to give your Foodyah Delivery App a professional and distinctive appearance on both Android and iOS platforms.