# Terraform セットアップ

このディレクトリには、AWS ECRとGitHub Actions統合用のTerraformコードが含まれています。

## クイックスタート

1. **terraform.tfvarsファイルの作成**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **terraform.tfvarsの編集**:
   - `github_repository`: あなたのGitHubリポジトリ（例: `myorg/my-repo`）
   - `ecr_repository_name`: ECRリポジトリ名
   - その他の設定を必要に応じて変更

3. **Terraformの初期化と適用**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **出力値の確認**:
   - `github_actions_role_arn`: GitHub Secretsに設定するARN
   - `ecr_repository_url`: ECRリポジトリのURL

## ファイル構成

- `main.tf`: メインのリソース定義（ECR、IAM、OIDC）
- `variables.tf`: 変数定義
- `outputs.tf`: 出力定義
- `versions.tf`: Terraformとプロバイダーのバージョン
- `terraform.tfvars.example`: 設定ファイルのテンプレート

## セキュリティ注意事項

- **terraform.tfvarsをコミットしない**: このファイルは`.gitignore`に含まれています
- **状態ファイルの保護**: `terraform.tfstate`もコミットされません。本番環境ではリモートバックエンドを使用してください

## リソースの削除

すべてのリソースを削除する場合：

```bash
terraform destroy
```

**警告**: これによりECRリポジトリ内のすべてのイメージも削除されます。

