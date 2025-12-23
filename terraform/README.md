# Auracast Hub - Terraform Infrastructure

このディレクトリには、Auracast HubのAWSインフラストラクチャをTerraformで管理するためのコードが含まれています。

## アーキテクチャ概要

```
terraform/
├── main.tf                    # メインエントリポイント
├── variables.tf               # 変数定義
├── outputs.tf                 # 出力値定義
├── backend.tf                 # リモートステート設定
├── environments/              # 環境別設定
│   ├── dev/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
└── modules/                   # 再利用可能なモジュール
    ├── auth/                  # Cognito認証
    ├── database/              # DynamoDB
    ├── api/                   # API Gateway, Lambda
    ├── analytics/             # Personalize, OpenSearch, Kinesis
    ├── realtime/              # ElastiCache, WebSocket, AppSync
    └── location/              # Amazon Location Service
```

## 前提条件

- Terraform >= 1.6.0
- AWS CLI configured with appropriate credentials
- AWS アカウント (東京リージョン: ap-northeast-1)

## クイックスタート

### 1. 初期化

```bash
cd terraform
terraform init
```

### 2. 開発環境へのデプロイ

```bash
# プランの確認
terraform plan -var-file="environments/dev/terraform.tfvars"

# デプロイ
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### 3. 本番環境へのデプロイ

```bash
terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## モジュール詳細

### Auth Module (modules/auth/)

Cognito User Pool、Identity Pool、ソーシャルログイン設定を管理します。

**リソース:**
- `aws_cognito_user_pool` - ユーザープール
- `aws_cognito_user_pool_client` - アプリクライアント
- `aws_cognito_identity_pool` - IDプール
- `aws_cognito_identity_provider` - Google/Appleログイン

### Database Module (modules/database/)

DynamoDB Single-Table Design を管理します。

**リソース:**
- `aws_dynamodb_table.main` - メインテーブル (5 GSI)
- `aws_dynamodb_table.websocket_connections` - WebSocket接続管理
- `aws_dynamodb_table.personalize_interactions` - ML用インタラクションデータ

### API Module (modules/api/)

REST API Gateway と Lambda 関数を管理します。

**リソース:**
- `aws_api_gateway_rest_api` - REST API
- `aws_lambda_function` - 各種Lambda関数
- `aws_api_gateway_authorizer` - Cognito認証

### Analytics Module (modules/analytics/)

分析基盤を管理します。

**リソース:**
- `aws_kinesis_stream` - イベントストリーム
- `aws_opensearch_domain` - 検索エンジン
- `aws_cloudwatch_event_bus` - EventBridge
- `aws_s3_bucket` - データレイク

### Realtime Module (modules/realtime/)

リアルタイム機能を管理します。

**リソース:**
- `aws_elasticache_cluster` - Redis
- `aws_apigatewayv2_api` - WebSocket API
- `aws_appsync_graphql_api` - GraphQL API

### Location Module (modules/location/)

位置情報サービスを管理します。

**リソース:**
- `aws_location_place_index` - 逆ジオコーディング
- `aws_location_map` - 地図
- `aws_location_geofence_collection` - ジオフェンス
- `aws_location_tracker` - 位置追跡

## 環境変数

以下の環境変数を設定してOAuth認証を有効化できます:

```bash
export TF_VAR_google_client_id="your-google-client-id"
export TF_VAR_google_client_secret="your-google-client-secret"
export TF_VAR_apple_client_id="your-apple-client-id"
export TF_VAR_apple_team_id="your-apple-team-id"
export TF_VAR_apple_key_id="your-apple-key-id"
export TF_VAR_apple_private_key="-----BEGIN PRIVATE KEY-----..."
```

## リモートステート設定

本番運用では、S3バックエンドを使用することを推奨します:

1. `backend.tf` のコメントを解除
2. S3バケットとDynamoDBテーブルを作成
3. `terraform init` を再実行

## 出力値

デプロイ後、以下の出力値がFlutterアプリの設定に使用できます:

```bash
terraform output flutter_amplify_config
```

## 注意事項

- 本番環境では必ずリモートステートを使用してください
- Secrets Managerに保存された認証情報は手動でローテーションしてください
- OpenSearchのマスターパスワードはSecrets Managerに保存されます

## コスト見積もり

開発環境（概算月額）:
- Cognito: $0 (50,000 MAUまで無料)
- DynamoDB: $1-5 (オンデマンド)
- API Gateway: $3.50/百万リクエスト
- Lambda: $0.20/百万リクエスト
- ElastiCache: ~$15 (cache.t3.micro)
- OpenSearch: ~$25 (t3.small.search)
- Location Service: 使用量に応じて

## ライセンス

Proprietary - All rights reserved
