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
| **Phase 1** | iOS MVP、手動L/R割り当て、100msバッファ | Complete |
| Phase 2 | UWB位置検出、自動チャンネル割り当て | Planned |
| **Phase 3** | Android対応、AudioTrack + MediaCodec | Complete |
| Phase 4 | 最適化、5.1ch対応、50ms以下遅延 | Planned |

## Requirements

- **iOS 15+** / **Android 13+** (API 33)
- macOS with Xcode 15+ (iOS開発)
- Android Studio / Android SDK (Android開発)
- [fvm](https://fvm.app/) - Flutter バージョン管理
- [CocoaPods](https://cocoapods.org/) - iOS依存関係管理
- [Devbox](https://www.jetify.com/devbox) - インフラ作業用（JDK17, Terraform, AWS CLI）
- Apple Developer Program（iOS実機テスト用）

## Quick Start

### 1. 開発環境のセットアップ

```bash
# fvmがない場合はインストール
dart pub global activate fvm

# CocoaPodsのインストール（iOS依存関係管理に必要）
brew install cocoapods

# Flutterバージョンをインストール
cd app
fvm install

# Devboxがない場合はインストール（Terraform作業用）
curl -fsSL https://get.jetify.com/devbox | bash
```

> **Note**: Flutter/iOS 開発は devbox shell を使わずに直接 fvm を使用してください。
> devbox shell は Nix の SDK が Xcode と競合するため、Terraform 作業時のみ使用します。

### 2. Flutter依存関係のインストール

```bash
cd app
fvm flutter pub get

# iOS依存関係のインストール
cd ios && pod install && cd ..
```

### 3. AWSインフラのデプロイ

```bash
# Terraform作業はdevbox shell内で実行
devbox shell
cd infrastructure/terraform
terraform init
terraform apply -var-file=environments/dev.tfvars
```

### 4. アプリ設定の更新

```bash
# devbox shell内で実行
terraform output api_gateway_url
terraform output flutter_amplify_config
```

取得した値で以下のファイルを更新:
- `app/lib/services/api_service.dart` - `_baseUrl`
- `app/lib/amplifyconfiguration.dart` - Cognito設定

### 5. アプリの実行

```bash
# devbox shellから抜ける（Flutter/iOSビルドはdevbox外で実行）
exit

cd app

# iOSシミュレータで実行
fvm flutter run

# 複数デバイスで同時実行（シミュレータ + 実機）
xcrun simctl boot "iPhone 15"
fvm flutter devices                    # デバイスID確認
fvm flutter run -d <device_id_1> -d <device_id_2>
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
| 5350 | UDP | 時刻同期 |
| 5354 | UDP Multicast | ホスト発見 |
| 5355 | UDP | オーディオストリーム |

## Commands

```bash
# Flutter (devbox shell外で実行)
cd app
fvm flutter pub get           # 依存関係インストール
fvm flutter run               # 実行
fvm flutter build ios         # iOSビルド
fvm flutter build apk         # Android APKビルド
fvm flutter analyze           # 静的解析
fvm flutter test              # テスト

# Terraform (devbox shell内で実行)
devbox shell
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
3. `fvm flutter run` で直接インストール

### TestFlight経由

1. `fvm flutter build ipa`
2. App Store Connectにアップロード
3. TestFlightで配布

## Troubleshooting

### Flutter環境の問題

```bash
fvm install
fvm flutter doctor
```

### Devbox環境の問題

```bash
devbox rm
devbox install
devbox shell
```

### ビルドエラー

```bash
cd app
fvm flutter clean
fvm flutter pub get
fvm flutter run
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
