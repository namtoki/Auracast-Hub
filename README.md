# Auracast Hub

Bluetooth LE Audio (Auracast) ブロードキャストを検出・接続するための Flutter Android アプリケーション。

## 機能

- AWS Cognito によるユーザー認証（サインアップ、ログイン、パスワードリセット）
- Auracast ブロードキャストのスキャン・検出
- ブロードキャスト情報の表示（名前、ID、信号強度、暗号化状態）
- BASS (Broadcast Audio Scan Service) を使用した接続制御（開発中）

## 必要要件

- **Android 13 (API 33) 以上** - LE Audio サポートに必須
- LE Audio 対応の Bluetooth ハードウェア
- [Devbox](https://www.jetify.com/devbox) - 開発環境管理（Flutter SDK、JDK 17、Android SDK ツールを自動インストール）
- Terraform 1.0.0 以上（AWS インフラ構築用）
- AWS CLI（設定済み）

## 開発環境セットアップ

このプロジェクトは **Devbox** を使用して開発環境を管理しています。

```bash
# Devbox がインストールされていない場合
curl -fsSL https://get.jetify.com/devbox | bash

# 開発環境に入る（Flutter SDK、JDK 17 が自動でセットアップされます）
devbox shell
```

> **Note**: 以降のコマンドはすべて `devbox shell` 内で実行するか、`devbox run -- <コマンド>` 形式で実行してください。

## AWS インフラ構築

### 1. Terraform 設定

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集して設定
```

### 2. インフラデプロイ

```bash
terraform init
terraform plan
terraform apply
```

### 3. Flutter アプリへの設定反映

デプロイ後、出力値を取得して `app/lib/amplifyconfiguration.dart` を更新:

```bash
terraform output flutter_amplify_config
```

出力例:
```
{
  "identityPoolId" = "ap-northeast-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  "region" = "ap-northeast-1"
  "userPoolClientId" = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
  "userPoolId" = "ap-northeast-1_xxxxxxxxx"
}
```

この値を `amplifyconfiguration.dart` の該当箇所に設定してください。

## ビルド方法

### 依存関係のインストール

```bash
# devbox shell 内で実行
cd app
flutter pub get

# または devbox run を使用
devbox run -- bash -c "cd app && flutter pub get"
```

### 静的解析

```bash
cd app
flutter analyze
```

### テスト実行

```bash
cd app
# 全テスト実行
flutter test

# 特定のテスト実行
flutter test test/widget_test.dart
```

## APK 作成方法

### Debug APK

```bash
cd app
flutter build apk --debug
```

出力先: `app/build/app/outputs/flutter-apk/app-debug.apk`

### Release APK

```bash
cd app
flutter build apk --release
```

出力先: `app/build/app/outputs/flutter-apk/app-release.apk`

### Split APK（ABI別）

```bash
cd app
flutter build apk --split-per-abi
```

出力先:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (x86_64)

### App Bundle（Google Play 用）

```bash
cd app
flutter build appbundle
```

出力先: `app/build/app/outputs/bundle/release/app-release.aab`

## エミュレーター実行方法

### 1. エミュレーターの作成

Android Studio を使用:
1. Tools → Device Manager を開く
2. "Create Device" をクリック
3. デバイスを選択（Pixel 6 推奨）
4. システムイメージで **API 33 以上** を選択
5. "Finish" をクリック

コマンドラインを使用:
```bash
# 利用可能なシステムイメージを確認
sdkmanager --list | grep "system-images"

# システムイメージをダウンロード
sdkmanager "system-images;android-33;google_apis;x86_64"

# AVD を作成
avdmanager create avd -n Pixel6_API33 -k "system-images;android-33;google_apis;x86_64" -d "pixel_6"
```

### 2. エミュレーターの起動

```bash
# エミュレーター一覧を確認
flutter emulators

# エミュレーターを起動
flutter emulators --launch Pixel6_API33

# または直接起動
emulator -avd Pixel6_API33
```

### 3. アプリ実行

```bash
cd app
flutter run
```

> **注意**: エミュレーターでは実際の Bluetooth LE Audio 機能は動作しません。UI の確認のみ可能です。

## USB 接続デバイスでの実行方法

### 1. デバイスの準備

1. Android デバイスで **開発者向けオプション** を有効にする
   - 設定 → デバイス情報 → ビルド番号を7回タップ
2. **USB デバッグ** を有効にする
   - 設定 → 開発者向けオプション → USB デバッグ
3. USB ケーブルでPCに接続
4. デバイスに表示される「USB デバッグを許可しますか？」で「許可」を選択

### 2. 接続確認

```bash
# 接続デバイスを確認
flutter devices

# 出力例:
# RQ8M802XXXX (mobile) • RQ8M802XXXX • android-arm64 • Android 14 (API 34)
```

または adb で確認:
```bash
adb devices
```

### 3. アプリ実行

```bash
cd app

# デバイスが1台の場合
flutter run

# 複数デバイスがある場合、デバイスIDを指定
flutter run -d RQ8M802XXXX
```

### 4. リリースモードで実行

```bash
cd app
flutter run --release
```

### 5. ホットリロード / ホットリスタート

アプリ実行中:
- `r` キー: ホットリロード（状態を保持して再描画）
- `R` キー: ホットリスタート（アプリを再起動）
- `q` キー: 終了

## APK のインストール

### adb を使用

```bash
# Debug APK をインストール
adb install app/build/app/outputs/flutter-apk/app-debug.apk

# 既存アプリを上書きインストール
adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
```

### flutter install を使用

```bash
cd app
flutter install
```

## トラブルシューティング

### Devbox 環境の問題

```bash
# Devbox 環境を再構築
devbox rm
devbox install

# または shell に再入
exit
devbox shell
```

### デバイスが認識されない

```bash
# adb サーバーを再起動
adb kill-server
adb start-server
adb devices
```

### Bluetooth 権限エラー

アプリ初回起動時に Bluetooth 権限を許可してください:
- `BLUETOOTH_SCAN`
- `BLUETOOTH_CONNECT`

### LE Audio 非対応エラー

- Android 13 以上のデバイスを使用してください
- 一部のデバイスはハードウェアが LE Audio に対応していません

### ビルドエラー

```bash
cd app
flutter clean
flutter pub get
flutter run
```

## プロジェクト構成

```
Auracast-Hub/
├── app/                          # Flutter アプリケーション
│   ├── android/                  # Android ネイティブコード
│   │   └── app/src/main/kotlin/
│   │       └── com/auracast/auracast_hub/
│   │           ├── AuracastPlugin.kt      # Flutter プラグイン
│   │           ├── MainActivity.kt
│   │           └── bluetooth/
│   │               ├── AuracastScanner.kt # BLE スキャナー
│   │               └── BluetoothUuids.kt  # UUID 定数
│   ├── lib/                      # Dart コード
│   │   ├── main.dart             # アプリエントリーポイント
│   │   ├── amplifyconfiguration.dart  # Cognito 設定
│   │   ├── screens/
│   │   │   ├── auth/             # 認証画面
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── signup_screen.dart
│   │   │   │   ├── confirm_signup_screen.dart
│   │   │   │   └── reset_password_screen.dart
│   │   │   └── broadcast_list_screen.dart
│   │   └── services/
│   │       ├── auracast_service.dart  # BLE サービス
│   │       └── auth_service.dart      # 認証サービス
│   ├── test/
│   └── pubspec.yaml
├── infrastructure/               # AWS インフラ
│   ├── terraform/
│   │   ├── provider.tf           # AWS プロバイダー設定
│   │   ├── variables.tf          # 変数定義
│   │   ├── cognito.tf            # Cognito リソース
│   │   ├── outputs.tf            # 出力値
│   │   └── terraform.tfvars.example
│   └── README.md
├── devbox.json                   # Devbox 開発環境設定（Flutter, JDK 17, Android SDK Tools）
├── devbox.lock                   # Devbox 依存関係ロックファイル
├── request.md                    # 技術仕様書
├── CLAUDE.md                     # Claude Code 用ガイド
└── README.md
```

## ライセンス

MIT License
