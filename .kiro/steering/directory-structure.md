# ディレクトリ構成ステアリング

このプロジェクトは「リリース作業自動化（Kiro導入）」を対象としています。
シェルスクリプトや関連成果物を生成・編集する際は、以下のディレクトリ構成・命名規則・権限定義に従ってください。

---

## Linux環境（実行サーバ）のディレクトリ構成

```
/
├── opt/
│   └── release/
│       └── scripts/                  # スクリプト配置ディレクトリ（権限: 755）
│           ├── CommandA.sh           # メインシェルスクリプト
│           └── deploy_CommandA.sh    # 資材配置シェル
└── var/
    └── log/
        └── release/                  # ログ出力ディレクトリ（権限: 755）
            ├── CommandA_YYYYMMDDHHMMSS.log
            └── CommandA_detail_YYYYMMDDHHMMSS.log
└── tmp/
    ├── testdir/                      # 作業ディレクトリ（権限: 755）
    │   ├── test.txt
    │   ├── data.txt
    │   ├── data_bk.txt
    │   └── renamed.txt
    ├── testdir_bk/                   # バックアップディレクトリ（権限: 755）
    └── testfile.sh                   # 権限変更テスト用ファイル
```

---

## スクリプトファイルの配置ルール

- メインシェルスクリプトは必ず `/opt/release/scripts/` に配置する
- スクリプトファイルの権限は `755` に設定する
- ログディレクトリ `/var/log/release/` はスクリプトの配置フォルダとは分離する

---

## 命名規則

### シェルスクリプト

| 区分 | 規則 | 例 |
|------|------|----|
| メインシェル | `{コマンドID}.sh` | `CommandA.sh` |
| 資材配置シェル | `deploy_{コマンドID}.sh` | `deploy_CommandA.sh` |

### ログファイル

| 区分 | 規則 | 例 |
|------|------|----|
| シェル実行ログ | `{コマンドID}_YYYYMMDDHHMMSS.log` | `CommandA_20260825143052.log` |
| 詳細ログ | `{コマンドID}_detail_YYYYMMDDHHMMSS.log` | `CommandA_detail_20260825143052.log` |

### 作業ディレクトリ・ファイル

- 作業ディレクトリは `/tmp/` 配下に作成する
- バックアップディレクトリは元のディレクトリ名に `_bk` を付与する（例: `testdir` → `testdir_bk`）
- バックアップファイルは元のファイル名（拡張子なし）に `_bk` を付与する（例: `data.txt` → `data_bk.txt`）

---

## 権限定義

| 対象 | 権限値 | 備考 |
|------|--------|------|
| シェルスクリプト（.sh） | `755` | オーナー: rwx、グループ/その他: r-x |
| ログディレクトリ | `755` | オーナー: rwx、グループ/その他: r-x |
| ログファイル（.log） | `644` | オーナー: rw-、グループ/その他: r-- |
| 作業ディレクトリ | `755` | オーナー: rwx、グループ/その他: r-x |

---

## ディレクトリ・ファイルの作成・削除タイミング

| 対象 | 作成タイミング | 削除タイミング |
|------|--------------|--------------|
| `/opt/release/scripts/` | `deploy_CommandA.sh` 実行時（存在しない場合に自動作成） | 手動削除（自動削除なし） |
| `/var/log/release/` | `CommandA.sh` 起動時 `init_log` 処理（存在しない場合に自動作成） | 手動削除（自動削除なし） |
| `/tmp/testdir/` | `CommandA.sh` の `mkdir /tmp/testdir` | `CommandA.sh` の `rm -rf /tmp/testdir` |
| `/tmp/testdir_bk/` | `CommandA.sh` の `cp -r /tmp/testdir /tmp/testdir_bk` | `CommandA.sh` の `rmdir /tmp/testdir_bk` |
| `/tmp/testdir/test.txt` | `touch /tmp/testdir/test.txt` | `mv` によりリネーム（`renamed.txt` に変わる） |
| `/tmp/testdir/data.txt` | `echo hello > /tmp/testdir/data.txt` | `rm -rf` による間接削除 |
| `/tmp/testdir/data_bk.txt` | `cp /tmp/testdir/data.txt /tmp/testdir/data_bk.txt` | `rm /tmp/testdir/data_bk.txt` |
| `/tmp/testdir/renamed.txt` | `mv /tmp/testdir/test.txt /tmp/testdir/renamed.txt` | `rm -rf` による間接削除 |

---

## コード生成時の注意事項

- シェルスクリプトを新規作成する場合は、上記のパス・権限・命名規則に従うこと
- ログ出力は必ず `/var/log/release/` に行い、スクリプト配置ディレクトリとは分離すること
- 作業ディレクトリ（`/tmp/testdir/` 等）は処理終了後に適切なタイミングで削除すること
- バックアップファイル・ディレクトリには `_bk` サフィックスを付与すること
- ログファイル名には実行日時（YYYYMMDDHHMMSS形式）を含めること
