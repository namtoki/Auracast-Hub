# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SpatialSync** - 位置ベースチャンネル分離オーディオシステム

複数のスマートフォンを使用してサラウンドシステムを実現。各デバイスが L/R/Center チャンネルとして機能し、Snapcast方式のタイムスタンプ同期で ±5ms 以内の同期精度を目指す。

### Current Phase: Phase 1 MVP（iOS限定、手動割り当て）

- iOS デバイス間での同期再生
- 手動 L/R チャンネル割り当て
- 100ms バッファで安定動作
- AWS バックエンド（API Gateway + Lambda + DynamoDB）

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
flutter run               # Run on connected device/simulator
flutter build ios         # Build for iOS
flutter analyze           # Run static analysis
flutter test              # Run tests

# Run on multiple simulators
xcrun simctl boot "iPhone 15"
xcrun simctl boot "iPhone 15 Pro"
flutter run -d all

# Terraform commands (run from infrastructure/terraform/)
cd infrastructure/terraform
terraform init            # Initialize Terraform
terraform plan            # Preview changes
terraform apply           # Deploy infrastructure
terraform output          # Show output values (including API Gateway URL)
```

## Architecture

### Flutter Layer (`app/lib/`)

#### Core (`core/`)
- **audio/audio_engine.dart** - Platform channel wrapper for iOS AVAudioEngine
- **audio/audio_buffer.dart** - Jitter buffer for smooth playback
- **audio/channel_splitter.dart** - L/R channel separation
- **network/sync_protocol.dart** - Main sync coordinator
- **network/time_sync.dart** - NTP-style time synchronization
- **network/audio_streamer.dart** - UDP audio streaming
- **network/discovery_service.dart** - Multicast host discovery
- **network/audio_packet.dart** - Audio packet format (SSYN header)

#### Models (`models/`)
- **session.dart** - Session state and configuration
- **device_info.dart** - Device information
- **channel_assignment.dart** - L/R/Stereo channel assignment
- **user_settings.dart** - User preferences (synced to DynamoDB)
- **audio_channel.dart** - Channel type definitions

#### Services (`services/`)
- **auth_service.dart** - AWS Cognito authentication
- **api_service.dart** - AWS API Gateway client
- **settings_service.dart** - Local + cloud settings sync

#### Features (`features/`)
- **home/home_screen.dart** - Role selection (Host/Client)
- **host/host_screen.dart** - Audio source selection, playback control
- **client/client_screen.dart** - Sync status, channel display
- **setup/manual_assign_screen.dart** - L/R channel assignment UI

#### Auth (`screens/auth/`)
- Login, signup, email verification, password reset screens

### iOS Native Layer (`app/ios/Runner/`)
- **AppDelegate.swift** - Plugin registration
- **AudioEnginePlugin.swift** - AVAudioEngine for low-latency audio

### AWS Infrastructure (`infrastructure/terraform/`)
- **cognito.tf** - User Pool, Identity Pool, IAM roles
- **dynamodb.tf** - UserSettings, DeviceProfiles, Sessions tables
- **lambda.tf** - Settings, DeviceProfiles, Sessions Lambda functions
- **api_gateway.tf** - REST API with Cognito authorizer
- **lambda/** - Python Lambda function source code

### Platform Channel Contract

Audio Engine (`com.spatialsync.audio/`):
- Method Channel: `initialize`, `startCapture`, `stopCapture`, `startPlayback`, `stopPlayback`, `queueAudio`, `setChannelVolume`
- Event Channel: Audio frame events for streaming

## Key Technical Details

### Audio Packet Format
```
Magic(4B) | Version(1B) | SeqNum(4B) | PlayTime(8B) | ChMask(1B) | Len(2B) | Payload
"SSYN"      0x01          sequence     μs timestamp   0x03=stereo   size      Opus/PCM
```

### Time Sync Protocol
- NTP-style 4-timestamp exchange
- RTT = (T4 - T1) - (T3 - T2)
- Offset = ((T2 - T1) + (T3 - T4)) / 2
- Median filtering for outlier removal

### Network Ports
- Time Sync: UDP 5353
- Discovery: UDP 5354 (Multicast 239.255.255.250)
- Audio Stream: UDP 5355

## Development Phases

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 1** | iOS MVP, manual L/R assignment, 100ms buffer | In Progress |
| Phase 2 | UWB位置検出, 自動チャンネル割り当て | Planned |
| Phase 3 | Android対応, AudioPlaybackCapture | Planned |
| Phase 4 | 最適化, 5.1ch対応, 50ms以下遅延 | Planned |

## Reference Documentation

The `request.md` file contains detailed technical specifications:
- Snapcast-style synchronization algorithm
- Audio chunk format and time sync protocol
- AWS backend architecture diagrams
- DynamoDB table schemas
- Evaluation metrics for each phase
- Reference apps (Snapcast, SoundSeeder, AmpMe)

## Post-Deployment Steps

1. Run `terraform apply` to deploy AWS infrastructure
2. Get API Gateway URL from `terraform output api_gateway_url`
3. Update `app/lib/services/api_service.dart` with the URL
4. Update `app/lib/amplifyconfiguration.dart` with Cognito config
