# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HiFi Audio Platform** - オーディオ機器データベース＆価格比較プラットフォーム

HiFi オーディオ機器のデータベース、互換性チェック、価格比較を提供するWebプラットフォーム。
トリバゴ的なアプローチで、複数ショップの最安価格を一括表示する。

### Current Phase: Phase 1 MVP

- 機器データベース（スピーカー、アンプ、DAC等）
- 組み合わせ互換性チェック
- 基本検索機能
- Next.js + AWS サーバーレスアーキテクチャ

## Tech Stack

### Frontend
- **Next.js 14** (App Router) + TypeScript
- **Tailwind CSS** for styling
- **TanStack Query** for state management
- **CloudFront + S3** for hosting

### Backend
- **AWS Lambda** (Node.js)
- **API Gateway** (REST API)
- **Aurora PostgreSQL Serverless v2** for main database
- **DynamoDB** for sessions
- **OpenSearch** for search (Phase 2+)
- **Cognito** for authentication (Phase 3+)

### Infrastructure
- **Terraform** for IaC
- **GitHub Actions** for CI/CD

## Development Environment

### Prerequisites

```bash
# Node.js (v20+)
nvm install 20
nvm use 20

# pnpm
npm install -g pnpm

# AWS CLI
brew install awscli
aws configure

# Terraform
brew install terraform

# Docker (local DB)
brew install --cask docker
```

### Local Development

```bash
# Frontend
cd frontend
pnpm install
pnpm dev

# Backend (serverless offline)
cd backend
pnpm install
pnpm dev

# Local PostgreSQL
docker-compose up -d postgres
```

## Common Commands

```bash
# Frontend (run from frontend/ directory)
pnpm dev              # Start dev server
pnpm build            # Production build
pnpm lint             # Run ESLint
pnpm test             # Run tests

# Backend (run from backend/ directory)
pnpm dev              # Serverless offline
pnpm deploy           # Deploy to AWS
pnpm test             # Run tests

# Terraform (run from infrastructure/terraform/)
terraform init        # Initialize
terraform plan        # Preview changes
terraform apply       # Deploy infrastructure

# Database
docker-compose up -d postgres   # Start local DB
pnpm db:migrate                 # Run migrations
pnpm db:seed                    # Seed data
```

## Architecture

### Project Structure

```
/hifi-audio-platform
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
├── backend/                     # Lambda functions
│   ├── functions/
│   │   ├── equipment/           # Equipment CRUD
│   │   ├── price/               # Price crawler & API
│   │   ├── user/                # User management
│   │   └── shared/              # Common utilities
│   └── serverless.yml
│
├── infrastructure/              # Terraform
│   └── terraform/
│       ├── main.tf
│       ├── rds.tf
│       ├── lambda.tf
│       └── ...
│
└── scripts/                     # Utility scripts
```

### Database Schema (PostgreSQL)

Main tables:
- `categories` - Equipment categories (speaker, amplifier, dac, etc.)
- `brands` - Audio brands
- `equipment` - Equipment master with specs (JSONB)
- `compatibility` - Equipment compatibility scores
- `shops` - Online/physical shops
- `prices` - Price history (partitioned)
- `user_profiles` - User accounts (Cognito linked)
- `user_systems` - User equipment setups
- `reviews` - User reviews

### API Endpoints

```
# Equipment
GET    /api/equipment                 # List with filters
GET    /api/equipment/:slug           # Detail
GET    /api/equipment/:slug/prices    # Prices
GET    /api/equipment/:slug/compatibility

# Search
GET    /api/search                    # Full-text search
POST   /api/search/compatibility      # Compatibility search

# Prices
GET    /api/prices/lowest/:id         # Lowest price
GET    /api/prices/history/:id        # Price history

# Users (authenticated)
GET    /api/users/me
GET    /api/systems
POST   /api/reviews
```

## Development Phases

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 1** | MVP: Equipment DB, compatibility, basic search | In Progress |
| Phase 2 | Price comparison, crawlers, caching | Planned |
| Phase 3 | User accounts, reviews, my systems | Planned |
| Phase 4 | Shop/demo info, maps integration | Planned |
| Phase 5 | Articles/CMS, editorial workflow | Planned |

## Key Technical Details

### Equipment Specs (JSONB)

```typescript
// Speaker
{
  impedance_ohm: 8,
  sensitivity_db: 89,
  frequency_hz: [35, 40000],
  power_w_min: 30,
  power_w_max: 150
}

// Amplifier
{
  output_w_8ohm: 100,
  output_w_4ohm: 200,
  thd_percent: 0.05,
  input_types: ["RCA", "XLR"]
}
```

### Compatibility Calculation

Score 1-5 based on:
- Power matching (amp output vs speaker requirements)
- Impedance matching
- Source compatibility

### Price Crawling (Phase 2)

- EventBridge: Daily scheduled crawls
- SQS: Job queue management
- Targets: Amazon, Rakuten, Soundhouse, Yodobashi

## Reference Documentation

The `request.md` file contains detailed specifications:
- System architecture diagrams
- Complete database schema (SQL)
- API design and response examples
- Terraform configurations
- Cost estimates per phase
- Evaluation metrics

## Cost Estimates (Monthly)

| Phase | Cost |
|-------|------|
| Phase 1 MVP | ~$60-110 |
| Phase 2-3 | ~$185 |
| Production | ~$400-550 |
