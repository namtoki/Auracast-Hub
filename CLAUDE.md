# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Auracast Hub is a Flutter application (Android-first) that serves as an Auracast Assistant for Bluetooth LE Audio broadcast discovery and connection. The app uses Android's standard BLE API and BASS (Broadcast Audio Scan Service) GATT to scan for and connect to Auracast broadcasts without requiring vendor-specific SDKs.

## Development Environment

Uses Devbox for environment management:
```bash
devbox shell    # Enter dev environment (Flutter + JDK17)
```

## Common Commands

```bash
# Flutter commands (run from app/ directory)
cd app
flutter pub get           # Install dependencies
flutter run               # Run on connected device
flutter build apk         # Build APK
flutter analyze           # Run static analysis
flutter test              # Run tests

# Run single test
flutter test test/widget_test.dart

# Terraform commands (run from infrastructure/terraform/)
cd infrastructure/terraform
terraform init            # Initialize Terraform
terraform plan            # Preview changes
terraform apply           # Deploy infrastructure
terraform output          # Show output values
```

## Architecture

### Flutter Layer (`app/lib/`)
- **main.dart** - App entry point with Amplify configuration and auth state management
- **services/auracast_service.dart** - Platform channel wrapper for native BLE operations
- **services/auth_service.dart** - AWS Cognito authentication wrapper
- **screens/auth/** - Login, signup, email verification, password reset screens
- **screens/** - UI screens using StatefulWidget pattern
- **amplifyconfiguration.dart** - Amplify/Cognito configuration (update after Terraform deploy)

### AWS Infrastructure (`infrastructure/terraform/`)
- **cognito.tf** - Cognito User Pool, Identity Pool, IAM roles
- **provider.tf** - AWS provider configuration (ap-northeast-1)
- **variables.tf** - Configurable parameters
- **outputs.tf** - Values needed for Flutter app configuration

### Android Native Layer (`app/android/app/src/main/kotlin/com/auracast/auracast_hub/`)
- **AuracastPlugin.kt** - Flutter plugin handling Method/Event channels
- **bluetooth/AuracastScanner.kt** - BLE scanner using BluetoothLeScanner with Extended Advertising support
- **bluetooth/BluetoothUuids.kt** - Bluetooth SIG UUID constants for BAAS/BASS services

### Platform Channel Contract
- Method Channel: `com.auracast.auracast_hub/method`
  - `isLeAudioSupported` - Check Android 13+ LE Audio support
  - `isBluetoothEnabled` - Check Bluetooth adapter state
  - `stopScan` - Stop active BLE scan
- Event Channel: `com.auracast.auracast_hub/scan` - Stream of discovered broadcasts

## Key Technical Constraints

- **Minimum Android 13 (API 33)** required for LE Audio
- Scanner uses `setLegacy(false)` for Extended Advertising detection
- Filters on BAAS UUID (0x1852) to find Auracast broadcasts
- BASS GATT service (0x184F) on sink devices handles connection control

## Reference Documentation

The `request.md` file contains detailed technical specifications including:
- Bluetooth SIG Auracast/BASS protocol details
- GATT characteristic formats and opcodes
- Planned AWS backend architecture
- Full implementation design for BASS GATT manager (not yet implemented)
