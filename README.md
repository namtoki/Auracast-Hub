# SpatialSync

複数のスマートフォンを使用してチャンネル分離オーディオシステムを実現するFlutterアプリケーション。各デバイスがサラウンドシステムの1チャンネル（L/R/Center）として機能します。

```
        ┌─────────────┐
        │   ホスト    │
        │  スマホ     │
        │ (音源+制御) │
        └──────┬──────┘
               │ Wi-Fi
   ┌───────────┼───────────┐
   │           │           │
   ▼           ▼           ▼
┌─────┐     ┌─────┐     ┌─────┐
│  L  │     │  C  │     │  R  │
└─────┘     └─────┘     └─────┘
```

## Features

- **同期再生**: Snapcast方式のタイムスタンプ同期で ±5ms 以内の精度
- **チャンネル分離**: 各デバイスに L/R/Center/Stereo を割り当て
- **低遅延**: 100ms バッファで安定動作（Phase 1）
- **AWS連携**: Cognito認証、設定のクラウド同期

## Development Phases

| Phase | 内容 | 状態 |
|-------|------|------|
| **Phase 1** | iOS MVP、手動L/R割り当て、100msバッファ | In Progress |
| Phase 2 | UWB位置検出、自動チャンネル割り当て | Planned |
| Phase 3 | Android対応、AudioPlaybackCapture | Planned |
| Phase 4 | 最適化、5.1ch対応、50ms以下遅延 | Planned |

## Requirements

- **iOS 15+** (Phase 1)
- macOS with Xcode 15+
- [Devbox](https://www.jetify.com/devbox) - 開発環境管理
- Apple Developer Program（実機テスト用）

## Quick Start

### 1. 開発環境のセットアップ

```bash
# Devboxがない場合はインストール
curl -fsSL https://get.jetify.com/devbox | bash

# 開発環境に入る
devbox shell
```

### 2. Flutter依存関係のインストール

```bash
cd app
flutter pub get
```

### 3. AWSインフラのデプロイ

```bash
cd infrastructure/terraform
terraform init
terraform apply -var-file=environments/dev.tfvars
```

### 4. アプリ設定の更新

```bash
# API Gateway URLを取得
terraform output api_gateway_url

# Cognito設定を取得
terraform output flutter_amplify_config
```

取得した値で以下のファイルを更新:
- `app/lib/services/api_service.dart` - `_baseUrl`
- `app/lib/amplifyconfiguration.dart` - Cognito設定

### 5. アプリの実行

```bash
cd app

# iOSシミュレータで実行
flutter run

# 複数のシミュレータで同時実行
xcrun simctl boot "iPhone 15"
xcrun simctl boot "iPhone 15 Pro"
flutter run -d all
```

## Architecture

```
app/lib/
├── main.dart                    # エントリーポイント
├── core/
│   ├── audio/
│   │   ├── audio_engine.dart    # AVAudioEngine Platform Channel
│   │   ├── audio_buffer.dart    # ジッターバッファ
│   │   └── channel_splitter.dart
│   └── network/
│       ├── sync_protocol.dart   # 同期プロトコル統合
│       ├── time_sync.dart       # NTP風時刻同期
│       ├── audio_streamer.dart  # UDPストリーミング
│       └── discovery_service.dart
├── models/
│   ├── session.dart
│   ├── device_info.dart
│   └── channel_assignment.dart
├── services/
│   ├── auth_service.dart        # Cognito認証
│   ├── api_service.dart         # AWS API Gateway
│   └── settings_service.dart    # 設定管理
└── features/
    ├── home/                    # ホーム（役割選択）
    ├── host/                    # ホスト画面
    ├── client/                  # クライアント画面
    └── setup/                   # チャンネル割り当て

app/ios/Runner/
├── AppDelegate.swift
└── AudioEnginePlugin.swift      # AVAudioEngine実装

infrastructure/terraform/
├── cognito.tf                   # Cognito User Pool
├── dynamodb.tf                  # UserSettings, DeviceProfiles
├── lambda.tf                    # Settings CRUD
├── api_gateway.tf               # REST API
└── lambda/                      # Lambda関数ソース
```

## Technical Details

### 同期プロトコル

NTP風の4タイムスタンプ方式:
```
Client                    Host
  │── T1: Request ──────────►│
  │                          │
  │◄── T2,T3: Response ──────│
  │                          │
  T4: Received

RTT = (T4 - T1) - (T3 - T2)
Offset = ((T2 - T1) + (T3 - T4)) / 2
```

### オーディオパケット

```
Magic(4B) | Version(1B) | SeqNum(4B) | PlayTime(8B) | ChMask(1B) | Len(2B) | Payload
"SSYN"      0x01          sequence     μs timestamp   0x03=stereo   size      Audio
```

### ネットワークポート

| Port | Protocol | 用途 |
|------|----------|------|
| 5353 | UDP | 時刻同期 |
| 5354 | UDP Multicast | ホスト発見 |
| 5355 | UDP | オーディオストリーム |

## Commands

```bash
# Flutter
cd app
flutter pub get           # 依存関係インストール
flutter run               # 実行
flutter build ios         # iOSビルド
flutter analyze           # 静的解析
flutter test              # テスト

# Terraform
cd infrastructure/terraform
terraform init            # 初期化
terraform plan            # プレビュー
terraform apply           # デプロイ
terraform output          # 出力値表示
terraform destroy         # 削除
```

## iOS実機テスト

### Apple Developer Programに登録済みの場合

1. Xcodeでチーム設定
2. デバイスをMacに接続
3. `flutter run` で直接インストール

### TestFlight経由

1. `flutter build ipa`
2. App Store Connectにアップロード
3. TestFlightで配布

## Troubleshooting

### Flutter環境の問題

```bash
devbox rm
devbox install
devbox shell
```

### ビルドエラー

```bash
cd app
flutter clean
flutter pub get
flutter run
```

### CocoaPodsの問題

```bash
cd app/ios
pod deintegrate
pod install
```

## Documentation

- **CLAUDE.md** - Claude Code向けの開発ガイド
- **request.md** - 詳細技術仕様（同期アルゴリズム、AWS設計、評価指標）

## License

MIT License
