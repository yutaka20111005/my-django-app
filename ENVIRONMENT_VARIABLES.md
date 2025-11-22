# 環境変数の設定方法

このドキュメントでは、本番環境でSECRET_KEYなどの環境変数を設定する方法を説明します。

## 🔐 SECRET_KEYの生成

まず、安全なSECRET_KEYを生成します：

```bash
# Pythonを使ってランダムなSECRET_KEYを生成
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

または、以下のコマンドでも生成できます：

```bash
python manage.py shell -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

## 📝 設定方法

### 1. Dockerコンテナ実行時（ローカル/開発環境）

#### docker runコマンドで実行する場合：

```bash
docker run -e SECRET_KEY='your-generated-secret-key-here' \
           -e DEBUG='False' \
           -e ALLOWED_HOSTS='your-domain.com,www.your-domain.com' \
           -p 8000:8000 \
           your-ecr-registry/my-django-app:latest
```

#### docker-compose.ymlを使用する場合：

```yaml
version: '3.8'

services:
  web:
    image: your-ecr-registry/my-django-app:latest
    ports:
      - "8000:8000"
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DEBUG=False
      - ALLOWED_HOSTS=your-domain.com,www.your-domain.com
      - DATABASE_URL=postgresql://user:password@db:5432/dbname
    env_file:
      - .env  # 環境変数ファイルから読み込む（推奨）
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: dbname
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

#### .envファイルを使用する場合：

`.env`ファイルを作成（このファイルは`.gitignore`に含まれています）：

```bash
SECRET_KEY=your-generated-secret-key-here
DEBUG=False
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
```

### 2. AWS ECS/Fargateでの設定

#### 方法A: タスク定義で直接設定

ECSタスク定義のJSONファイルまたはコンソールで環境変数を設定：

```json
{
  "containerDefinitions": [
    {
      "name": "my-django-app",
      "image": "your-ecr-registry/my-django-app:latest",
      "environment": [
        {
          "name": "SECRET_KEY",
          "value": "your-generated-secret-key-here"
        },
        {
          "name": "DEBUG",
          "value": "False"
        },
        {
          "name": "ALLOWED_HOSTS",
          "value": "your-domain.com,www.your-domain.com"
        },
        {
          "name": "DATABASE_URL",
          "value": "postgresql://user:password@rds-endpoint:5432/dbname"
        }
      ],
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

**⚠️ セキュリティ警告**: SECRET_KEYをタスク定義に直接記述するのは推奨されません。AWS Systems Manager Parameter Store または AWS Secrets Manager を使用してください。

#### 方法B: AWS Systems Manager Parameter Store（推奨）

1. **Parameter Storeに値を保存**：

```bash
# AWS CLIでパラメータを保存
aws ssm put-parameter \
  --name "/my-django-app/SECRET_KEY" \
  --value "your-generated-secret-key-here" \
  --type "SecureString" \
  --region ap-northeast-1

aws ssm put-parameter \
  --name "/my-django-app/DATABASE_URL" \
  --value "postgresql://user:password@rds-endpoint:5432/dbname" \
  --type "SecureString" \
  --region ap-northeast-1
```

2. **ECSタスク定義で参照**：

```json
{
  "containerDefinitions": [
    {
      "name": "my-django-app",
      "image": "your-ecr-registry/my-django-app:latest",
      "secrets": [
        {
          "name": "SECRET_KEY",
          "valueFrom": "arn:aws:ssm:ap-northeast-1:123456789012:parameter/my-django-app/SECRET_KEY"
        },
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:ssm:ap-northeast-1:123456789012:parameter/my-django-app/DATABASE_URL"
        }
      ],
      "environment": [
        {
          "name": "DEBUG",
          "value": "False"
        },
        {
          "name": "ALLOWED_HOSTS",
          "value": "your-domain.com,www.your-domain.com"
        }
      ]
    }
  ]
}
```

3. **タスクロールに権限を付与**：

ECSタスク実行ロールに以下のポリシーを追加：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:ap-northeast-1:123456789012:parameter/my-django-app/*"
      ]
    }
  ]
}
```

#### 方法C: AWS Secrets Manager（最高レベルのセキュリティ）

1. **Secrets Managerにシークレットを保存**：

```bash
aws secretsmanager create-secret \
  --name "my-django-app/secrets" \
  --secret-string '{"SECRET_KEY":"your-generated-secret-key-here","DATABASE_URL":"postgresql://..."}' \
  --region ap-northeast-1
```

2. **ECSタスク定義で参照**：

```json
{
  "containerDefinitions": [
    {
      "name": "my-django-app",
      "image": "your-ecr-registry/my-django-app:latest",
      "secrets": [
        {
          "name": "SECRET_KEY",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:my-django-app/secrets:SECRET_KEY::"
        },
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:my-django-app/secrets:DATABASE_URL::"
        }
      ]
    }
  ]
}
```

## ⚖️ Parameter Store vs Secrets Manager 比較

AWSでシークレットを管理する際の選択肢として、Parameter StoreとSecrets Managerがあります。以下は両者の比較です。

### 比較表

| 項目 | Parameter Store | Secrets Manager |
|------|----------------|----------------|
| **料金** | 無料（Standard）、有料（Advanced） | 1シークレットあたり月額$0.40 + API呼び出し料金 |
| **シークレットサイズ** | 8KB（Standard）、4KB（Advanced） | 64KB |
| **自動ローテーション** | ❌ なし | ✅ あり（RDS、Redshift等） |
| **バージョン管理** | ✅ あり | ✅ あり |
| **暗号化** | ✅ KMSによる暗号化 | ✅ KMSによる暗号化（必須） |
| **監査ログ** | ✅ CloudTrailでログ記録 | ✅ CloudTrailでログ記録 |
| **統合性** | ✅ ECS、Lambda等と統合 | ✅ ECS、Lambda、RDS等と統合 |
| **複数値をJSON形式で保存** | ⚠️ 可能だが推奨されない | ✅ 推奨（JSON形式） |
| **設定の複雑さ** | 🟢 シンプル | 🟡 やや複雑 |
| **IAMポリシー** | 🟢 シンプル | 🟡 やや複雑 |

### Parameter Store（推奨: コスト重視・シンプルな構成）

#### ✅ メリット
- **無料で利用可能**（Standardパラメータ）
- **シンプルな設定**で導入しやすい
- **ECS、Lambda等と直接統合**可能
- **階層的なパラメータ管理**が可能（例: `/app/env/secret`）

#### ❌ デメリット
- **自動ローテーション機能がない**（手動で更新が必要）
- **シークレットサイズ制限**（8KB）
- **個別パラメータごとにARNが必要**（複数値を扱う場合）

#### 📝 使用例
- 単一の環境変数（SECRET_KEY、API_KEY等）
- 設定値とシークレットを同じ場所で管理したい場合
- コストを抑えたい場合

```bash
# 個別パラメータとして保存
aws ssm put-parameter --name "/app/SECRET_KEY" --value "xxx" --type "SecureString"
aws ssm put-parameter --name "/app/DATABASE_URL" --value "xxx" --type "SecureString"
```

### Secrets Manager（推奨: セキュリティ重視・自動化したい場合）

#### ✅ メリット
- **自動ローテーション機能**（RDS、Redshift、DocumentDB等）
- **より大きなシークレットサイズ**（64KB）
- **複数のシークレットを1つのJSONで管理**可能
- **より詳細な監査とアクセス制御**

#### ❌ デメリット
- **有料**（1シークレットあたり月額$0.40 + API呼び出し料金）
- **設定がやや複雑**（JSON形式での管理）
- **自動ローテーションを使用しない場合は過剰**な場合がある

#### 📝 使用例
- RDSデータベースパスワード（自動ローテーションが必要）
- 複数のシークレットをまとめて管理したい場合
- 高セキュリティ要件がある場合

```bash
# JSON形式で複数のシークレットを一度に保存
aws secretsmanager create-secret \
  --name "app/secrets" \
  --secret-string '{"SECRET_KEY":"xxx","DATABASE_URL":"xxx"}'
```

### 推奨される選択

| シナリオ | 推奨サービス | 理由 |
|---------|------------|------|
| **単一の環境変数（SECRET_KEY等）** | Parameter Store | 無料でシンプル |
| **複数のシークレットをまとめて管理** | Secrets Manager | JSON形式で一元管理可能 |
| **RDS等の自動ローテーションが必要** | Secrets Manager | 自動ローテーション機能が利用可能 |
| **コストを抑えたい** | Parameter Store | 無料で利用可能 |
| **小規模プロジェクト** | Parameter Store | シンプルで十分 |
| **大規模・エンタープライズ** | Secrets Manager | より詳細な管理機能 |

### まとめ

- **Parameter Store**: コスト重視・シンプルな構成 → **小規模～中規模プロジェクト向け**
- **Secrets Manager**: セキュリティ重視・自動化重視 → **大規模プロジェクト・自動ローテーションが必要な場合向け**

### 3. ローカル開発環境での設定

#### Windows (PowerShell):

```powershell
$env:SECRET_KEY="your-generated-secret-key-here"
$env:DEBUG="True"
python manage.py runserver
```

#### Windows (Command Prompt):

```cmd
set SECRET_KEY=your-generated-secret-key-here
set DEBUG=True
python manage.py runserver
```

#### Linux/macOS:

```bash
export SECRET_KEY='your-generated-secret-key-here'
export DEBUG='True'
python manage.py runserver
```

または、`.env`ファイルを使用（`python-decouple`パッケージが必要）：

```python
# settings.py で追加
from decouple import config

SECRET_KEY = config('SECRET_KEY', default='django-insecure-change-this-in-production')
```

### 4. GitHub Actionsでの設定（CI/CD用）

`.github/workflows/deploy.yml`に環境変数を追加：

```yaml
jobs:
  build-and-push:
    steps:
      - name: Build, tag, and push image to Amazon ECR
        env:
          SECRET_KEY: ${{ secrets.SECRET_KEY }}  # GitHub Secretsに設定
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build \
            --build-arg SECRET_KEY=$SECRET_KEY \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          # ... 以下省略
```

**注意**: GitHub Actionsでビルド時のみ必要な場合に使用。実行時の環境変数はデプロイ先で設定してください。

## 🔒 セキュリティベストプラクティス

1. **SECRET_KEYは必ず環境変数で設定**: コードに直接書かない
2. **本番環境では`.gitignore`に`.env`を含める**: 既に含まれています
3. **AWS環境ではParameter Store/Secrets Managerを使用**: タスク定義に直接書かない
4. **定期的にローテーション**: SECRET_KEYは定期的に変更することを推奨
5. **最小権限の原則**: Parameter Store/Secrets Managerへのアクセス権限は必要最小限に

## 📋 必要な環境変数一覧

| 環境変数名 | 必須 | 説明 | デフォルト値 |
|----------|------|------|------------|
| `SECRET_KEY` | ✅ 本番では必須 | Djangoの秘密鍵 | `django-insecure-change-this-in-production`（開発用のみ） |
| `DEBUG` | ⚠️ 本番では必須 | デバッグモード | `False` |
| `ALLOWED_HOSTS` | ⚠️ 本番では必須 | 許可されたホスト名（カンマ区切り） | `localhost,127.0.0.1` |
| `DATABASE_URL` | オプション | データベース接続URL | SQLite（開発用） |

## 🔗 参考資料

- [Django デプロイメントチェックリスト](https://docs.djangoproject.com/ja/5.0/howto/deployment/checklist/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [AWS ECS タスク定義の環境変数](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/taskdef-envfiles.html)

