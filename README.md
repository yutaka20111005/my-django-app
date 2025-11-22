# GitHub Actions + AWS ECR 自動デプロイ

このプロジェクトは、GitHub Actionsを使用してDockerコンテナをビルドし、AWS ECR（Elastic Container Registry）にプッシュするためのTerraformコードとGitHub Actionsワークフローを提供します。

## 📋 目次

- [概要](#概要)
- [アーキテクチャ](#アーキテクチャ)
- [セキュリティ対策](#セキュリティ対策)
- [前提条件](#前提条件)
- [セットアップ手順](#セットアップ手順)
- [使用方法](#使用方法)
- [トラブルシューティング](#トラブルシューティング)

## 📖 概要

このプロジェクトでは、以下の機能を提供します：

- **AWS ECRリポジトリの作成**: Dockerイメージを保存するためのECRリポジトリ
- **OIDC認証**: AWS Access Key/Secret Keyを使わない安全な認証方法
- **自動ビルド・プッシュ**: GitHub Actionsで自動的にDockerイメージをビルドしてECRにプッシュ
- **イメージライフサイクル管理**: 古いイメージの自動削除

## 🏗️ アーキテクチャ

```
GitHub Repository
    ↓
GitHub Actions (OIDC認証)
    ↓
AWS IAM Role (AssumeRoleWithWebIdentity)
    ↓
AWS ECR (Dockerイメージ保存)
```

## 🔒 セキュリティ対策

### 1. OIDC（OpenID Connect）認証の使用

**なぜ重要か**: 
- AWS Access Key IDとSecret Access Keyを保存する必要がありません
- 一時的な認証情報のみを使用するため、漏洩リスクが大幅に低減されます
- キーのローテーションが不要です

**実装内容**:
- GitHub ActionsとAWSの間でOIDCプロバイダーを使用
- IAMロールによる一時的な認証情報の提供
- リポジトリ単位でのアクセス制御

### 2. 最小権限の原則

**実装内容**:
- IAMポリシーはECRへのプッシュ・プルに必要な最小限の権限のみを付与
- リソースレベルでのアクセス制限（特定のECRリポジトリのみ）

### 3. GitHub Secretsの使用

**重要**: 
- `terraform.tfvars`ファイルをリポジトリにコミットしないこと
- `terraform.tfvars.example`をテンプレートとして使用
- AWSの認証情報はGitHub Secretsに保存（OIDCのため、実際には必要なし）

### 4. Terraform状態ファイルの保護

**推奨事項**:
- Terraform状態ファイル（`terraform.tfstate`）をバージョン管理に含めない（`.gitignore`に含まれています）
- 本番環境では、リモートバックエンド（S3）の使用を推奨
- Terraform 1.13.5以降では、S3バックエンドのネイティブな状態ロック機能により、DynamoDBは不要です

### 5. ECRリポジトリのセキュリティ設定

- **イメージスキャン**: プッシュ時の自動スキャンを有効化
- **暗号化**: AES256による暗号化
- **ライフサイクルポリシー**: 古いイメージの自動削除

### 6. IAMロールの条件付きアクセス

- GitHubリポジトリ単位でのアクセス制御
- 特定のブランチやタグからのみアクセス可能に設定可能

## ✅ 前提条件

1. **AWSアカウント**: アクティブなAWSアカウント
2. **Terraform**: バージョン 1.0以上がインストール済み
3. **AWS CLI**: インストール済みかつ設定済み（`aws configure`実行済み）
4. **GitHubリポジトリ**: GitHub Actionsが有効なリポジトリ
5. **Docker**: ローカルでのテスト用（オプション）

## 🚀 セットアップ手順

> **📌 実行前の確認**: 以下の前提条件を満たしていることを確認してください
> - AWS CLIが設定済み（`aws configure`実行済み、`aws sts get-caller-identity`で確認可能）
> - Terraformがインストール済み（`terraform version`で確認可能）
> - GitHubリポジトリの所有者/リポジトリ名を把握している（例: `yutaka20111005/my-django-app`）

### ステップ1: Terraformの設定

1. **terraform.tfvarsファイルの作成**:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

2. **terraform.tfvarsの編集**:

```hcl
aws_region         = "ap-northeast-1"
project_name       = "my-django-app"
ecr_repository_name = "my-django-app"
github_repository  = "yutaka20111005/my-django-app"  # あなたのGitHubリポジトリ

image_retention_count = 10

tags = {
  Environment = "production"
  Project     = "my-django-app"
  ManagedBy   = "terraform"
}
```

**📌 `github_repository`の形式について**:

`github_repository`は `owner/repo` 形式で指定します。これは、GitHubリポジトリのURLから取得できます。

**具体例**:
- パーソナルアカウントの場合: `taro-yamada/my-django-app`
- 組織アカウントの場合: `mycompany/my-django-app`
- ユーザー名が `johnsmith`、リポジトリ名が `awesome-app` の場合: `johnsmith/awesome-app`

**確認方法**:
1. GitHubリポジトリのページを開く
2. ブラウザのアドレスバーを確認（例: `https://github.com/taro-yamada/my-django-app`）
3. `https://github.com/` の後の部分（`taro-yamada/my-django-app`）が `owner/repo` 形式

**重要**: `terraform.tfvars`は`.gitignore`に含まれているため、リポジトリにコミットされません。

### ステップ2: Terraformの実行

1. **Terraformの初期化**:

```bash
cd terraform
terraform init
```

2. **実行計画の確認**:

```bash
terraform plan
```

3. **リソースの作成**:

```bash
terraform apply
```

4. **出力値の確認**:

Terraform実行後、以下のような出力が表示されます：

```
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-django-app"
github_actions_role_arn = "arn:aws:iam::123456789012:role/my-django-app-github-actions-role"
```

**重要**: `github_actions_role_arn`の値をコピーしてください（次のステップで使用します）。

### ステップ3: GitHub Secretsの設定

1. **GitHubリポジトリに移動**
   - Settings → Secrets and variables → Actions

2. **New repository secretをクリック**

3. **以下のSecretを追加**:

| Secret名 | 値 | 説明 |
|---------|-----|------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/my-django-app-github-actions-role` | Terraformの出力から取得したIAMロールARN |

**注意**: OIDCを使用するため、AWS_ACCESS_KEY_IDやAWS_SECRET_ACCESS_KEYは不要です。

### ステップ4: GitHub Actionsワークフローの設定

1. **ワークフローファイルの確認**:
   - `.github/workflows/deploy.yml`が正しく設定されていることを確認

2. **環境変数の更新**:
   - ファイル内の`ECR_REPOSITORY`を**ステップ1で設定した`ecr_repository_name`と同じ値**に更新
   - `AWS_REGION`も必要に応じて更新（ステップ1の`aws_region`と一致させる）

```yaml
env:
  AWS_REGION: ap-northeast-1  # terraform.tfvarsのaws_regionと一致させる
  ECR_REPOSITORY: my-django-app  # terraform.tfvarsのecr_repository_nameと一致させる
```

**重要**: `ECR_REPOSITORY`の値は、ステップ1の`terraform.tfvars`で設定した`ecr_repository_name`と**完全に一致**させる必要があります。

### ステップ5: Dockerfileの確認

プロジェクトルートに`Dockerfile`が存在することを確認してください。存在しない場合は、アプリケーションに合わせて作成してください。

### ステップ6: テスト実行

1. **変更をコミット・プッシュ**:

```bash
git add .
git commit -m "Add GitHub Actions workflow and Terraform code"
git push origin main
```

2. **GitHub Actionsの確認**:
   - GitHubリポジトリの「Actions」タブを開く
   - ワークフローの実行状況を確認

3. **ECRへのプッシュ確認**:
   - AWSコンソール → ECR → リポジトリ → イメージの確認

## 📝 使用方法

### ワークフローのトリガー

以下のイベントでワークフローが自動実行されます：

- `main`または`develop`ブランチへのプッシュ
- `v*`形式のタグの作成（例: `v1.0.0`）
- プルリクエストの作成（`main`/`develop`へのPR）
- 手動実行（Actionsタブから`workflow_dispatch`）

### イメージのタグ

- **コミットハッシュ**: `{ECR_REGISTRY}/{ECR_REPOSITORY}:{git-sha}`
- **latest**: `{ECR_REGISTRY}/{ECR_REPOSITORY}:latest`

### ローカルでのECRアクセス（開発用）

1. **AWS CLIでログイン**:

```bash
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
```

2. **イメージのプル**:

```bash
docker pull 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-django-app:latest
```

## 🔧 トラブルシューティング

### エラー: "Error: AccessDenied"

**原因**: IAMロールの権限が不足している可能性があります。

**解決策**:
1. IAMロールのポリシーを確認
2. ECRリポジトリのARNが正しいことを確認
3. GitHubリポジトリ名が`terraform.tfvars`で正しく設定されていることを確認

### エラー: "Error assuming role with OIDC"

**原因**: OIDCプロバイダーの設定またはGitHubリポジトリの設定が間違っています。

**解決策**:
1. `github_repository`変数が正しい形式（`owner/repo`）であることを確認
2. GitHubリポジトリの設定でOIDCが有効になっていることを確認
3. IAMロールのAssumeRolePolicyを確認

### エラー: "Repository not found"

**原因**: ECRリポジトリ名が間違っているか、存在しません。

**解決策**:
1. Terraformの出力でECRリポジトリURLを確認
2. GitHub Actionsワークフロー内の`ECR_REPOSITORY`環境変数を確認

### イメージがプッシュされない

**原因**: Dockerfileが存在しないか、ビルドエラーが発生している可能性があります。

**解決策**:
1. GitHub Actionsのログを確認
2. ローカルで`docker build`が成功することを確認
3. Dockerfileのパスが正しいことを確認

## 🔐 追加のセキュリティ推奨事項

### 1. Terraform状態ファイルのリモートバックエンド

本番環境では、以下の設定を追加することを推奨します：

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "ecr/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
  }
}
```

**注意**: Terraform 1.13.5以降では、S3バックエンドのネイティブな状態ロック機能が利用可能なため、DynamoDBテーブルは不要です。S3バケットのみで状態ファイルの保存と状態ロックの両方が実現できます。

### 2. GitHubブランチ保護ルール

- メインブランチへの直接プッシュを制限
- プルリクエスト必須
- コードレビュー必須

### 3. 定期的なセキュリティスキャン

- ECRイメージの脆弱性スキャンを有効化（既に有効）
- GitHub Dependabotの有効化
- 定期的な依存関係の更新

### 4. IAMポリシーの定期レビュー

- 定期的にIAMポリシーを見直し
- 不要な権限の削除
- CloudTrailでのアクセスログ監視

## 📚 参考資料

- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions: Configure AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)
- [AWS IAM OIDC Identity Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

## 📄 ライセンス

このプロジェクトのライセンス情報を記載してください。

---

**注意**: この設定は本番環境用のセキュアな構成です。開発環境では、要件に応じて調整してください。

