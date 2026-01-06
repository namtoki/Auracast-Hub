# HiFi Audio Platform

オーディオ機器データベース＆価格比較プラットフォーム。HiFi オーディオ機器の互換性チェックと複数ショップの最安価格を一括表示します。

```
┌─────────────────────────────────────────────────────────────┐
│                    HiFi Audio Platform                       │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌──────────┐ │
│  │ 機器DB    │  │ 互換性    │  │ 価格比較  │  │ レビュー │ │
│  │ 検索      │  │ チェック  │  │ 最安表示  │  │ 投稿     │ │
│  └───────────┘  └───────────┘  └───────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
           ┌────────────────┼────────────────┐
           ▼                ▼                ▼
     ┌──────────┐     ┌──────────┐     ┌──────────┐
     │  Amazon  │     │  楽天    │     │サウンド  │
     │          │     │          │     │ハウス    │
     └──────────┘     └──────────┘     └──────────┘
```

## Features

- **機器データベース**: スピーカー、アンプ、DAC等のスペック検索
- **互換性チェック**: インピーダンス・出力マッチングによる相性診断
- **価格比較**: 複数ショップの最安値を自動収集・表示
- **レビュー**: ユーザーによる機器レビュー・マイシステム公開
- **店舗情報**: 実店舗での視聴可能機器・地図連携

## Development Phases

| Phase | 内容 | 状態 |
|-------|------|------|
| **Phase 1** | MVP: 機器DB、互換性チェック、基本検索 | In Progress |
| Phase 2 | 価格比較、クローラー、キャッシュ | Planned |
| Phase 3 | ユーザー機能、レビュー、マイシステム | Planned |
| Phase 4 | 店舗・視聴情報、地図連携 | Planned |
| Phase 5 | 記事CMS、編集ワークフロー | Planned |

## Tech Stack

### Frontend
- **Next.js 14** (App Router) + TypeScript
- **Tailwind CSS** for styling
- **TanStack Query** for data fetching

### Backend
- **Ruby on Rails 8.0** (API mode)
- **Ruby 3.3**
- **PostgreSQL** (Aurora Serverless v2)
- **ECS Fargate** for container hosting

### Infrastructure
- **CloudFront + S3** for frontend hosting
- **ALB** for API load balancing
- **ECR** for container registry
- **Cognito** for authentication (Phase 3+)
- **OpenSearch** for full-text search (Phase 2+)
- **Terraform** for IaC

## Requirements

- Node.js 20+
- pnpm
- Docker (Colima or Docker Desktop)
- AWS CLI (configured)
- Terraform 1.5+

## Quick Start

### 1. 開発環境のセットアップ

```bash
# Node.js (v20+)
nvm install 20
nvm use 20

# pnpm
npm install -g pnpm

# Docker (Colima推奨)
brew install colima
colima start

# AWS CLI
brew install awscli
aws configure

# Terraform
brew install terraform
```

### 2. ローカル開発

```bash
# リポジトリクローン
git clone https://github.com/namtoki/HiFiHi
cd HiFiHi

# 全サービス起動（PostgreSQL, Redis, Rails）
docker-compose up -d

# フロントエンド（別ターミナル）
cd frontend
pnpm install
pnpm dev
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:3001/api

### 3. データベースセットアップ

```bash
# マイグレーション実行
docker-compose exec backend rails db:migrate

# シードデータ投入
docker-compose exec backend rails db:seed
```

### 4. AWSインフラのデプロイ

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

## Project Structure

```
/HiFiHi
├── frontend/                    # Next.js application
│   ├── src/
│   │   ├── app/                 # App Router pages
│   │   ├── components/          # React components
│   │   ├── hooks/               # Custom hooks
│   │   ├── lib/                 # Utilities
│   │   ├── services/            # API clients
│   │   └── types/               # TypeScript types
│   └── package.json
│
├── backend/                     # Ruby on Rails API
│   ├── app/
│   │   ├── controllers/api/     # API controllers
│   │   ├── models/              # ActiveRecord models
│   │   └── serializers/         # JSON serializers
│   ├── config/
│   │   ├── routes.rb            # API routes
│   │   └── database.yml         # DB configuration
│   ├── db/
│   │   ├── migrate/             # Database migrations
│   │   └── seeds.rb             # Seed data
│   ├── Dockerfile               # Production container
│   └── Gemfile                  # Ruby dependencies
│
├── infrastructure/              # Terraform
│   └── terraform/
│       ├── main.tf              # Provider configuration
│       ├── vpc.tf               # VPC, subnets
│       ├── rds.tf               # Aurora PostgreSQL
│       ├── ecs.tf               # ECS Fargate
│       ├── ecr.tf               # Container registry
│       ├── alb.tf               # Load balancer
│       ├── s3.tf                # S3 buckets
│       ├── cloudfront.tf        # CDN
│       └── outputs.tf           # Output values
│
└── docker-compose.yml           # Local development
```

## Database Schema

主要テーブル (Phase 1):

| テーブル | 説明 |
|----------|------|
| `categories` | 機器カテゴリ（speaker, amplifier, dac等） |
| `brands` | オーディオブランド |
| `equipment` | 機器マスタ（スペックはJSONB） |
| `compatibilities` | 機器間の互換性スコア |

将来追加 (Phase 2+):

| テーブル | 説明 |
|----------|------|
| `shops` | オンライン/実店舗 |
| `prices` | 価格履歴 |
| `user_profiles` | ユーザーアカウント |
| `user_systems` | マイシステム |
| `reviews` | レビュー |

## API Endpoints

```
# Categories
GET    /api/categories              # カテゴリ一覧

# Brands
GET    /api/brands                  # ブランド一覧
GET    /api/brands/:slug            # ブランド詳細

# Equipment
GET    /api/equipment               # 機器一覧（フィルタ・ページネーション）
GET    /api/equipment/:slug         # 機器詳細
GET    /api/equipment/:slug/compatibility  # 互換性情報

# Search
GET    /api/search                  # 統合検索
```

## Commands

```bash
# Frontend (frontend/ ディレクトリで実行)
pnpm dev              # 開発サーバー起動 (localhost:3000)
pnpm build            # 本番ビルド
pnpm lint             # ESLint
pnpm test             # テスト

# Backend (Docker経由)
docker-compose up -d                          # 全サービス起動
docker-compose exec backend rails db:migrate  # マイグレーション
docker-compose exec backend rails db:seed     # シードデータ
docker-compose exec backend rails console     # Railsコンソール
docker-compose exec backend rspec             # テスト
docker-compose logs -f backend                # ログ確認

# Terraform (infrastructure/terraform/ ディレクトリで実行)
terraform init        # 初期化
terraform plan        # プレビュー
terraform apply       # デプロイ
```

## Cost Estimates (Monthly)

| Phase | コスト |
|-------|--------|
| Phase 1 MVP | ~$80-130 |
| Phase 2-3 | ~$200 |
| Production | ~$450-600 |

## Documentation

- **CLAUDE.md** - Claude Code向けの開発ガイド
- **request.md** - 詳細技術仕様（DB設計、API設計、Terraform設定）

## License

MIT License
