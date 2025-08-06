# Foodyah Delivery App - App Store Deployment Guide

This document provides instructions for deploying the Foodyah Delivery App to the Apple App Store and Google Play Store.

## Prerequisites

1. Apple Developer Account ($99/year)
2. Google Play Developer Account ($25 one-time fee)
3. App Store Connect account (included with Apple Developer Account)
4. Xcode (latest version recommended)
5. Android Studio (latest version recommended)

## App Store Compliance Changes

The following changes have been made to ensure compliance with app store policies:

1. Updated package names and bundle identifiers to use proper domain-style format (`com.foodyah.delivery`)
2. Ensured all network connections use HTTPS for production environments
3. Added proper app name and icons
4. Included required privacy policy and terms of service links
5. Added proper permission request dialogs with clear explanations

## iOS App Store Deployment

### Preparing for Submission

1. Open the project in Xcode
2. Update the Bundle Identifier to match your Apple Developer Account
3. Configure App Store Connect with the app information
4. Create screenshots for all required device sizes
5. Prepare app privacy information for App Store Connect

### Building the App

```bash
flutter build ios --release
```

### Uploading to App Store Connect

1. Open the iOS folder in Xcode
2. Select a development team
3. Configure signing certificates
4. Use Xcode to archive and upload the app

## Google Play Store Deployment

### Preparing for Submission

1. Create a keystore file for signing the app
2. Configure the key.properties file
3. Prepare screenshots for all required device sizes
4. Prepare app privacy information for Google Play

### Building the App

```bash
flutter build appbundle --release
```

### Uploading to Google Play Console

1. Log in to the Google Play Console
2. Create a new app or select your existing app
3. Navigate to the Production track
4. Upload the AAB file
5. Complete the store listing information
6. Submit for review

## App Store Review Guidelines

### Apple App Store

- Ensure all permissions are properly explained
- Make sure background location usage is clearly justified
- Include a privacy policy and terms of service
- Ensure the app doesn't crash or have major bugs

### Google Play Store

- Comply with the Developer Program Policies
- Include proper permission explanations
- Provide a privacy policy
- Ensure the app meets quality guidelines

## Troubleshooting

### Common Issues

1. **Rejection due to missing privacy policy**: Ensure your privacy policy is accessible and covers all required information.
2. **Background location usage**: Make sure you clearly explain why the app needs background location.
3. **App crashes**: Test thoroughly on multiple devices before submission.
4. **Missing permissions**: Ensure all required permissions are properly declared and explained.

## Maintenance

- Regularly update the app to fix bugs and security issues
- Increment the version number for each update
- Keep the privacy policy and terms of service up to date
- Monitor user feedback and reviews