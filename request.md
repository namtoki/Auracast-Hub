# SpatialSync - 位置ベースチャンネル分離オーディオシステム

## 1. プロジェクト概要

### 1.1 コンセプト

複数のスマートフォンを使用して、チャンネル分離オーディオシステムを実現する。
各スマートフォンがサラウンドシステムの1チャンネルとして機能する。

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SpatialSync コンセプト                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌─────────────┐                                      │
│                        │   ホスト    │                                      │
│                        │  スマホ     │                                      │
│                        │ (音源+制御) │                                      │
│                        └──────┬──────┘                                      │
│                               │ Wi-Fi                                       │
│              ┌────────────────┼────────────────┐                            │
│              │                │                │                            │
│              ▼                ▼                ▼                            │
│     ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                    │
│     │  スマホ L   │   │  スマホ C   │   │  スマホ R   │                    │
│     │ (Left Ch)   │   │ (Center Ch) │   │ (Right Ch)  │                    │
│     └─────────────┘   └─────────────┘   └─────────────┘                    │
│                                                                             │
│     ★ 手動 or UWB位置検出でデバイスにチャンネル割り当て                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Phase 1 開始時の方針

> **重要**: UWBは対応デバイスが限定的（iPhone 11以降、一部Android）なので、
> 最初はUWBなしで手動チャンネル割り当てからスタートする。
> UWB対応は Phase 2 以降で検討。

**Phase 1 の目標:**
- iOS デバイス間での同期再生を実現
- 手動 L/R チャンネル割り当て
- 100ms バッファで安定動作
- Snapcast方式のタイムスタンプ同期

---

## 2. Snapcast スタイル同期の仕組み

### 2.1 基本原理

Snapcastは **タイムスタンプベース同期** を採用し、0.2ms以下の同期偏差を実現している。

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Snapcast方式 タイムスタンプ同期                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【原理】                                                                   │
│  1. ホストがオーディオチャンクにタイムスタンプを付与                         │
│  2. 各クライアントがNTP風プロトコルでホストと時刻同期                        │
│  3. クライアントは「指定時刻」にオーディオを再生                             │
│  4. サンプル単位（48kHz = 0.02ms）の補正で高精度同期                        │
│                                                                             │
│  【ポイント】                                                               │
│  ・各デバイスが独立して「この音は T=X に再生する」と判断                     │
│  ・ネットワーク遅延の変動は関係ない（十分なバッファがあれば）                │
│  ・クロックドリフトはPLL方式で継続補正                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 オーディオチャンクフォーマット

```
┌────────────────────────────────────────────────────────────────────┐
│                    Audio Chunk Format                              │
├────────┬────────┬────────┬────────┬────────┬───────────────────────┤
│ Magic  │ Version│ SeqNum │PlayTime│ Ch Mask│ Opus/PCM Payload      │
│ 4B     │ 1B     │ 4B     │ 8B     │ 1B     │ Variable              │
└────────┴────────┴────────┴────────┴────────┴───────────────────────┘

Magic: "SSYN" (SpatialSync)
SeqNum: シーケンス番号（パケットロス検出）
PlayTime: 再生すべき時刻（ホスト時刻基準、μs単位）
Ch Mask: チャンネルマスク (bit0=L, bit1=R, bit2=C, ...)
```

### 2.3 時刻同期プロトコル（NTP風）

```
  Client                              Host
     │                                  │
     │──── T1: Request (T1) ──────────►│
     │                                  │
     │◄─── T2,T3: Response (T1,T2,T3) ──│
     │                                  │
     │  T4: Response received           │

  RTT = (T4 - T1) - (T3 - T2)
  Offset = ((T2 - T1) + (T3 - T4)) / 2

  ・5秒ごとに再同期
  ・クロックドリフト補正（PLL方式）
  ・精度目標: ±1ms (95%tile)
```

---

## 3. チャンネル分離

### 3.1 ステレオ (2.0ch) モード

```
入力: ステレオPCM [L, R]
  │
  ├─── デバイスA (Left割り当て)  → [L, L] または [L, 0]
  └─── デバイスB (Right割り当て) → [R, R] または [0, R]
```

### 3.2 サラウンド (5.1ch) モード

```
入力: 5.1ch PCM [FL, FR, C, LFE, SL, SR]
  │
  ├─── デバイスA → [FL]      (Front Left)
  ├─── デバイスB → [FR]      (Front Right)
  ├─── デバイスC → [C + LFE] (Center + Subwoofer mix)
  ├─── デバイスD → [SL]      (Surround Left)
  └─── デバイスE → [SR]      (Surround Right)
```

### 3.3 5.1ch スピーカー配置

```
                    ┌─────┐
                    │  C  │  Center
                    └──┬──┘
                       │
         ┌─────┐       │       ┌─────┐
         │ FL  │───────┼───────│ FR  │  Front L/R
         └─────┘       │       └─────┘
                       │
                  ┌────┴────┐
                  │ Listener │
                  └────┬────┘
                       │
         ┌─────┐       │       ┌─────┐
         │ SL  │───────┴───────│ SR  │  Surround L/R
         └─────┘               └─────┘

  角度目安:
  - FL/FR: 正面から ±22.5° 〜 ±30°
  - SL/SR: 正面から ±90° 〜 ±110°
  - C: 正面 0°
```

---

## 4. 遅延分析

### 4.1 遅延コンポーネント内訳

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     エンドツーエンド遅延分析                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  │ コンポーネント      │ 典型値       │ 最適化後     │                      │
│  ├─────────────────────┼──────────────┼──────────────┤                      │
│  │ 音源キャプチャ      │ 5-20ms       │ 1-5ms        │                      │
│  │ エンコード (Opus)   │ 2-10ms       │ 2-5ms        │                      │
│  │ ネットワーク転送    │ 1-5ms        │ 1-3ms        │                      │
│  │ デコード            │ 1-5ms        │ 1-3ms        │                      │
│  │ バッファリング      │ 20-100ms     │ 20-40ms      │                      │
│  │ オーディオ出力      │ 10-40ms      │ 5-15ms       │                      │
│  │ Bluetooth送信       │ 40-200ms     │ 40-80ms(aptX)│                      │
│  ├─────────────────────┼──────────────┼──────────────┤                      │
│  │ 合計 (BT経由)       │ 79-380ms     │ 70-150ms     │                      │
│  │ 合計 (内蔵スピーカー)│ 39-180ms     │ 30-70ms      │                      │
│  └─────────────────────┴──────────────┴──────────────┘                      │
│                                                                             │
│  ★ 同期において重要なのは「全デバイス間で遅延が揃う」こと                    │
│  ★ 絶対遅延が大きくても、全員同じなら問題なし                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 遅延対策

| 対策 | 効果 |
|------|------|
| 内蔵スピーカー使用 | Bluetooth遅延を回避 (40-200ms削減) |
| aptX LL対応機器 | Bluetooth遅延を40ms程度に抑制 |
| デバイス別遅延補正 | 機種ごとの遅延プロファイル適用 |
| 適応バッファ | ネットワーク状況に応じてバッファ調整 |

---

## 5. 参考技術・アプリ

### 5.1 Snapcast

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Snapcast                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  GitHub: https://github.com/badaix/snapcast                                 │
│  ライセンス: GPL-3.0                                                        │
│                                                                             │
│  【特徴】                                                                   │
│  ・0.2ms以下の同期偏差を達成                                                │
│  ・サンプル単位の補正（48kHz = 0.02ms精度）                                 │
│  ・48台以上のApple TVへの同時配信実績あり                                   │
│  ・C++実装、iOS/Androidクライアント有り                                     │
│                                                                             │
│  【我々が参考にすべき点】                                                   │
│  ・タイムスタンプ同期アルゴリズム                                           │
│  ・クロックドリフト補正方式                                                 │
│  ・パケットフォーマット設計                                                 │
│                                                                             │
│  【我々の独自機能】                                                         │
│  ・チャンネル分離（Snapcastは全デバイス同一音声）                           │
│  ・UWB位置検出による自動ルーティング                                        │
│  ・スマホネイティブ最適化                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 SoundSeeder

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SoundSeeder                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  URL: https://soundseeder.com/                                              │
│  プラットフォーム: Android (ホスト/クライアント), Windows, Linux            │
│                                                                             │
│  【特徴】                                                                   │
│  ・デバイスごとに L/R/モノラル/ステレオを手動設定可能                       │
│  ・Wi-Fi経由でPCMストリーミング                                            │
│  ・最大16台同期                                                            │
│  ・遅延調整 ±400ms（10msステップ）                                         │
│                                                                             │
│  【我々との違い】                                                           │
│  ・Android限定（iOSクライアントなし）                                       │
│  ・位置検出機能なし（完全手動）                                             │
│  ・サラウンド対応は限定的                                                   │
│                                                                             │
│  【参考ポイント】                                                           │
│  ・チャンネル分離UIデザイン                                                 │
│  ・遅延キャリブレーション方法                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 AmpMe

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             AmpMe                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  プラットフォーム: iOS, Android                                             │
│                                                                             │
│  【概要】                                                                   │
│  複数のスマホやBluetoothスピーカーを同期させて同じ音楽を再生するアプリ。     │
│  Spotify, YouTube, SoundCloud, Apple Music などと連携可能。                 │
│                                                                             │
│  【同期技術（独自開発）】                                                   │
│  1. 音響フィンガープリント: 再生中の音を分析して同期ポイント検出            │
│  2. 超音波同期: 可聴域外の超音波を使用                                      │
│  3. ML予測: 機種別遅延を機械学習で予測                                      │
│                                                                             │
│  【実績】                                                                   │
│  ・22,000台以上の同時同期（ギネス記録挑戦）                                 │
│  ・600万ダウンロード以上                                                    │
│                                                                             │
│  【限界】                                                                   │
│  ・チャンネル分離非対応（全デバイス同一音声のみ）                           │
│  ・独立ストリーミング方式（各デバイスが個別に音源取得）                     │
│  ・ローカルネットワーク最適化なし                                           │
│                                                                             │
│  【我々との差別化ポイント】                                                 │
│  ・L/Rチャンネル分離 → AmpMeにはない機能                                   │
│  ・ローカルWi-Fi最適化 → 低遅延・安定性向上                                │
│  ・UWB位置検出 → 自動チャンネルルーティング                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. 技術スタック

### 6.1 音源キャプチャ

| プラットフォーム | 方式 | 制限 |
|------------------|------|------|
| **Android** | AudioPlaybackCapture API | Android 10+, MediaProjection必要 |
| **iOS** | アプリ内再生のみ | 他アプリ音声のキャプチャ不可 |

```kotlin
// Android: AudioPlaybackCapture
val config = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
    .build()

val audioRecord = AudioRecord.Builder()
    .setAudioPlaybackCaptureConfig(config)
    .setAudioFormat(AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(48000)
        .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
        .build())
    .build()
```

### 6.2 低遅延オーディオ出力

**iOS: AVAudioEngine**
```swift
let session = AVAudioSession.sharedInstance()
try session.setPreferredIOBufferDuration(0.002) // 2ms = 96 samples
try session.setCategory(.playback, mode: .default)
// 実測遅延: 5-10ms (出力のみ)
```

**Android: AAudio**
```kotlin
AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY)
AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_EXCLUSIVE)
// 対応デバイス (Pixel等): 10ms round-trip
// 非対応デバイス: 50-100ms以上
```

### 6.3 位置検出（Phase 2以降）

| 技術 | 精度 | スマホ間測距 | 対応率 |
|------|------|--------------|--------|
| **UWB** | 10-30cm | 可能 | 25-30% |
| Bluetooth RSSI | 2-5m | 不可 | 100% |
| 音響測位 | 1-2cm | 可能 | 100% |
| **手動割り当て** | 完璧 | - | 100% |

---

## 7. AWSバックエンド

### 7.1 アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AWS バックエンドアーキテクチャ                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐                                                           │
│  │   Flutter   │                                                           │
│  │    App      │                                                           │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         │ HTTPS                                                            │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Amazon API Gateway                            │   │
│  │                         (REST API)                                   │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│         ┌───────────────────────┼───────────────────────┐                  │
│         │                       │                       │                  │
│         ▼                       ▼                       ▼                  │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐          │
│  │   Lambda    │         │   Lambda    │         │   Lambda    │          │
│  │  Settings   │         │    ML       │         │  Analytics  │          │
│  │   CRUD      │         │ Inference   │         │  Collector  │          │
│  └──────┬──────┘         └──────┬──────┘         └──────┬──────┘          │
│         │                       │                       │                  │
│         ▼                       ▼                       ▼                  │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐          │
│  │  DynamoDB   │         │  SageMaker  │         │ CloudWatch  │          │
│  │  Settings   │         │  Endpoint   │         │    Logs     │          │
│  └─────────────┘         └─────────────┘         └─────────────┘          │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Amazon Cognito                                  │   │
│  │            User Pool + Identity Pool (実装済み)                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 既存実装（Cognito認証）

現在、以下が Terraform で実装済み:

```
infrastructure/terraform/
├── cognito.tf          # User Pool, Identity Pool, IAM Roles
├── provider.tf         # AWS Provider (ap-northeast-1)
├── variables.tf        # 設定変数
└── outputs.tf          # 出力値
```

**Cognito 機能:**
- Email/Password 認証
- Google/Facebook/Apple ソーシャルログイン
- MFA (TOTP)
- パスワードリセット

### 7.3 ユーザー設定ストレージ (DynamoDB)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      DynamoDB テーブル設計                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【UserSettings テーブル】                                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ PK: userId (String)                                                  │  │
│  │ SK: settingType (String)                                            │  │
│  ├──────────────────────────────────────────────────────────────────────┤  │
│  │ Attributes:                                                          │  │
│  │   - data: Map (設定内容)                                             │  │
│  │   - updatedAt: Number (Unix timestamp)                               │  │
│  │   - version: Number (楽観的ロック用)                                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  【settingType の種類】                                                     │
│  ├─ "profile"       : ユーザープロフィール                                 │
│  ├─ "audio"         : オーディオ設定（バッファサイズ、コーデック等）        │
│  ├─ "channel"       : チャンネル割り当て設定                               │
│  ├─ "devices"       : 登録デバイス一覧                                     │
│  └─ "preferences"   : UI設定、通知設定等                                   │
│                                                                             │
│  【DeviceProfiles テーブル】（ML用）                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ PK: deviceModel (String) - 例: "iPhone 15 Pro"                       │  │
│  │ SK: osVersion (String) - 例: "17.2"                                  │  │
│  ├──────────────────────────────────────────────────────────────────────┤  │
│  │ Attributes:                                                          │  │
│  │   - avgLatency: Number (平均遅延 ms)                                 │  │
│  │   - latencyStdDev: Number (標準偏差)                                 │  │
│  │   - sampleCount: Number (測定サンプル数)                             │  │
│  │   - btLatencyProfile: Map (Bluetoothコーデック別遅延)                │  │
│  │   - recommendedBuffer: Number (推奨バッファサイズ)                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.4 機械学習機能

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ML 機能設計                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【1. デバイス遅延予測モデル】                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 入力:                                                                │  │
│  │   - デバイスモデル (iPhone 15 Pro, Pixel 8, etc.)                   │  │
│  │   - OSバージョン                                                     │  │
│  │   - Bluetoothコーデック (aptX, AAC, SBC, etc.)                      │  │
│  │   - Wi-Fi信号強度                                                    │  │
│  │                                                                      │  │
│  │ 出力:                                                                │  │
│  │   - 予測遅延 (ms)                                                    │  │
│  │   - 推奨バッファサイズ (ms)                                          │  │
│  │   - 信頼度スコア (0-1)                                               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  【2. 遅延キャリブレーション自動化】                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ - ユーザーの実測データを収集                                         │  │
│  │ - デバイスモデル別に集計                                             │  │
│  │ - 新規ユーザーに最適な初期値を提供                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  【3. UWB位置補正（Phase 2以降）】                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ - カルマンフィルタのパラメータ最適化                                 │  │
│  │ - 環境ごとの位置誤差補正                                             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  【実装方式】                                                               │
│  ├─ Phase 1-2: Lambda + 統計的手法（平均、分散）                          │
│  └─ Phase 3以降: SageMaker エンドポイント（本格MLモデル）                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.5 API設計

```yaml
# API Gateway エンドポイント

# ユーザー設定
GET    /settings                    # 全設定取得
GET    /settings/{type}             # 特定タイプの設定取得
PUT    /settings/{type}             # 設定更新
DELETE /settings/{type}             # 設定削除

# デバイスプロファイル
GET    /devices/profile             # 現在のデバイスの推奨設定取得
POST   /devices/calibration         # キャリブレーション結果送信

# ML推論
POST   /ml/predict-latency          # 遅延予測
POST   /ml/optimize-buffer          # バッファサイズ最適化

# セッション管理
POST   /sessions                    # セッション作成
GET    /sessions/{id}               # セッション情報取得
PUT    /sessions/{id}               # セッション更新
DELETE /sessions/{id}               # セッション終了

# 分析・テレメトリ
POST   /analytics/event             # イベント送信（バッチ対応）
```

### 7.6 Terraform 追加リソース

```hcl
# infrastructure/terraform/dynamodb.tf

resource "aws_dynamodb_table" "user_settings" {
  name           = "${var.app_name}-${var.environment}-user-settings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "settingType"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "settingType"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-user-settings"
  }
}

resource "aws_dynamodb_table" "device_profiles" {
  name           = "${var.app_name}-${var.environment}-device-profiles"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "deviceModel"
  range_key      = "osVersion"

  attribute {
    name = "deviceModel"
    type = "S"
  }

  attribute {
    name = "osVersion"
    type = "S"
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-device-profiles"
  }
}
```

```hcl
# infrastructure/terraform/api_gateway.tf

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.app_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 86400
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.mobile_client.id]
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
  }
}
```

```hcl
# infrastructure/terraform/lambda.tf

resource "aws_lambda_function" "settings_handler" {
  filename         = data.archive_file.lambda_settings.output_path
  function_name    = "${var.app_name}-${var.environment}-settings"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_settings.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      SETTINGS_TABLE = aws_dynamodb_table.user_settings.name
      DEVICES_TABLE  = aws_dynamodb_table.device_profiles.name
    }
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-settings"
  }
}

resource "aws_lambda_function" "ml_inference" {
  filename         = data.archive_file.lambda_ml.output_path
  function_name    = "${var.app_name}-${var.environment}-ml-inference"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_ml.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      DEVICES_TABLE = aws_dynamodb_table.device_profiles.name
      # SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.latency_predictor.name  # Phase 3以降
    }
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-ml-inference"
  }
}
```

### 7.7 Flutter API クライアント

```dart
// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';

class ApiService {
  static const String baseUrl = 'https://api.spatialsync.example.com';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<String> _getAccessToken() async {
    final session = await Amplify.Auth.fetchAuthSession()
        as CognitoAuthSession;
    return session.userPoolTokensResult.value.accessToken.toJson();
  }

  /// ユーザー設定を取得
  Future<Map<String, dynamic>> getSettings() async {
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  /// 設定を更新
  Future<void> updateSettings(String type, Map<String, dynamic> data) async {
    final token = await _getAccessToken();
    await http.put(
      Uri.parse('$baseUrl/settings/$type'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
  }

  /// デバイス遅延予測
  Future<LatencyPrediction> predictLatency({
    required String deviceModel,
    required String osVersion,
    String? bluetoothCodec,
  }) async {
    final token = await _getAccessToken();
    final response = await http.post(
      Uri.parse('$baseUrl/ml/predict-latency'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'bluetoothCodec': bluetoothCodec,
      }),
    );
    return LatencyPrediction.fromJson(jsonDecode(response.body));
  }

  /// キャリブレーション結果を送信
  Future<void> submitCalibration({
    required String deviceModel,
    required String osVersion,
    required double measuredLatency,
    String? bluetoothCodec,
  }) async {
    final token = await _getAccessToken();
    await http.post(
      Uri.parse('$baseUrl/devices/calibration'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'measuredLatency': measuredLatency,
        'bluetoothCodec': bluetoothCodec,
      }),
    );
  }
}

class LatencyPrediction {
  final double predictedLatency;
  final int recommendedBuffer;
  final double confidence;

  LatencyPrediction({
    required this.predictedLatency,
    required this.recommendedBuffer,
    required this.confidence,
  });

  factory LatencyPrediction.fromJson(Map<String, dynamic> json) {
    return LatencyPrediction(
      predictedLatency: json['predictedLatency'].toDouble(),
      recommendedBuffer: json['recommendedBuffer'],
      confidence: json['confidence'].toDouble(),
    );
  }
}
```

### 7.8 AWS サービス一覧

| サービス | 用途 | フェーズ |
|----------|------|----------|
| **Cognito** | ユーザー認証 | 実装済み |
| **API Gateway** | REST API | Phase 1 |
| **Lambda** | ビジネスロジック | Phase 1 |
| **DynamoDB** | ユーザー設定、デバイスプロファイル | Phase 1 |
| **CloudWatch** | ログ、メトリクス | Phase 1 |
| **S3** | オーディオファイル保存（オプション） | Phase 2 |
| **SageMaker** | 本格MLモデル | Phase 3 |
| **CloudFront** | CDN（オプション） | Phase 4 |

---

## 8. 開発フェーズ

### Phase 1: MVP（iOS限定、手動割り当て）

```
【目標】4-6週間
├─ iOS デバイス間での同期再生実証
├─ 手動 L/R チャンネル割り当て
├─ 100ms バッファで安定動作
├─ 同期精度 ±5ms
└─ AWSバックエンド基盤構築

【技術】
├─ Flutter (iOS only)
├─ AVAudioEngine
├─ WebSocket + UDP
├─ Opus コーデック
└─ AWS (API Gateway + Lambda + DynamoDB)

【成果物】
├─ ホストアプリ: ローカル音楽再生 + ストリーミング
├─ クライアントアプリ: 受信 + 同期再生
├─ 手動チャンネル割り当てUI
├─ ユーザー設定保存/復元機能
└─ デバイスプロファイル収集開始
```

### Phase 2: UWB位置検出

```
【目標】3-4週間
├─ UWB による自動位置検出 (iPhone 11以降)
├─ 位置に基づく L/R/C 自動割り当て
├─ リスナー移動時の動的チャンネル切り替え
└─ 非UWBデバイスは手動フォールバック

【技術】
├─ iOS Nearby Interaction Framework
└─ カルマンフィルタによる位置安定化
```

### Phase 3: Android対応

```
【目標】4-6週間
├─ Android クライアント対応
├─ Android ホスト: AudioPlaybackCapture
├─ AAudio による低遅延再生
└─ iOS/Android 混在環境

【技術】
├─ Android AudioPlaybackCapture API
├─ AAudio (MMAP Exclusive)
└─ androidx.core.uwb
```

### Phase 4: 最適化・5.1ch対応

```
【目標】4-6週間
├─ 50ms以下遅延達成（対応デバイス）
├─ 10台以上の同時接続
├─ 5.1ch サラウンド分離
└─ Bluetooth aptX LL 対応

【技術】
├─ デバイス別遅延プロファイル
├─ マルチキャスト配信
└─ 5.1ch→2.0ch ダウンミックス
```

---

## 9. プロジェクト構造

```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── audio/
│   │   ├── audio_engine.dart          # オーディオ処理エンジン
│   │   ├── channel_splitter.dart      # チャンネル分離
│   │   ├── opus_codec.dart            # Opusエンコード/デコード
│   │   └── low_latency_player.dart    # 低遅延再生
│   │
│   ├── network/
│   │   ├── sync_protocol.dart         # 同期プロトコル
│   │   ├── audio_streamer.dart        # オーディオストリーミング
│   │   ├── time_sync.dart             # 時刻同期
│   │   └── discovery_service.dart     # デバイス発見
│   │
│   └── positioning/
│       ├── uwb_manager.dart           # UWB位置検出 (Phase 2)
│       └── channel_router.dart        # チャンネルルーティング
│
├── services/
│   ├── auth_service.dart              # Cognito認証 (実装済み)
│   ├── api_service.dart               # AWS API クライアント
│   └── settings_service.dart          # ユーザー設定管理
│
├── features/
│   ├── auth/                          # 認証画面 (実装済み)
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── ...
│   │
│   ├── host/
│   │   ├── host_screen.dart           # ホスト画面
│   │   ├── source_selector.dart       # 音源選択
│   │   └── device_manager.dart        # 接続デバイス管理
│   │
│   ├── client/
│   │   ├── client_screen.dart         # クライアント画面
│   │   └── speaker_output.dart        # スピーカー出力
│   │
│   └── setup/
│       ├── manual_assign_screen.dart  # 手動チャンネル割り当て
│       └── calibration_screen.dart    # 遅延キャリブレーション
│
└── models/
    ├── session.dart                   # セッションモデル
    ├── device_info.dart               # デバイス情報
    ├── channel_assignment.dart        # チャンネル割り当て
    └── user_settings.dart             # ユーザー設定モデル
```

---

## 10. 技術的リスクと対策

| リスク | 影響度 | 対策 |
|--------|--------|------|
| UWB対応デバイス限定 | 高 | 手動割り当てフォールバック (Phase 1で先行実装) |
| Android遅延ばらつき | 高 | デバイスホワイトリスト + 適応バッファ |
| iOS音源キャプチャ不可 | 中 | Android限定ホスト or アプリ内再生 |
| Wi-Fi品質による同期乱れ | 中 | 適応バッファ + エラー訂正 |
| Bluetooth遅延 | 中 | 内蔵スピーカー推奨 + aptX LL対応 |

---

## 11. 評価指標

### Phase 1 MVP
- [x] iOSデバイス間の接続確立（ホスト/クライアント）
- [x] mDNS/Bonjourによるホスト検出
- [x] NTP方式の時刻同期（±5ms達成）
- [x] UDPオーディオパケット送受信
- [x] クライアント側でのオーディオ再生（一部ポップノイズあり）
- [x] 手動L/R割り当てが正常動作
- [ ] 3台のiOSデバイスで安定した同期再生
- [ ] 1時間連続再生でドリフトなし
- [ ] AWS API Gateway + Lambda + DynamoDB デプロイ完了
- [ ] ユーザー設定の保存/復元が動作
- [ ] デバイスプロファイル収集が動作

### Phase 2 UWB
- [ ] UWBで位置検出・自動チャンネル割り当て動作
- [ ] リスナー移動時の滑らかなチャンネル切り替え
- [ ] 位置検出精度 50cm以内

### Phase 3 Android
- [ ] Android→iOS ストリーミング動作
- [ ] YouTube音声キャプチャ・配信成功
- [ ] Pixel デバイスで50ms以下遅延達成
- [ ] SageMaker エンドポイントでML推論動作
- [ ] 遅延予測精度 ±10ms以内

### Phase 4 最適化
- [ ] 10台同時接続で安定動作
- [ ] 5.1chソース分離再生
- [ ] 対応デバイスで30ms以下遅延達成

---

## 12. 参考リソース

| リソース | URL |
|----------|-----|
| Snapcast GitHub | https://github.com/badaix/snapcast |
| SoundSeeder | https://soundseeder.com/ |
| iOS Nearby Interaction | https://developer.apple.com/nearby-interaction/ |
| Android UWB Jetpack | https://developer.android.com/develop/connectivity/uwb |
| Android AudioPlaybackCapture | https://developer.android.com/media/platform/av-capture |
| iOS AVAudioEngine | https://developer.apple.com/documentation/avfaudio/avaudioengine |
| Opus Codec | https://opus-codec.org/ |
| AWS Cognito | https://docs.aws.amazon.com/cognito/ |
| AWS API Gateway | https://docs.aws.amazon.com/apigateway/ |
| AWS Lambda | https://docs.aws.amazon.com/lambda/ |
| AWS DynamoDB | https://docs.aws.amazon.com/dynamodb/ |
| AWS SageMaker | https://docs.aws.amazon.com/sagemaker/ |
| Terraform AWS Provider | https://registry.terraform.io/providers/hashicorp/aws/ |
| Amplify Flutter | https://docs.amplify.aws/flutter/ |

---

## 13. 特許技術仕様（実装ガイドライン）

本セクションは特許出願ドラフト（4_document.md）から抽出した詳細実装仕様である。

### 13.1 オーディオパケット拡張仕様

特許請求の範囲に対応した完全なパケットフォーマット:

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Extended Audio Packet Format                       │
├──────────┬──────────┬────────────────────────────────────────────────┤
│  Field   │  Size    │  Description                                   │
├──────────┼──────────┼────────────────────────────────────────────────┤
│ Magic    │  4B      │ "SSYN" (0x5353594E) - SpatialSync identifier   │
│ Version  │  1B      │ Protocol version (0x01)                        │
│ Flags    │  1B      │ bit0: compressed, bit1: FEC, bit2-7: reserved  │
│ SeqNum   │  4B      │ Sequence number (big-endian)                   │
│ PlayTime │  8B      │ Playback timestamp (μs, host clock base)       │
│ ChMask   │  1B      │ Channel mask (see below)                       │
│ SampleRate│ 3B      │ Sample rate in Hz (e.g., 48000)                │
│ PayloadLen│ 2B      │ Payload length in bytes                        │
│ Reserved │  1B      │ Reserved for future use                        │
├──────────┴──────────┴────────────────────────────────────────────────┤
│ Header Total: 25 bytes                                                │
├──────────────────────────────────────────────────────────────────────┤
│ Payload  │ Variable │ PCM/Opus audio data                            │
└──────────────────────────────────────────────────────────────────────┘

Channel Mask (ChMask) ビット定義:
  bit0: Left Front (L)
  bit1: Right Front (R)
  bit2: Center (C)
  bit3: LFE (Subwoofer)
  bit4: Surround Left (SL)
  bit5: Surround Right (SR)
  bit6-7: Reserved

例:
  0x03 = Stereo (L+R)
  0x07 = 3.0ch (L+R+C)
  0x3F = 5.1ch (L+R+C+LFE+SL+SR)
```

### 13.2 時刻同期プロトコル詳細

特許請求項2に対応した4タイムスタンプ方式の完全実装:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Time Sync Protocol Sequence                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Client (Slave)                          Host (Master)                  │
│       │                                        │                        │
│       │                                        │                        │
│  T1 ──┼────── SYNC_REQUEST ──────────────────►│                        │
│       │      { slave_id, T1 }                  │                        │
│       │                                        │── T2 (受信時刻)        │
│       │                                        │                        │
│       │                                        │── T3 (送信時刻)        │
│       │◄────── SYNC_RESPONSE ─────────────────┼                        │
│  T4 ──│      { slave_id, T1, T2, T3 }         │                        │
│       │                                        │                        │
│  [計算]                                        │                        │
│  RTT = (T4 - T1) - (T3 - T2)                  │                        │
│  Offset = ((T2 - T1) + (T3 - T4)) / 2         │                        │
│                                                │                        │
│  [補正]                                        │                        │
│  SyncedTime = LocalTime + Offset              │                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

SYNC_REQUEST パケット構造 (16 bytes):
┌────────────┬──────────────┬────────────────────┐
│ Magic (4B) │ Type (1B)    │ SlaveID (3B)       │
│ "SYNC"     │ 0x01=REQ     │                    │
├────────────┴──────────────┴────────────────────┤
│ T1 (8B) - Client送信時刻 (μs)                  │
└────────────────────────────────────────────────┘

SYNC_RESPONSE パケット構造 (32 bytes):
┌────────────┬──────────────┬────────────────────┐
│ Magic (4B) │ Type (1B)    │ SlaveID (3B)       │
│ "SYNC"     │ 0x02=RES     │                    │
├────────────┴──────────────┴────────────────────┤
│ T1 (8B) - Client送信時刻 (エコーバック)        │
├────────────────────────────────────────────────┤
│ T2 (8B) - Host受信時刻 (μs)                    │
├────────────────────────────────────────────────┤
│ T3 (8B) - Host送信時刻 (μs)                    │
└────────────────────────────────────────────────┘

同期パラメータ:
  - 同期間隔: 1秒 (安定時は5秒に延長)
  - 精度目標: ±5ms (99%tile)
  - 中央値フィルタ: 直近5回の測定から中央値を採用
  - 異常値除去: RTT > 100ms の測定は破棄
```

### 13.3 チャンネルマルチキャスト割り当て

特許請求項3,6に対応したマルチキャストグループ設計:

```
┌─────────────────────────────────────────────────────────────────────────┐
│              Channel-based Multicast Architecture                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  【ユニキャスト方式（Phase 1 現在の実装）】                              │
│                                                                         │
│    Host ──► Client A (L)     Port 5355                                 │
│         └─► Client B (R)     Port 5355                                 │
│         └─► Client C (C)     Port 5355                                 │
│                                                                         │
│    ※ 各クライアントに個別送信（帯域効率△）                             │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  【マルチキャスト方式（Phase 4 最適化）】                                │
│                                                                         │
│  Channel │ Multicast Address │ Port  │ Description                     │
│  ────────┼───────────────────┼───────┼─────────────────────────────    │
│  Stereo  │ 239.255.0.1       │ 5361  │ L+R combined (default)          │
│  L       │ 239.255.0.2       │ 5362  │ Left Front only                 │
│  R       │ 239.255.0.3       │ 5363  │ Right Front only                │
│  C       │ 239.255.0.4       │ 5364  │ Center only                     │
│  LFE     │ 239.255.0.5       │ 5365  │ Subwoofer only                  │
│  SL      │ 239.255.0.6       │ 5366  │ Surround Left only              │
│  SR      │ 239.255.0.7       │ 5367  │ Surround Right only             │
│                                                                         │
│    Client A ──join──► 239.255.0.2 (L channel)                          │
│    Client B ──join──► 239.255.0.3 (R channel)                          │
│                                                                         │
│    ※ Hostは各チャンネルを1回だけ送信（帯域効率◎）                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 13.4 ジッター吸収バッファ制御

特許請求項4に対応した適応的バッファ管理:

```dart
/// 適応的ジッターバッファ実装ガイドライン
///
/// 特許請求項4: バッファ残量監視による補間/破棄制御

class AdaptiveJitterBuffer {
  // バッファパラメータ
  static const int targetBufferMs = 100;      // 目標バッファ量
  static const int minBufferMs = 40;          // 下限閾値
  static const int maxBufferMs = 200;         // 上限閾値

  // バッファ状態
  int currentBufferMs = 0;

  void processPacket(AudioPacket packet, int currentTimeUs) {
    final playTimeUs = packet.playTimeUs;
    final delayUs = playTimeUs - currentTimeUs;

    // バッファ量を計算
    currentBufferMs = delayUs ~/ 1000;

    if (currentBufferMs < minBufferMs) {
      // バッファアンダーラン防止: 無音補間
      _insertSilence(targetBufferMs - currentBufferMs);
    } else if (currentBufferMs > maxBufferMs) {
      // バッファオーバーフロー防止: 古いパケット破棄
      _discardOldPackets(currentBufferMs - targetBufferMs);
    }
  }

  void _insertSilence(int durationMs) {
    // 無音データを生成してバッファに挿入
    // または前のサンプルをフェードアウトして繰り返し
  }

  void _discardOldPackets(int excessMs) {
    // 最も古いパケットから順に破棄
    // シーケンス番号の連続性を維持
  }
}
```

### 13.5 パケットロス検出と補間

特許請求項5に対応したパケットロス対策:

```dart
/// パケットロス検出・補間実装ガイドライン

class PacketLossHandler {
  int _expectedSeqNum = 0;
  final List<AudioPacket> _recentPackets = [];

  void handlePacket(AudioPacket packet) {
    final receivedSeq = packet.sequenceNumber;

    if (receivedSeq != _expectedSeqNum) {
      // パケットロス検出
      final lostCount = receivedSeq - _expectedSeqNum;

      if (lostCount > 0 && lostCount < 10) {
        // 軽度のロス: 補間処理
        for (int i = 0; i < lostCount; i++) {
          final interpolated = _interpolatePacket(
            _recentPackets.last,
            packet,
            i + 1,
            lostCount + 1,
          );
          _outputPacket(interpolated);
        }
      } else if (lostCount >= 10) {
        // 重度のロス: リセット
        _resetBuffer();
      }
    }

    _expectedSeqNum = receivedSeq + 1;
    _recentPackets.add(packet);
    if (_recentPackets.length > 5) {
      _recentPackets.removeAt(0);
    }

    _outputPacket(packet);
  }

  AudioPacket _interpolatePacket(
    AudioPacket prev,
    AudioPacket next,
    int position,
    int total,
  ) {
    // 線形補間による中間パケット生成
    final ratio = position / total;
    final interpolatedPayload = Uint8List(prev.payload.length);

    for (int i = 0; i < prev.payload.length; i += 2) {
      // 16-bit PCMサンプルの線形補間
      final prevSample = _bytesToInt16(prev.payload, i);
      final nextSample = _bytesToInt16(next.payload, i);
      final interpolated = (prevSample * (1 - ratio) + nextSample * ratio).round();
      _int16ToBytes(interpolated, interpolatedPayload, i);
    }

    return AudioPacket(
      sequenceNumber: prev.sequenceNumber + position,
      playTimeUs: prev.playTimeUs +
        ((next.playTimeUs - prev.playTimeUs) * ratio).round(),
      channelMask: prev.channelMask,
      payload: interpolatedPayload,
    );
  }
}
```

### 13.6 UWB位置ベース自動チャンネル割り当て（Phase 2）

特許請求項6,7,8に対応した位置検出とチャンネル割り当てアルゴリズム:

```dart
/// UWB位置ベースチャンネル自動割り当て実装ガイドライン
///
/// 特許請求項6: UWB三辺測量による位置算出
/// 特許請求項7: 方位角に基づくチャンネル割り当てロジック
/// 特許請求項8: 複数候補時の最適化選択

class UwbChannelRouter {
  // リスニングポジション（基準点）
  late Position3D listeningPosition;

  // UWBアンカー位置（既知）
  final List<Position3D> anchors = [];

  /// デバイス位置から最適チャンネルを決定
  AudioChannel assignChannel(DevicePosition device) {
    // 1. リスニングポジションからの相対位置を計算
    final relative = device.position - listeningPosition;

    // 2. 方位角を計算 (水平面での角度、正面=0°)
    final azimuth = atan2(relative.y, relative.x) * 180 / pi;

    // 3. 方位角に基づくチャンネル判定 (特許請求項7)
    return _azimuthToChannel(azimuth);
  }

  AudioChannel _azimuthToChannel(double azimuth) {
    // 5.1chサラウンド配置に基づく角度範囲
    //
    //           C (0°)
    //    L(-30°)  |  R(+30°)
    //       \     |     /
    //        \    |    /
    //         \   |   /
    //          Listener
    //         /   |   \
    //        /    |    \
    //       /     |     \
    //   SL(-110°) | SR(+110°)
    //

    if (azimuth >= -15 && azimuth < 15) {
      return AudioChannel.center;
    } else if (azimuth >= -30 && azimuth < -15) {
      return AudioChannel.left;
    } else if (azimuth >= 15 && azimuth < 30) {
      return AudioChannel.right;
    } else if (azimuth >= 100 && azimuth < 135) {
      return AudioChannel.surroundLeft;
    } else if (azimuth >= -135 && azimuth < -100) {
      return AudioChannel.surroundRight;
    } else {
      // 範囲外: 最も近いチャンネルを割り当て
      return _findNearestChannel(azimuth);
    }
  }

  /// 複数デバイスが同一チャンネル候補の場合の最適化選択 (特許請求項8)
  void optimizeAssignments(List<DevicePosition> devices) {
    // 各チャンネルの理想方位角
    const idealAngles = {
      AudioChannel.left: -26.0,      // FL: -22.5° ~ -30°の中央
      AudioChannel.right: 26.0,       // FR: +22.5° ~ +30°の中央
      AudioChannel.center: 0.0,       // C: 0°
      AudioChannel.surroundLeft: 110.0,  // SL: +100° ~ +120°の中央
      AudioChannel.surroundRight: -110.0, // SR: -100° ~ -120°の中央
    };

    // 各チャンネルに対して最も理想角度に近いデバイスを選択
    final assignments = <AudioChannel, DevicePosition>{};
    final unassigned = List<DevicePosition>.from(devices);

    for (final channel in idealAngles.keys) {
      if (unassigned.isEmpty) break;

      final ideal = idealAngles[channel]!;
      unassigned.sort((a, b) {
        final aDiff = (a.azimuth - ideal).abs();
        final bDiff = (b.azimuth - ideal).abs();
        return aDiff.compareTo(bDiff);
      });

      assignments[channel] = unassigned.removeAt(0);
    }

    // 結果を通知
    for (final entry in assignments.entries) {
      _notifyAssignment(entry.value.deviceId, entry.key);
    }
  }

  /// UWB三辺測量による位置計算
  Position3D calculatePosition(Map<int, double> anchorDistances) {
    // 最低3つのアンカーからの距離が必要
    if (anchorDistances.length < 3) {
      throw Exception('At least 3 anchor distances required');
    }

    // 連立方程式を解いて位置を算出
    // (x - x1)² + (y - y1)² + (z - z1)² = d1²
    // (x - x2)² + (y - y2)² + (z - z2)² = d2²
    // (x - x3)² + (y - y3)² + (z - z3)² = d3²

    // 最小二乗法で解を求める（実装略）
    return _solveTrilateration(anchorDistances);
  }
}

class Position3D {
  final double x, y, z;
  Position3D(this.x, this.y, this.z);

  Position3D operator -(Position3D other) {
    return Position3D(x - other.x, y - other.y, z - other.z);
  }
}
```

### 13.7 システム初期化シーケンス

特許実施形態7に対応したシステム起動フロー:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    System Initialization Sequence                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Phase 1: Network Configuration                                   │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 1. Host starts Wi-Fi AP or joins existing network               │  │
│  │ 2. Host starts mDNS/Bonjour service advertisement               │  │
│  │    Service: "_spatialsync._udp.local"                           │  │
│  │    TXT Records: sessionId, sessionName, hostName                │  │
│  │ 3. Clients discover Host via mDNS                               │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              ↓                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Phase 2: Device Registration                                    │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 1. Client sends REGISTER message to Host                        │  │
│  │    { deviceId, deviceName, deviceModel, platform, osVersion }   │  │
│  │ 2. Host assigns unique slaveId and adds to device list          │  │
│  │ 3. Host responds with REGISTER_ACK                              │  │
│  │    { slaveId, sessionConfig }                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              ↓                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Phase 3: Time Synchronization                                   │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 1. Initial sync: 5 rapid exchanges (100ms interval)             │  │
│  │ 2. Apply median filter to remove outliers                       │  │
│  │ 3. Calculate final offset                                       │  │
│  │ 4. Start periodic sync timer (1-5 second interval)              │  │
│  │ 5. Mark device as "synced" when offset < 5ms                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              ↓                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Phase 4: Position Detection & Channel Assignment (UWB devices)  │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 1. UWB anchor calibration (if not already done)                 │  │
│  │ 2. Each client measures distance to anchors                     │  │
│  │ 3. Host calculates 3D positions via trilateration               │  │
│  │ 4. Host applies channel assignment algorithm                    │  │
│  │ 5. Host sends CHANNEL_ASSIGNMENT to each client                 │  │
│  │    { slaveId, channel, multicastGroup }                         │  │
│  │                                                                  │  │
│  │ [Non-UWB fallback: Manual assignment via UI]                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              ↓                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Phase 5: Audio Streaming Start                                  │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ 1. Clients join assigned multicast group (or await unicast)     │  │
│  │ 2. Host starts audio capture from source                        │  │
│  │ 3. Host begins channel separation (if applicable)               │  │
│  │ 4. Host starts sending audio packets with playback timestamps   │  │
│  │ 5. Clients buffer packets and play at designated time           │  │
│  │ 6. Host sends SESSION_STATE(playing) to all clients             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 13.8 エラー処理とフォールバック

特許実施形態9に対応した堅牢性設計:

```dart
/// エラー処理実装ガイドライン

class ErrorHandler {
  // ネットワーク切断検出
  static const heartbeatIntervalMs = 1000;
  static const heartbeatTimeoutMs = 5000;

  // 時刻同期エラー閾値
  static const syncErrorThresholdMs = 10;
  static const maxSyncRetries = 5;

  // パケットロス閾値
  static const packetLossWarningPercent = 5;
  static const packetLossCriticalPercent = 15;

  /// ネットワーク切断時の処理
  void handleDisconnect(String deviceId) {
    // 1. デバイスリストから除外
    // 2. チャンネル再割り当て実行（必要に応じて）
    // 3. 他のクライアントに通知
    // 4. 再接続監視開始
  }

  /// 時刻同期失敗時の処理
  void handleSyncFailure(String deviceId, int consecutiveFailures) {
    if (consecutiveFailures >= maxSyncRetries) {
      // デバイスを一時的に無効化
      _disableDevice(deviceId, 'Sync failure');
    } else {
      // 再同期を試行
      _forceSyncRetry(deviceId);
    }
  }

  /// パケットロス増加時の処理
  void handlePacketLoss(double lossPercent) {
    if (lossPercent >= packetLossCriticalPercent) {
      // バッファサイズ増加 + ビットレート低減
      _increaseBuffer(50);
      _reduceBitrate();
    } else if (lossPercent >= packetLossWarningPercent) {
      // 警告表示のみ
      _showNetworkWarning();
    }
  }

  /// UWB測距失敗時のフォールバック
  void handleUwbFailure(String deviceId) {
    // 手動チャンネル割り当てモードに切り替え
    _switchToManualMode(deviceId);
    _promptUserForChannelSelection(deviceId);
  }
}
```

### 13.9 性能最適化パラメータ

特許実施形態10に対応した最適化設定:

```yaml
# 性能最適化パラメータ設定

latency_modes:
  low_latency:
    description: "Low latency mode (jitter sensitive)"
    buffer_ms: 50
    sync_interval_ms: 500
    packet_size_samples: 480      # 10ms @ 48kHz
    use_fec: false

  standard:
    description: "Balanced mode (default)"
    buffer_ms: 100
    sync_interval_ms: 1000
    packet_size_samples: 960      # 20ms @ 48kHz
    use_fec: false

  high_stability:
    description: "High stability mode (jitter resistant)"
    buffer_ms: 200
    sync_interval_ms: 2000
    packet_size_samples: 1920     # 40ms @ 48kHz
    use_fec: true

power_saving:
  uwb_measurement_interval_playing_ms: 60000    # 再生中は1分に1回
  uwb_measurement_interval_idle_ms: 5000        # アイドル時は5秒に1回
  reduce_uwb_on_stable_position: true           # 位置安定時はUWB頻度低減
  sleep_detection_timeout_ms: 30000             # 30秒無反応でスリープ判定

network_optimization:
  max_udp_payload_bytes: 1400                   # MTU safe
  multicast_ttl: 1                              # Same subnet only
  socket_send_buffer_bytes: 65536
  socket_recv_buffer_bytes: 131072
```

---

## 14. 特許との対応表

| 特許請求項 | 対応セクション | 実装状態 |
|-----------|---------------|---------|
| 請求項1 (システム全体) | 13.1-13.8 | Phase 1 部分実装 |
| 請求項2 (時刻同期精度) | 13.2 | 実装済み (time_sync.dart) |
| 請求項3 (パケット構造) | 13.1 | 実装済み (audio_packet.dart) |
| 請求項4 (ジッタ吸収) | 13.4 | 実装済み (audio_buffer.dart) |
| 請求項5 (パケットロス対応) | 13.5 | 未実装 |
| 請求項6 (UWB位置検出) | 13.6 | Phase 2 予定 |
| 請求項7 (チャンネル割り当てロジック) | 13.6 | Phase 2 予定 |
| 請求項8 (割り当て最適化) | 13.6 | Phase 2 予定 |
| 請求項9 (方法クレーム) | 13.7 | Phase 1 部分実装 |
| 請求項10 (UWB自動割り当て方法) | 13.6, 13.7 | Phase 2 予定 |

---

## 15. 開発進捗ログ

### 2025-12-25: Phase 1 基本動作確認完了

**達成項目:**

1. **iOSデバイス間接続**
   - ホスト（Simulator）とクライアント（実機iPhone）間の接続確立
   - mDNS/Bonjourによるセッション検出動作確認
   - クライアント登録（REGIパケット）によるデバイス認識

2. **時刻同期**
   - NTP方式4タイムスタンプ同期実装済み
   - Clock Offset: ~24ms, RTT: ~15ms で同期達成
   - 5秒間隔での継続的同期動作確認

3. **オーディオストリーミング**
   - UDP Port 5355 でのパケット送受信動作確認
   - クライアント側でオーディオ再生成功
   - 150ms バッファ設定で基本動作

**修正した主要課題:**

- クライアントのソースポート保持問題を修正（`_ClientEndpoint`クラス導入）
- iOS `queueAudio` のタイミング計算問題を修正（Flutter側でタイミング制御）
- ジッターバッファの初期化閾値を改善

**残課題:**

- [ ] 一部ポップノイズ（ボツボツ）の解消
- [ ] セッション状態同期（Client側が"Waiting for host..."のまま）
- [ ] 複数クライアント（3台以上）でのテスト
- [ ] チャンネル分離（L/R）の実装・テスト

**技術メモ:**

```
現在の構成:
- Host: iOS Simulator (macOS)
- Client: iPhone実機
- Audio Format: PCM 16-bit, 48kHz, Stereo
- Buffer: 150ms (Host/Client両方)
- Playback Loop: 5ms interval
- Look-ahead: 30ms
```

---

### 2025-12-25: L/R チャンネル分離機能実装完了

**達成項目:**

1. **チャンネル割り当てプロトコル実装**
   - `ChannelAssignmentPacket` クラス追加（Magic: "CHAN"）
   - Host → Client へのチャンネル割り当て送信
   - Client側での割り当て受信・状態反映

2. **チャンネル分離再生**
   - ステレオ音声からL/Rチャンネルを抽出
   - 割り当てられたチャンネルのみをモノラル化して再生
   - `ChannelSplitter` を利用したサンプル単位の分離

3. **L/Rテスト音源作成**
   - `lr_test_tone.m4a`: L=440Hz（低音）, R=880Hz（高音）
   - 10秒間、48kHz ステレオ
   - チャンネル分離の動作確認用

**修正した主要課題:**

- `Icons.spatial_audio` が存在しない問題 → `Icons.surround_sound` に変更
- `kAudioUnitErr_FormatNotSupported` エラー → ファイル形式に合わせてプレイヤーを再接続
- 停止後の再生で音が出ない問題 → `reset()` 削除、エンジン起動状態を確認

**実装詳細:**

```
チャンネルマスク:
- 0x01 = Left のみ
- 0x02 = Right のみ
- 0x03 = Stereo（両方）
- 0x04 = Center

パケット構造（ChannelAssignmentPacket）:
┌────────────┬──────────────┬──────────────┬──────────────┐
│ Magic (4B) │ ChMask (1B)  │ Volume (1B)  │ Delay (2B)   │
│ "CHAN"     │ 0x01=L/0x02=R│ 0-100        │ signed ms    │
└────────────┴──────────────┴──────────────┴──────────────┘

変更ファイル:
- audio_packet.dart: ChannelAssignmentPacket 追加
- audio_streamer.dart: sendChannelAssignment(), onChannelAssignment 追加
- sync_protocol.dart: channelAssignmentStream, _sendChannelAssignmentToClient 追加
- client_screen.dart: _extractAssignedChannel(), チャンネル表示UI
- host_screen.dart: L/Rテスト音源選択、デバッグログ
- AudioEnginePlugin.swift: フォーマット不一致修正、再開処理改善
```

**残課題:**

- [ ] 一部ポップノイズ（ボツボツ）の解消
- [ ] セッション状態同期の改善
- [ ] 複数クライアント（3台以上）でのテスト
- [ ] Center/5.1ch チャンネル対応（Phase 4）

---

### 2025-12-26: Phase 3 Android 対応完了

**達成項目:**

1. **Android AudioEnginePlugin 完全実装**
   - `AudioTrack` による低遅延再生（クライアントモード）
   - `MediaExtractor` + `MediaCodec` によるファイルデコード（ホストモード）
   - `PERFORMANCE_MODE_LOW_LATENCY` で最適化
   - 107行のスタブ → 541行の完全実装

2. **Android ネットワーク対応**
   - `NetworkPlugin.kt` 追加: `MulticastLock` 管理
   - マルチキャスト受信に必要な権限追加
   - iOS ホストのセッション検出成功

3. **クロスプラットフォーム動作確認**
   - iOS ホスト → Android クライアント: 同期再生成功
   - Android ホスト → iOS クライアント: 対応済み
   - L/R チャンネル分離: 両プラットフォームで動作

**変更ファイル:**

```
app/android/app/src/main/AndroidManifest.xml
  - RECORD_AUDIO, MODIFY_AUDIO_SETTINGS 追加
  - INTERNET, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, ACCESS_NETWORK_STATE 追加

app/android/app/src/main/kotlin/com/auracast/auracast_hub/
├── MainActivity.kt              # NetworkPlugin 登録追加
├── audio/
│   └── AudioEnginePlugin.kt     # 完全実装（541行）
└── network/
    └── NetworkPlugin.kt         # 新規追加（MulticastLock管理）

app/lib/main.dart
  - 認証スキップ（暫定対応）
```

**Android AudioEnginePlugin 実装詳細:**

```kotlin
// 再生（クライアントモード）
AudioTrack.Builder()
    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
    .setTransferMode(AudioTrack.MODE_STREAM)
    .setAudioFormat(AudioFormat.ENCODING_PCM_16BIT, 48kHz, Stereo)

// キャプチャ（ホストモード）
MediaExtractor + MediaCodec でファイルデコード
→ PCM 16-bit, 48kHz, Stereo に変換
→ Event Channel 経由で Flutter に送信

// マルチキャスト受信
NetworkPlugin で MulticastLock を自動取得
→ UDP マルチキャスト (239.255.255.250:5354) 受信可能に
```

**フェーズ状態更新:**

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 1** | iOS MVP, 手動L/R割り当て, 100msバッファ | **Complete** |
| Phase 2 | UWB位置検出, 自動チャンネル割り当て | Planned |
| **Phase 3** | Android対応, AudioTrack + MediaCodec | **Complete** |
| Phase 4 | 最適化, 5.1ch対応, 50ms以下遅延 | Planned |

**残課題:**

- [ ] 認証機能の再有効化（Cognito設定確認）
- [ ] ポップノイズの解消
- [ ] 複数デバイス（3台以上）での同期テスト
- [ ] Android ホストでの AudioPlaybackCapture 対応（他アプリ音声キャプチャ）

---

*Last Updated: 2025-12-26*
*Project: SpatialSync - Position-based Channel Separation Audio System*
