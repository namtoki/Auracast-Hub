# HiFi Audio Platform - オーディオ機器データベース＆価格比較プラットフォーム

## 1. プロジェクト概要

### 1.1 コンセプト

HiFi オーディオ機器の **データベース**、**互換性チェック**、**価格比較** を提供するWebプラットフォーム。
トリバゴ的なアプローチで、複数ショップの最安価格を一括表示する。

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HiFi Audio Platform コンセプト                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         ユーザー                                     │   │
│  │    「このスピーカーに合うアンプは？」「最安値はどこ？」               │   │
│  └────────────────────────────┬────────────────────────────────────────┘   │
│                               │                                             │
│                               ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    HiFi Audio Platform                               │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐        │   │
│  │  │ 機器DB    │  │ 互換性    │  │ 価格比較  │  │ レビュー  │        │   │
│  │  │ 検索      │  │ チェック  │  │ 最安表示  │  │ 投稿      │        │   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                               │                                             │
│              ┌────────────────┼────────────────┐                           │
│              ▼                ▼                ▼                           │
│       ┌───────────┐    ┌───────────┐    ┌───────────┐                     │
│       │  Amazon   │    │  楽天     │    │ サウンド  │                     │
│       │           │    │           │    │ ハウス    │                     │
│       └───────────┘    └───────────┘    └───────────┘                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 主要機能

| 機能 | 説明 | Phase |
|------|------|-------|
| **機器データベース** | スピーカー、アンプ、DAC等のスペック・画像管理 | Phase 1 |
| **組み合わせ互換性** | インピーダンス、出力、感度等による相性チェック | Phase 1 |
| **価格比較** | 複数ショップの価格を自動収集・最安表示 | Phase 2 |
| **ユーザー機能** | アカウント、マイシステム、レビュー投稿 | Phase 3 |
| **店舗・視聴情報** | 実店舗での視聴可能機器、地図連携 | Phase 4 |
| **記事・CMS** | ライターによるレビュー記事、編集ワークフロー | Phase 5 |

---

## 2. システムアーキテクチャ

### 2.1 全体構成

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (React)                        │
│  - Next.js 14 (App Router, SSR/SEO対策) + TypeScript           │
│  - CloudFront + S3 でホスティング                               │
│  - Tailwind CSS                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API Layer (API Gateway)                    │
│  - REST API または GraphQL (AppSync)                            │
│  - Cognito Authorizer                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Services                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Lambda     │  │   Lambda     │  │   Lambda     │         │
│  │ (機器API)    │  │ (価格収集)   │  │ (ユーザ管理) │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Data Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  DynamoDB    │  │     RDS      │  │ OpenSearch   │         │
│  │ (セッション) │  │ (機器/価格)  │  │   (検索)     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 技術スタック詳細

| レイヤー | 技術 | 理由 |
|----------|------|------|
| Frontend | Next.js 14 + TypeScript | SEO必須、App Router |
| Styling | Tailwind CSS | 開発速度、レスポンシブ |
| State | Zustand or TanStack Query | 軽量、キャッシュ管理 |
| Backend | Node.js + Lambda | サーバーレス、コスト効率 |
| DB (メイン) | Aurora PostgreSQL Serverless v2 | リレーショナル、スケール |
| DB (セッション) | DynamoDB | 高速、セッション管理 |
| 検索 | OpenSearch | 機器検索、フィルタリング |
| 認証 | Cognito | AWS統合、ソーシャルログイン |
| IaC | Terraform | 再現性、CI/CD連携 |
| CDN | CloudFront | 静的配信、キャッシュ |
| 画像 | S3 + Lambda@Edge | 画像リサイズ |

---

## 3. データモデル

### 3.1 機器マスタ (PostgreSQL)

```sql
-- 機器カテゴリ
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,        -- 'speaker', 'amplifier', 'dac', 'headphone', etc.
    display_name VARCHAR(200) NOT NULL,
    parent_id UUID REFERENCES categories(id),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ブランド
CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    country VARCHAR(100),
    website_url VARCHAR(500),
    logo_url VARCHAR(500),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 機器マスタ
CREATE TABLE equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES categories(id) NOT NULL,
    brand_id UUID REFERENCES brands(id) NOT NULL,
    model VARCHAR(300) NOT NULL,
    slug VARCHAR(300) UNIQUE NOT NULL,
    release_year INT,
    msrp_jpy INT,                       -- 定価（税込）
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'discontinued', 'upcoming'

    -- 共通スペック (JSONB)
    specs JSONB NOT NULL DEFAULT '{}',
    -- スピーカー例: {"impedance_ohm": 8, "sensitivity_db": 89, "frequency_hz": [35, 40000], "power_w": 150}
    -- アンプ例: {"output_w_8ohm": 100, "output_w_4ohm": 200, "thd_percent": 0.05, "input_types": ["RCA", "XLR"]}
    -- DAC例: {"bit_depth": 32, "sample_rate_khz": 768, "dsd_support": true, "inputs": ["USB", "Coax", "Optical"]}

    -- 画像
    images JSONB DEFAULT '[]',          -- [{"url": "...", "type": "main"}, ...]

    -- メタデータ
    description TEXT,
    features TEXT[],

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(brand_id, model)
);

-- インデックス
CREATE INDEX idx_equipment_category ON equipment(category_id);
CREATE INDEX idx_equipment_brand ON equipment(brand_id);
CREATE INDEX idx_equipment_slug ON equipment(slug);
CREATE INDEX idx_equipment_specs ON equipment USING GIN(specs);
```

### 3.2 組み合わせ互換性

```sql
-- 組み合わせ互換性
CREATE TABLE compatibility (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_a_id UUID REFERENCES equipment(id) NOT NULL,
    equipment_b_id UUID REFERENCES equipment(id) NOT NULL,
    compatibility_score INT CHECK (compatibility_score BETWEEN 1 AND 5),

    -- 互換性の詳細
    compatibility_details JSONB DEFAULT '{}',
    -- 例: {"power_match": "good", "impedance_match": "excellent", "notes": "..."}

    source VARCHAR(50) NOT NULL,        -- 'official', 'user', 'article', 'calculated'
    source_url VARCHAR(500),

    -- ユーザー投稿の場合
    user_id UUID,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(equipment_a_id, equipment_b_id)
);

-- 自動計算による互換性ルール
CREATE TABLE compatibility_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    category_a_id UUID REFERENCES categories(id),
    category_b_id UUID REFERENCES categories(id),

    -- ルール定義 (JSONB)
    rule_definition JSONB NOT NULL,
    -- 例: {"type": "impedance_power", "amp_min_power_ratio": 1.5, "max_impedance_diff": 4}

    weight DECIMAL(3,2) DEFAULT 1.0,    -- スコア計算時の重み
    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 3.3 価格情報

```sql
-- ショップ
CREATE TABLE shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    website_url VARCHAR(500) NOT NULL,
    logo_url VARCHAR(500),
    shop_type VARCHAR(50) NOT NULL,     -- 'online', 'physical', 'both'
    affiliate_id VARCHAR(200),          -- アフィリエイトID
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 価格履歴
CREATE TABLE prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_id UUID REFERENCES equipment(id) NOT NULL,
    shop_id UUID REFERENCES shops(id) NOT NULL,
    price_jpy INT NOT NULL,
    price_jpy_with_shipping INT,        -- 送料込み価格
    stock_status VARCHAR(50),           -- 'in_stock', 'limited', 'out_of_stock', 'preorder'
    product_url VARCHAR(1000) NOT NULL,
    condition VARCHAR(50) DEFAULT 'new', -- 'new', 'used', 'refurbished'

    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- パーティショニング用
    fetched_date DATE DEFAULT CURRENT_DATE
) PARTITION BY RANGE (fetched_date);

-- 月別パーティション作成（自動化）
-- CREATE TABLE prices_2024_01 PARTITION OF prices FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- 最新価格ビュー
CREATE MATERIALIZED VIEW latest_prices AS
SELECT DISTINCT ON (equipment_id, shop_id)
    equipment_id,
    shop_id,
    price_jpy,
    price_jpy_with_shipping,
    stock_status,
    product_url,
    condition,
    fetched_at
FROM prices
ORDER BY equipment_id, shop_id, fetched_at DESC;

-- インデックス
CREATE INDEX idx_latest_prices_equipment ON latest_prices(equipment_id);
CREATE UNIQUE INDEX idx_latest_prices_unique ON latest_prices(equipment_id, shop_id);
```

### 3.4 ユーザー関連

```sql
-- ユーザープロファイル（Cognitoと連携）
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY,                 -- Cognito sub
    username VARCHAR(100) UNIQUE,
    display_name VARCHAR(200),
    avatar_url VARCHAR(500),
    bio TEXT,
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- マイシステム（ユーザーの機器構成）
CREATE TABLE user_systems (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT true,
    images JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- マイシステム構成機器
CREATE TABLE user_system_equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id UUID REFERENCES user_systems(id) ON DELETE CASCADE NOT NULL,
    equipment_id UUID REFERENCES equipment(id) NOT NULL,
    role VARCHAR(100),                   -- 'main_speaker', 'subwoofer', 'amp', etc.
    notes TEXT,
    sort_order INT DEFAULT 0,
    UNIQUE(system_id, equipment_id)
);

-- レビュー
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) NOT NULL,
    equipment_id UUID REFERENCES equipment(id) NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5) NOT NULL,
    title VARCHAR(300),
    content TEXT NOT NULL,
    pros TEXT[],
    cons TEXT[],

    -- 使用環境
    usage_context JSONB DEFAULT '{}',
    -- 例: {"room_size": "8畳", "music_genre": ["クラシック", "ジャズ"], "source": "ストリーミング"}

    is_verified_purchase BOOLEAN DEFAULT false,
    helpful_count INT DEFAULT 0,

    status VARCHAR(20) DEFAULT 'published', -- 'draft', 'published', 'hidden'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(user_id, equipment_id)
);
```

### 3.5 店舗・視聴情報

```sql
-- 実店舗
CREATE TABLE physical_shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES shops(id),   -- オンラインショップとの紐付け（任意）
    name VARCHAR(300) NOT NULL,
    address TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326),     -- PostGIS
    phone VARCHAR(50),
    business_hours JSONB,                -- {"mon": "10:00-20:00", ...}
    website_url VARCHAR(500),
    google_place_id VARCHAR(200),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 店舗展示機器（視聴可能）
CREATE TABLE shop_demos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    physical_shop_id UUID REFERENCES physical_shops(id) NOT NULL,
    equipment_id UUID REFERENCES equipment(id) NOT NULL,
    demo_status VARCHAR(50) NOT NULL,    -- 'available', 'by_appointment', 'display_only'
    notes TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID,                      -- 店舗スタッフ or ユーザー報告

    UNIQUE(physical_shop_id, equipment_id)
);

-- 空間インデックス
CREATE INDEX idx_physical_shops_location ON physical_shops USING GIST(location);
```

---

## 4. API設計

### 4.1 エンドポイント一覧

```yaml
# 機器
GET    /api/equipment                    # 機器一覧（フィルタ・ページネーション）
GET    /api/equipment/:slug              # 機器詳細
GET    /api/equipment/:slug/prices       # 機器の価格一覧
GET    /api/equipment/:slug/compatibility # 機器の互換性情報
GET    /api/equipment/:slug/reviews      # 機器のレビュー一覧

# カテゴリ・ブランド
GET    /api/categories                   # カテゴリ一覧
GET    /api/brands                       # ブランド一覧
GET    /api/brands/:slug                 # ブランド詳細（機器一覧含む）

# 検索
GET    /api/search                       # 統合検索（OpenSearch）
POST   /api/search/compatibility         # 互換性検索

# 価格
GET    /api/prices/lowest/:equipmentId   # 最安値取得
GET    /api/prices/history/:equipmentId  # 価格履歴

# ユーザー（認証必須）
GET    /api/users/me                     # 自分のプロファイル
PUT    /api/users/me                     # プロファイル更新
GET    /api/users/:username              # 公開プロファイル

# マイシステム
GET    /api/systems                      # 自分のシステム一覧
POST   /api/systems                      # システム作成
GET    /api/systems/:id                  # システム詳細
PUT    /api/systems/:id                  # システム更新
DELETE /api/systems/:id                  # システム削除

# レビュー
POST   /api/reviews                      # レビュー投稿
PUT    /api/reviews/:id                  # レビュー更新
DELETE /api/reviews/:id                  # レビュー削除
POST   /api/reviews/:id/helpful          # 参考になった

# 店舗
GET    /api/shops/nearby                 # 近くの店舗（位置情報）
GET    /api/shops/:id/demos              # 店舗の展示機器

# 管理（管理者のみ）
POST   /api/admin/equipment              # 機器登録
PUT    /api/admin/equipment/:id          # 機器更新
POST   /api/admin/crawl/trigger          # 価格クロール手動実行
```

### 4.2 レスポンス例

```json
// GET /api/equipment/dali-oberon-5
{
  "id": "uuid",
  "slug": "dali-oberon-5",
  "brand": {
    "id": "uuid",
    "name": "DALI",
    "slug": "dali",
    "country": "Denmark"
  },
  "category": {
    "id": "uuid",
    "name": "speaker",
    "displayName": "フロアスタンディングスピーカー"
  },
  "model": "OBERON 5",
  "releaseYear": 2018,
  "msrpJpy": 176000,
  "status": "active",
  "specs": {
    "type": "floorstanding",
    "impedanceOhm": 6,
    "sensitivityDb": 88,
    "frequencyHz": [39, 26000],
    "powerWMin": 30,
    "powerWMax": 150,
    "drivers": {
      "tweeter": "29mm soft dome",
      "woofer": "2x 5.25\" wood fiber"
    },
    "dimensions": {
      "heightMm": 830,
      "widthMm": 162,
      "depthMm": 283
    },
    "weightKg": 11.8
  },
  "images": [
    {"url": "https://cdn.../oberon5-main.jpg", "type": "main"},
    {"url": "https://cdn.../oberon5-side.jpg", "type": "side"}
  ],
  "description": "...",
  "features": ["SMC磁気システム", "Wood Fiber Cone"],
  "lowestPrice": {
    "priceJpy": 145000,
    "shop": {"name": "サウンドハウス", "slug": "soundhouse"},
    "stockStatus": "in_stock",
    "fetchedAt": "2024-01-15T10:00:00Z"
  },
  "averageRating": 4.5,
  "reviewCount": 23
}
```

---

## 5. 実装フェーズ

### Phase 1: MVP基盤（1-2ヶ月）

**目標**: 機器データベースと基本的な組み合わせ表示

```
/hifi-audio-platform
├── frontend/
│   ├── src/
│   │   ├── app/                  # Next.js App Router
│   │   │   ├── page.tsx          # トップページ
│   │   │   ├── speakers/         # スピーカー一覧
│   │   │   ├── amplifiers/       # アンプ一覧
│   │   │   ├── equipment/[slug]/ # 機器詳細
│   │   │   └── combinations/     # 組み合わせ検索
│   │   ├── components/
│   │   │   ├── equipment/        # 機器表示コンポーネント
│   │   │   ├── combination/      # 組み合わせ表示
│   │   │   └── common/           # 共通UI
│   │   ├── hooks/
│   │   ├── lib/                  # ユーティリティ
│   │   └── types/
│   ├── tailwind.config.js
│   └── package.json
│
├── backend/
│   ├── functions/
│   │   ├── equipment/            # 機器CRUD
│   │   ├── combination/          # 組み合わせロジック
│   │   ├── search/               # 検索
│   │   └── shared/               # 共通処理
│   └── serverless.yml            # or SAM template
│
└── infrastructure/
    └── terraform/
        ├── main.tf
        ├── rds.tf                # Aurora PostgreSQL
        ├── api_gateway.tf
        ├── lambda.tf
        ├── cloudfront.tf
        └── s3.tf
```

**成果物:**
- [ ] 機器一覧表示（カテゴリ別）
- [ ] 機器詳細ページ（スペック表示）
- [ ] 組み合わせ互換性表示
- [ ] 基本検索機能
- [ ] レスポンシブデザイン

---

### Phase 2: 価格比較機能（2-3ヶ月）

**目標**: トリバゴ的な最安価格提示

```
backend/
├── functions/
│   ├── price-crawler/
│   │   ├── amazon.ts
│   │   ├── rakuten.ts
│   │   ├── soundhouse.ts
│   │   ├── yodobashi.ts
│   │   └── scheduler.ts          # EventBridge連携
│   └── price-api/
│       └── handler.ts
```

**追加インフラ:**
- EventBridge: 定期クローリング（1日1-2回）
- SQS: クローリングジョブのキュー管理
- ElastiCache (Redis): 価格データキャッシュ

**成果物:**
- [ ] 複数ショップの価格表示
- [ ] 最安値ハイライト
- [ ] 価格履歴グラフ
- [ ] 在庫状況表示
- [ ] アフィリエイトリンク

---

### Phase 3: ユーザー機能（3-4ヶ月）

**目標**: ユーザー登録、組み合わせ投稿、レビュー

```
frontend/
├── src/
│   ├── app/
│   │   ├── auth/
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── mypage/
│   │   │   ├── systems/          # マイシステム管理
│   │   │   ├── reviews/          # 投稿レビュー
│   │   │   └── settings/         # アカウント設定
│   │   └── user/[username]/      # 公開プロフィール
```

**追加AWS:**
- Cognito: ユーザー認証（Email、Google、Apple）
- S3: ユーザー投稿画像
- Lambda@Edge: 画像リサイズ

**成果物:**
- [ ] ユーザー登録・ログイン
- [ ] マイシステム登録・公開
- [ ] レビュー投稿・編集
- [ ] ユーザープロフィールページ
- [ ] 「参考になった」機能

---

### Phase 4: 店舗・視聴情報（4-5ヶ月）

**目標**: 実店舗での視聴可能情報、地図連携

**追加機能:**
- Google Maps API連携
- 近くの店舗検索（PostGIS）
- 店舗展示機器データ
- 店舗オーナー向け管理画面

**成果物:**
- [ ] 店舗一覧・地図表示
- [ ] 「この機器を視聴できる店」検索
- [ ] 店舗詳細ページ
- [ ] 展示機器の登録・更新機能

---

### Phase 5: 記事・CMS（5-6ヶ月）

**目標**: ライター記事、編集ワークフロー

**選択肢:**
1. Headless CMS導入: Contentful / Strapi
2. 自前実装: 管理画面 + S3 + CloudFront

```
frontend/
├── src/
│   ├── app/
│   │   ├── articles/
│   │   │   ├── page.tsx          # 記事一覧
│   │   │   └── [slug]/           # 記事詳細
│   │   └── admin/
│   │       └── articles/         # 記事管理（ライター用）
```

**成果物:**
- [ ] 記事一覧・詳細表示
- [ ] 記事管理画面（WYSIWYG）
- [ ] ライター権限管理
- [ ] 記事内での機器リンク
- [ ] SEO最適化

---

## 6. インフラストラクチャ

### 6.1 Terraform構成

```hcl
# infrastructure/terraform/main.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "hifi-platform-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = "hifi-audio-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

### 6.2 Aurora PostgreSQL

```hcl
# infrastructure/terraform/rds.tf

resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.app_name}-${var.environment}"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "15.4"
  database_name          = "hifi_platform"
  master_username        = var.db_username
  master_password        = var.db_password

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  skip_final_snapshot    = var.environment != "prod"

  tags = {
    Name = "${var.app_name}-${var.environment}-cluster"
  }
}

resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.app_name}-${var.environment}-instance"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}
```

### 6.3 CloudFront + S3

```hcl
# infrastructure/terraform/cloudfront.tf

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.app_name}-${var.environment}-frontend"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  origin {
    domain_name = replace(aws_apigatewayv2_api.main.api_endpoint, "https://", "")
    origin_id   = "API"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-frontend"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "API"

    forwarded_values {
      query_string = true
      headers      = ["Authorization"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # または ACM証明書
    # acm_certificate_arn = aws_acm_certificate.main.arn
    # ssl_support_method  = "sni-only"
  }
}
```

---

## 7. コスト概算

### 7.1 Phase 1 MVP（月額）

| サービス | 概算 |
|----------|------|
| CloudFront + S3 | ~$5 |
| Lambda | ~$0 (Free tier) |
| Aurora Serverless v2 | ~$50-100 |
| API Gateway | ~$5 |
| **合計** | **~$60-110** |

### 7.2 Phase 2-3（月額）

| サービス | 概算 |
|----------|------|
| Phase 1 | ~$100 |
| ElastiCache | ~$30 |
| OpenSearch | ~$50 |
| Cognito | ~$0 (Free tier) |
| EventBridge + SQS | ~$5 |
| **合計** | **~$185** |

### 7.3 本番運用時（月額）

| サービス | 概算 |
|----------|------|
| CloudFront + S3 | ~$20 |
| Lambda | ~$20 |
| Aurora Serverless v2 | ~$150-300 |
| API Gateway | ~$30 |
| ElastiCache | ~$50 |
| OpenSearch | ~$100 |
| Cognito | ~$10 |
| その他 | ~$20 |
| **合計** | **~$400-550** |

---

## 8. プロジェクト構造

```
/hifi-audio-platform
├── frontend/                       # Next.js アプリケーション
│   ├── src/
│   │   ├── app/                    # App Router
│   │   ├── components/             # Reactコンポーネント
│   │   ├── hooks/                  # カスタムフック
│   │   ├── lib/                    # ユーティリティ
│   │   ├── services/               # API クライアント
│   │   └── types/                  # TypeScript型定義
│   ├── public/                     # 静的ファイル
│   ├── next.config.js
│   ├── tailwind.config.js
│   ├── tsconfig.json
│   └── package.json
│
├── backend/                        # Lambda関数
│   ├── functions/
│   │   ├── equipment/
│   │   │   ├── list.ts
│   │   │   ├── get.ts
│   │   │   └── admin.ts
│   │   ├── price/
│   │   │   ├── crawler/
│   │   │   └── api.ts
│   │   ├── user/
│   │   ├── review/
│   │   └── shared/
│   │       ├── db.ts               # DB接続
│   │       ├── auth.ts             # 認証ヘルパー
│   │       └── response.ts         # レスポンスヘルパー
│   ├── serverless.yml              # Serverless Framework
│   ├── tsconfig.json
│   └── package.json
│
├── infrastructure/                 # Terraform
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── vpc.tf
│       ├── rds.tf
│       ├── lambda.tf
│       ├── api_gateway.tf
│       ├── cloudfront.tf
│       ├── s3.tf
│       ├── cognito.tf
│       └── modules/
│
├── scripts/                        # ユーティリティスクリプト
│   ├── seed-data.ts                # 初期データ投入
│   ├── migrate.ts                  # DBマイグレーション
│   └── crawl-test.ts               # クローラーテスト
│
├── docs/                           # ドキュメント
│   ├── api.md
│   ├── database.md
│   └── deployment.md
│
├── .github/
│   └── workflows/
│       ├── frontend-deploy.yml
│       ├── backend-deploy.yml
│       └── terraform.yml
│
├── docker-compose.yml              # ローカル開発用
├── README.md
└── request.md                      # この仕様書
```

---

## 9. 開発環境セットアップ

### 9.1 必要なツール

```bash
# Node.js (v20+)
nvm install 20
nvm use 20

# pnpm (推奨)
npm install -g pnpm

# AWS CLI
brew install awscli
aws configure

# Terraform
brew install terraform

# Docker (ローカルDB用)
brew install --cask docker
```

### 9.2 ローカル開発

```bash
# リポジトリクローン
git clone https://github.com/xxx/hifi-audio-platform
cd hifi-audio-platform

# フロントエンド
cd frontend
pnpm install
pnpm dev

# バックエンド（別ターミナル）
cd backend
pnpm install
pnpm dev  # serverless offline

# ローカルDB
docker-compose up -d postgres
```

### 9.3 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: hifi_platform
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

---

## 10. 評価指標

### Phase 1 MVP
- [ ] 機器データ100件以上登録
- [ ] 機器一覧・詳細ページ表示
- [ ] 互換性スコア計算・表示
- [ ] 基本検索機能動作
- [ ] Lighthouse Performance 90+

### Phase 2 価格比較
- [ ] 3ショップ以上の価格収集
- [ ] 最安値表示機能
- [ ] 価格履歴グラフ表示
- [ ] クローラー自動実行（1日1回）

### Phase 3 ユーザー機能
- [ ] ユーザー登録・ログイン動作
- [ ] マイシステム登録・公開機能
- [ ] レビュー投稿・表示機能
- [ ] 画像アップロード機能

### Phase 4 店舗情報
- [ ] 店舗データ50件以上
- [ ] 地図表示・近隣検索
- [ ] 展示機器検索機能

### Phase 5 記事CMS
- [ ] 記事作成・編集・公開
- [ ] ライター権限管理
- [ ] 記事内機器リンク

---

## 11. 参考リソース

| リソース | URL |
|----------|-----|
| Next.js 14 | https://nextjs.org/docs |
| Tailwind CSS | https://tailwindcss.com/docs |
| TanStack Query | https://tanstack.com/query |
| AWS Serverless | https://docs.aws.amazon.com/serverless/ |
| Aurora Serverless v2 | https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html |
| Terraform AWS Provider | https://registry.terraform.io/providers/hashicorp/aws/ |
| OpenSearch | https://opensearch.org/docs/ |

---

*Last Updated: 2026-01-05*
*Project: HiFi Audio Platform - オーディオ機器データベース＆価格比較プラットフォーム*
