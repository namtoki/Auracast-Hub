# Auracast Hub Infrastructure

AWS インフラストラクチャを Terraform で管理します。

## 前提条件

- [Terraform](https://www.terraform.io/downloads) >= 1.0.0
- AWS CLI が設定済み
- 適切な AWS IAM 権限

## セットアップ

### 1. 設定ファイルの作成

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集して環境に合わせた設定を行う
```

### 2. Terraform の初期化

```bash
terraform init
```

### 3. 変更内容の確認

```bash
terraform plan
```

### 4. インフラのデプロイ

```bash
terraform apply
```

### 5. 出力値の確認

```bash
terraform output
```

## リソース

### Cognito

- **User Pool**: ユーザー認証・管理
- **User Pool Client**: モバイルアプリ用クライアント
- **Identity Pool**: AWS リソースアクセス用の一時認証情報
- **IAM Roles**: 認証済み/未認証ユーザー用のロール

## Flutter アプリへの設定

Terraform デプロイ後、以下のコマンドで設定値を取得:

```bash
terraform output flutter_amplify_config
```

取得した値を Flutter アプリの `lib/amplifyconfiguration.dart` に設定してください。

## 環境別デプロイ

```bash
# 開発環境
terraform workspace new dev
terraform apply -var="environment=dev"

# 本番環境
terraform workspace new prod
terraform apply -var="environment=prod"
```

## クリーンアップ

```bash
terraform destroy
```

**注意**: 本番環境では `deletion_protection` が有効になっています。
