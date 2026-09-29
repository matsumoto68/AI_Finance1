# Requirements Document

## 複数サーバ対応リリース作業自動化 - シェルスクリプト拡張

---

## Introduction

本ドキュメントは、既存の単一サーバ向けリリース作業自動化スクリプト（`CommandA.sh`）を、
複数サーバ（サーバA・サーバB）対応に拡張するための要件を定義する。

現状、資材（シェルスクリプト）はサーバAに格納されており、サーバAでの処理（25コマンド）のみが
自動化されている。本拡張では、サーバAでの処理完了後にサーバBへ資材を転送（SCP）し、
SSH経由でサーバBのコマンドをリモート実行する機能を追加する。

### 拡張方針

- 既存の `CommandA.sh`（サーバA向け25コマンド）の動作は変更しない
- 新たに `CommandB.sh`（サーバB向けコマンド群）をサーバA上に作成する
- サーバA処理完了後にサーバBへ資材転送・リモート実行を行うオーケストレーターシェルを新設する
- 既存の共通関数（`log_info()`, `log_error()`, `log_cmd()`, `log_rc()`, `check_rc()`, `check_str()`）を継承する

---

## Glossary

| 用語 | 定義 |
|------|------|
| **Multi_Release_Script** | 複数サーバ対応リリース作業自動化システム全体 |
| **Orchestrator** | `release_all.sh`。サーバAの処理完了後にサーバBへの資材転送・リモート実行を制御するオーケストレーターシェル |
| **ServerA_Script** | `CommandA.sh`。サーバA上でローカル実行される既存の自動化シェル（25コマンド） |
| **ServerB_Script** | `CommandB.sh`。サーバB上でリモート実行される自動化シェル |
| **Deploy_Script** | `deploy_multi.sh`。複数サーバ向けの資材配置シェル |
| **サーバA** | `CommandA.sh` および `CommandB.sh` の資材が格納されている実行元サーバ |
| **サーバB** | サーバAからSCPで資材を受け取り、コマンドを実行する対象サーバ |
| **SSH接続** | サーバAからサーバBへのSecure Shell接続 |
| **SCP転送** | SSH経由でのファイル転送（Secure Copy Protocol） |
| **EARS** | Easy Approach to Requirements Syntax。要件記述パターン |
| **ReturnCode** | Linuxコマンド実行後の終了コード（`$?`） |
| **LOG_DIR** | ログ出力ディレクトリ `/var/log/release/` |
| **SCRIPT_DIR** | スクリプト配置ディレクトリ `/opt/release/scripts/` |
| **WORK_DIR** | 作業ディレクトリ `/tmp/testdir/` |
| **SSH_USER** | サーバBへのSSH接続ユーザー名 |
| **SSH_HOST** | サーバBのホスト名またはIPアドレス |
| **SSH_KEY** | サーバBへの公開鍵認証用秘密鍵ファイルパス |

---

## Requirements

---

### 要件1：オーケストレーター機能

**ユーザーストーリー：** 担当者として、単一のシェルを実行するだけでサーバAとサーバBの両方のリリース処理が順番に自動実行されるようにしたい。そうすることで、複数サーバへの手動操作を排除し、リリース作業を効率化できる。

#### 受け入れ基準

1. THE Multi_Release_Script SHALL `release_all.sh`（Orchestrator）を提供し、サーバAの処理・サーバBへの資材転送・サーバBのリモート実行を1回の実行で完結させる

2. WHEN `release_all.sh` が起動されたとき、THE Orchestrator SHALL サーバA処理（ServerA_Script）を先に実行し、サーバA処理が正常終了した場合にのみサーバBへの処理を継続する

3. THE Orchestrator SHALL 実行順序を「サーバA処理 → サーバBへの資材転送（SCP） → サーバBでのリモート実行（SSH）」の順序で保証する

4. WHEN サーバA処理がエラー終了したとき、THE Orchestrator SHALL サーバBへの資材転送およびリモート実行を行わずに処理を中断し、`exit 1` で終了する

5. THE Orchestrator SHALL 処理開始時に実行対象サーバ（サーバA、サーバB）の情報をシェル実行ログに出力する

---

### 要件2：サーバA処理（既存機能の継承）

**ユーザーストーリー：** 担当者として、既存の `CommandA.sh` が持つ25コマンドの自動実行機能を、複数サーバ対応後も変更なく動作させたい。そうすることで、既存の試験済み資産を継承し、手戻りを防止できる。

#### 受け入れ基準

1. THE Orchestrator SHALL 既存の `CommandA.sh` をサーバA上でローカル実行する（既存スクリプトの動作は変更しない）

2. WHEN `CommandA.sh` が正常終了（ReturnCode=0）したとき、THE Orchestrator SHALL サーバBへの処理に進む

3. IF `CommandA.sh` の実行に失敗したとき、THEN THE Orchestrator SHALL エラーコードと詳細メッセージをシェル実行ログおよび詳細ログに記録し、`exit 1` で終了する

4. THE ServerA_Script SHALL 既存の処理フロー（`init_log` → `check_env` → `proc_dir` → `proc_file` → `proc_service` → `proc_misc`）を維持する

---

### 要件3：サーバBへの資材転送（SCP）

**ユーザーストーリー：** 担当者として、サーバAに格納されたサーバB向け資材（`CommandB.sh`）がサーバBの所定ディレクトリへ自動転送されるようにしたい。そうすることで、手動のファイル転送作業を排除できる。

#### 受け入れ基準

1. WHEN サーバA処理が正常終了したとき、THE Orchestrator SHALL `scp` コマンドを使用してサーバBへ `CommandB.sh` を転送する

2. THE Orchestrator SHALL SCP転送先パスを `/opt/release/scripts/CommandB.sh` とする

3. THE Orchestrator SHALL SCP転送時に公開鍵認証（`-i ${SSH_KEY}`）を使用する

4. THE Orchestrator SHALL SCP転送コマンドの実行前に `log_cmd()` でコマンド文字列を詳細ログに記録する

5. THE Orchestrator SHALL SCP転送コマンドの実行後に ReturnCode を `log_rc()` で詳細ログに記録する

6. IF SCP転送が失敗したとき（ReturnCode≠0）、THEN THE Orchestrator SHALL エラーメッセージをシェル実行ログに記録し、`exit 1` で終了する

7. WHEN SCP転送が正常完了したとき、THE Orchestrator SHALL 転送完了メッセージを `log_info()` でシェル実行ログに記録する

---

### 要件4：サーバBでのリモート実行（SSH）

**ユーザーストーリー：** 担当者として、転送されたサーバB向け資材が、SSH経由で自動実行されるようにしたい。そうすることで、サーバBへの手動ログインおよびコマンド実行を排除できる。

#### 受け入れ基準

1. WHEN SCP転送が正常完了したとき、THE Orchestrator SHALL `ssh` コマンドを使用してサーバB上で `CommandB.sh` をリモート実行する

2. THE Orchestrator SHALL SSHリモート実行時に公開鍵認証（`-i ${SSH_KEY}`）を使用する

3. THE Orchestrator SHALL SSHリモート実行コマンドの実行前に `log_cmd()` でコマンド文字列を詳細ログに記録する

4. THE Orchestrator SHALL SSHリモート実行コマンドの実行後に ReturnCode を `log_rc()` で詳細ログに記録する

5. IF SSHリモート実行が失敗したとき（ReturnCode≠0）、THEN THE Orchestrator SHALL エラーメッセージをシェル実行ログに記録し、`exit 1` で終了する

6. WHEN SSHリモート実行が正常完了したとき、THE Orchestrator SHALL 完了メッセージを `log_info()` でシェル実行ログに記録する

---

### 要件5：サーバB側スクリプト（CommandB.sh）

**ユーザーストーリー：** 担当者として、サーバB固有の処理（ファイル展開・サービス再起動等）がスクリプト化されており、SSH経由で確実に実行されるようにしたい。そうすることで、サーバBの作業手順を標準化し、手作業による操作ミスを防止できる。

#### 受け入れ基準

1. THE ServerB_Script SHALL サーバB上で独立して実行可能な bash シェルスクリプトとして実装する

2. THE ServerB_Script SHALL 既存の共通関数（`log_info()`, `log_error()`, `log_cmd()`, `log_rc()`, `check_rc()`, `check_str()`）を `CommandA.sh` と同一の仕様で実装する

3. THE ServerB_Script SHALL 処理開始時に `init_log` 処理を実行し、ログディレクトリの作成とログヘッダーの出力を行う

4. THE ServerB_Script SHALL ログファイルを `CommandB_YYYYMMDDHHMMSS.log` および `CommandB_detail_YYYYMMDDHHMMSS.log` の命名規則で `/var/log/release/` に出力する

5. THE ServerB_Script SHALL サーバB固有の各コマンド実行後に ReturnCode チェック（`check_rc()`）または出力文字列チェック（`check_str()`）を実施する

6. IF コマンド実行でエラーが発生したとき、THEN THE ServerB_Script SHALL エラー内容を詳細ログに記録し、`exit 1` で終了する

---

### 要件6：SSH接続前チェック

**ユーザーストーリー：** 担当者として、SSH/SCP実行前に接続可否が確認されるようにしたい。そうすることで、接続できない状態でのSCP/SSHコマンド実行を防ぎ、エラー原因を早期特定できる。

#### 受け入れ基準

1. WHEN `release_all.sh` が起動されたとき、THE Orchestrator SHALL SCP/SSH実行前に `ssh -o ConnectTimeout=10` を使用してサーバBへの疎通確認を実施する

2. IF サーバBへの疎通確認が失敗したとき（ReturnCode≠0）、THEN THE Orchestrator SHALL 「サーバB接続不可」のエラーメッセージをシェル実行ログに記録し、`exit 1` で終了する

3. THE Orchestrator SHALL 疎通確認コマンドの実行内容を `log_cmd()` で詳細ログに記録する

4. WHEN 疎通確認が成功したとき、THE Orchestrator SHALL 「サーバB接続確認完了」メッセージを `log_info()` でシェル実行ログに記録し、後続のSCP/SSH処理に進む

---

### 要件7：エラーハンドリング（SSH/SCP失敗）

**ユーザーストーリー：** 担当者として、SSH接続失敗・SCP転送失敗・リモートコマンド実行失敗が発生した場合に、エラー内容が明確にログに記録され、処理が即時中断されるようにしたい。そうすることで、障害原因の特定と対処を迅速に行える。

#### 受け入れ基準

1. IF SSH接続が失敗したとき（ReturnCode≠0）、THEN THE Orchestrator SHALL エラーコード・エラーメッセージ・対象ホスト名をシェル実行ログに記録し、`exit 1` で終了する

2. IF SCP転送が失敗したとき（ReturnCode≠0）、THEN THE Orchestrator SHALL エラーコード・転送元ファイルパス・転送先パスをシェル実行ログに記録し、`exit 1` で終了する

3. IF SSHリモート実行が失敗したとき（ReturnCode≠0）、THEN THE Orchestrator SHALL エラーコード・実行コマンド・ReturnCode 値をシェル実行ログおよび詳細ログに記録し、`exit 1` で終了する

4. THE Orchestrator SHALL SSH/SCP コマンド実行後に `rc=$?` で ReturnCode を変数に退避してから `check_rc()` に渡す

5. THE Orchestrator SHALL SSH/SCP エラーメッセージ出力に際して `2>&1` を使用してエラー出力を標準出力にリダイレクトしてからログに記録する

---

### 要件8：ログ出力（複数サーバ対応）

**ユーザーストーリー：** 担当者として、オーケストレーターの実行ログが既存のログ設計書のフォーマットに準拠して出力されるようにしたい。そうすることで、ログの可読性を統一し、障害調査や証跡確認を容易にできる。

#### 受け入れ基準

1. THE Orchestrator SHALL シェル実行ログを `release_all_YYYYMMDDHHMMSS.log`、詳細ログを `release_all_detail_YYYYMMDDHHMMSS.log` の命名規則で `/var/log/release/` に出力する

2. THE Orchestrator SHALL 全てのログ出力を既存フォーマット `[YYYY-MM-DD HH:MM:SS] [LEVEL] メッセージ` に準拠して行う

3. THE Orchestrator SHALL サーバA処理開始・完了、SCP転送開始・完了、SSHリモート実行開始・完了の各フェーズで `log_info()` を使用してシェル実行ログにメッセージを出力する

4. WHILE `release_all.sh` が実行中であるとき、THE Orchestrator SHALL SSH/SCP の各コマンド実行内容を `log_cmd()` で詳細ログに記録し続ける

5. THE Orchestrator SHALL ログファイルの権限を `644`（オーナー：読み書き、グループ/その他：読み取りのみ）に設定する

---

### 要件9：資材配置シェルの複数サーバ対応拡張

**ユーザーストーリー：** 担当者として、複数サーバ対応の全資材（`CommandB.sh`、`release_all.sh`）がサーバAの所定ディレクトリへ一括配置されるようにしたい。そうすることで、資材配置作業の手間を削減できる。

#### 受け入れ基準

1. THE Deploy_Script SHALL `deploy_multi.sh` として実装し、`CommandB.sh` および `release_all.sh` をサーバAの `/opt/release/scripts/` へ配置する

2. THE Deploy_Script SHALL 各配置対象ファイルの存在確認を行い、配置元ファイルが存在しない場合はエラーメッセージを出力して `exit 1` で終了する

3. THE Deploy_Script SHALL 配置先ディレクトリ `/opt/release/scripts/` が存在しない場合、`mkdir -p` で自動作成する

4. THE Deploy_Script SHALL 配置した各スクリプトファイルに対して `chmod 755` で実行権限を付与する

5. WHEN 全資材の配置が完了したとき、THE Deploy_Script SHALL 各ファイルの配置完了メッセージを標準出力に出力する

---

### 要件10：セキュリティ要件

**ユーザーストーリー：** 担当者として、SSH/SCPに使用する接続情報（ホスト名・ユーザー名・秘密鍵パス）がシェルスクリプトにハードコードされないようにしたい。そうすることで、機密情報の漏洩リスクを排除できる。

#### 受け入れ基準

1. THE Multi_Release_Script SHALL `SSH_HOST`、`SSH_USER`、`SSH_KEY` を実行時引数または設定ファイルから取得し、シェルスクリプト内にハードコードしない

2. IF 実行時に `SSH_HOST`、`SSH_USER`、`SSH_KEY` のいずれかが未設定または空文字の場合、THEN THE Orchestrator SHALL 不足パラメータ名をエラーメッセージとして出力し、`exit 1` で終了する

3. THE Multi_Release_Script SHALL `SSH_KEY` に指定された秘密鍵ファイルが存在しない場合、エラーメッセージを出力して `exit 1` で終了する

4. THE Multi_Release_Script SHALL 秘密鍵ファイルのパスおよびホスト名をシェル実行ログおよび詳細ログに出力する場合、パスワードやパスフレーズは記録しない

---

## 付録：処理フロー概要

```
release_all.sh 起動
    │
    ├─ init_log()                        # ログ初期化
    │
    ├─ パラメータチェック                  # SSH_HOST / SSH_USER / SSH_KEY 検証
    │
    ├─ check_ssh_connection()            # サーバBへの疎通確認
    │     IF 失敗 → exit 1
    │
    ├─ [サーバA処理]
    │   bash ${SCRIPT_DIR}/CommandA.sh
    │     IF 失敗 → exit 1
    │
    ├─ [サーバBへの資材転送]
    │   scp -i ${SSH_KEY} CommandB.sh ${SSH_USER}@${SSH_HOST}:/opt/release/scripts/
    │     IF 失敗 → exit 1
    │
    ├─ [サーバBでのリモート実行]
    │   ssh -i ${SSH_KEY} ${SSH_USER}@${SSH_HOST} bash /opt/release/scripts/CommandB.sh
    │     IF 失敗 → exit 1
    │
    └─ 正常終了ログ出力 → exit 0
```
