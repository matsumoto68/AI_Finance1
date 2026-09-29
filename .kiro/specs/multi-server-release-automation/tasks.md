# Implementation Plan: 複数サーバ対応リリース作業自動化

## Overview

既存の `CommandA.sh`（サーバA向け25コマンド自動化）を継承しつつ、以下の3ファイルを新規実装する。

- `deploy_multi.sh`：複数サーバ向け資材配置シェル
- `CommandB.sh`：サーバB向けリリース作業自動化シェル（SSH経由でリモート実行）
- `release_all.sh`：サーバA処理 → SCP転送 → SSHリモート実行を一括制御するオーケストレーター

実装順序は「共通関数・基盤 → 各処理関数 → 統合・動作確認」の順とし、依存関係を考慮して段階的に実装する。

---

## Tasks

- [ ] 1. deploy_multi.sh の実装
  - [ ] 1.1 定数定義・ファイルスケルトン作成
    - `#!/bin/bash`・`set -u` ヘッダーを記述する
    - `SCRIPT_DIR="/opt/release/scripts"`・`SRC_CMD_B="./CommandB.sh"`・`SRC_RELEASE_ALL="./release_all.sh"` を定数定義する
    - `main()` 関数の骨格（`check_src_files` → `make_dir` → `copy_files` → `set_permissions`）を記述する
    - _要件: 9.1_

  - [ ] 1.2 check_src_files 関数の実装
    - `CommandB.sh` の存在確認（`[ -f ${SRC_CMD_B} ]`）を実装し、不存在時にエラーメッセージを出力して `exit 1` する
    - `release_all.sh` の存在確認（`[ -f ${SRC_RELEASE_ALL} ]`）を実装し、不存在時に同様の処理をする
    - _要件: 9.2_

  - [ ] 1.3 make_dir 関数の実装
    - `[ -d ${SCRIPT_DIR} ] || mkdir -p ${SCRIPT_DIR}` で配置先ディレクトリを自動作成する
    - `mkdir` 失敗時はエラーメッセージを出力して `exit 1` する
    - _要件: 9.3_

  - [ ] 1.4 copy_files・set_permissions 関数の実装
    - `cp ${SRC_CMD_B} ${SCRIPT_DIR}/CommandB.sh` および `cp ${SRC_RELEASE_ALL} ${SCRIPT_DIR}/release_all.sh` を実装し、RC≠0 の場合はエラー出力して `exit 1` する
    - `chmod 755 ${SCRIPT_DIR}/CommandB.sh` および `chmod 755 ${SCRIPT_DIR}/release_all.sh` を実装し、RC≠0 の場合は同様の処理をする
    - 全配置完了後に `echo "全資材の配置完了: ${SCRIPT_DIR}"` を出力する
    - _要件: 9.4, 9.5_

  - [ ]* 1.5 deploy_multi.sh の動作確認テスト
    - 正常系：両ソースファイルが存在する状態でスクリプトを実行し、配置先に `755` で配置されることを確認する
    - 異常系：`CommandB.sh` を削除した状態で実行し、エラーメッセージ出力・`exit 1` を確認する
    - _要件: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 2. CommandB.sh の実装

  - [ ] 2.1 定数定義・共通関数・ファイルスケルトン作成
    - `#!/bin/bash`・`set -u` ヘッダーを記述する
    - `LOG_DIR`・`TIMESTAMP`・`LOG_FILE`・`DETAIL_LOG`・`WORK_DIR_B`・`DATA_FILE_B`・`SERVICE_NAME_B` を定数定義する
    - `CommandA.sh` と同一仕様で `log_info()`・`log_error()`・`log_cmd()`・`log_rc()`・`check_rc()`・`check_str()` の6共通関数を実装する
    - `main()` 関数の骨格（`init_log` → `check_env_b` → `proc_dir_b` → `proc_file_b` → `proc_service_b`）を記述する
    - _要件: 5.1, 5.2_

  - [ ] 2.2 init_log 関数の実装（CommandB.sh）
    - `LOG_DIR` が存在しない場合 `mkdir -p` で作成し、失敗時はエラー出力して `exit 1` する（E601）
    - `LOG_FILE` と `DETAIL_LOG` にスクリプト名・実行開始日時のヘッダーを出力する
    - _要件: 5.3, 5.4_

  - [ ] 2.3 check_env_b 関数の実装
    - `LOG_DIR` への書き込み権限確認（`-w` チェック）を実装し、権限がない場合はエラー出力して `exit 1` する
    - `command -v systemctl` で `systemctl` コマンドの存在確認を実装し、不存在の場合はエラー出力して `exit 1` する
    - _要件: 5.5, 5.6_

  - [ ] 2.4 proc_dir_b 関数の実装
    - `CommandA.sh` の `proc_dir()` と同等のパターンで、`WORK_DIR_B`（`/tmp/testdir_b`）に対するディレクトリ作成・確認・削除操作を実装する
    - 各コマンド実行前に `log_cmd()`、実行後に `rc=$?` で ReturnCode を退避し `check_rc()` または `check_str()` でチェックする
    - _要件: 5.5, 5.6_

  - [ ] 2.5 proc_file_b 関数の実装
    - `CommandA.sh` の `proc_file()` と同等のパターンで、`DATA_FILE_B`（`/tmp/testdir_b/data_b.txt`）に対するファイル作成・確認・コピー・削除操作を実装する
    - 各コマンド実行前に `log_cmd()`、実行後に ReturnCode を `check_rc()` または `check_str()` でチェックする
    - _要件: 5.5, 5.6_

  - [ ] 2.6 proc_service_b 関数の実装
    - `CommandA.sh` の `proc_service()` と同等のパターンで、`SERVICE_NAME_B`（`httpd`）に対するサービス起動・状態確認・停止操作を実装する
    - `systemctl start`・`systemctl is-active`・`systemctl stop`・`systemctl status` を実装し、各コマンド後に `check_rc()` または `check_str()` でチェックする
    - _要件: 5.5, 5.6_

  - [ ]* 2.7 CommandB.sh の動作確認テスト
    - スモークテスト：スクリプトが存在し権限が `755` であることを確認する
    - 正常系：`CommandB.sh` を直接実行し、ログファイル（`CommandB_*.log`・`CommandB_detail_*.log`）が `/var/log/release/` に生成されることを確認する
    - 異常系：`LOG_DIR` を書き込み不可にした状態で実行し、`exit 1` となることを確認する（E601）
    - _要件: 5.1, 5.3, 5.4, 5.6_

- [ ] 3. チェックポイント
  - 全テストが通過していることを確認する。不明点があればユーザーに確認する。

- [ ] 4. release_all.sh の実装

  - [ ] 4.1 定数定義・実行時引数・共通関数・ファイルスケルトン作成
    - `#!/bin/bash`・`set -u` ヘッダーを記述する
    - `LOG_DIR`・`TIMESTAMP`・`LOG_FILE`・`DETAIL_LOG`・`SCRIPT_DIR`・`CMD_B_SH`・`CMD_B_REMOTE` を `readonly` で定数定義する
    - `SSH_HOST="$1"`・`SSH_USER="$2"`・`SSH_KEY="$3"` で実行時引数を受け取る
    - `CommandA.sh` と同一仕様で6共通関数を実装する
    - `main()` 関数の骨格（`init_log` → `check_params` → `check_ssh_connection` → `run_server_a` → `scp_to_server_b` → `run_server_b` → 正常終了ログ → `exit 0`）を記述する
    - _要件: 1.1, 10.1_

  - [ ] 4.2 init_log 関数の実装（release_all.sh）
    - `LOG_DIR` が存在しない場合 `mkdir -p` で作成する
    - `LOG_FILE` と `DETAIL_LOG` にスクリプト名・実行開始日時のヘッダーを出力する
    - 実行対象サーバ（`SSH_HOST`）を `log_info()` でシェル実行ログに出力する
    - _要件: 1.5, 8.1, 8.2_

  - [ ] 4.3 check_params 関数の実装
    - `SSH_HOST`・`SSH_USER`・`SSH_KEY` それぞれが空文字でないことを確認し、空の場合は不足パラメータ名を `log_error()` で出力して `exit 1` する（E501）
    - `SSH_KEY` で指定されたファイルが存在することを `[ -f "${SSH_KEY}" ]` で確認し、不存在の場合は `log_error()` で出力して `exit 1` する（E502）
    - _要件: 10.1, 10.2, 10.3_

  - [ ]* 4.4 プロパティテストの実装（Property 2：必須パラメータ未設定時の拒否）
    - **Property 2: 必須パラメータ未設定時の拒否**
    - **Validates: 要件 10.2**
    - `SSH_HOST`・`SSH_USER`・`SSH_KEY` の値の組み合わせ（各値：有効な文字列 or 空文字）を生成するジェネレーターを実装し、1つ以上が空文字の全パターンで `release_all.sh` が `exit 1` で終了し、シェル実行ログに空だったパラメータ名が含まれることを100回以上のイテレーションで検証する
    - _要件: 10.2_

  - [ ] 4.5 check_ssh_connection 関数の実装
    - `ssh -o ConnectTimeout=10 -i ${SSH_KEY} ${SSH_USER}@${SSH_HOST} exit 2>&1` を実行する前に `log_cmd()` でコマンド文字列を詳細ログへ記録する
    - `rc=$?` で ReturnCode を退避し、RC≠0 の場合はホスト名付きエラーメッセージを `log_error()` で出力して `exit 1` する（E503）
    - 疎通確認成功時は `log_info()` で「サーバB接続確認完了」を出力する
    - _要件: 6.1, 6.2, 6.3, 6.4_

  - [ ] 4.6 run_server_a 関数の実装
    - 処理開始ログを `log_info()` で出力する
    - `bash ${SCRIPT_DIR}/CommandA.sh` を実行し、`rc=$?` で ReturnCode を退避する
    - RC≠0 の場合はエラーコード・詳細メッセージを `log_error()` で出力して `exit 1` する（E504）
    - 正常終了時は処理完了ログを `log_info()` で出力する
    - _要件: 2.1, 2.2, 2.3_

  - [ ] 4.7 scp_to_server_b 関数の実装
    - 転送開始ログを `log_info()` で出力する
    - `log_cmd "scp -i ${SSH_KEY} ${CMD_B_SH} ${SSH_USER}@${SSH_HOST}:${CMD_B_REMOTE}"` でコマンド文字列を詳細ログへ記録する
    - `scp -i "${SSH_KEY}" "${CMD_B_SH}" "${SSH_USER}@${SSH_HOST}:${CMD_B_REMOTE}" 2>&1` を実行し、`rc=$?` で ReturnCode を退避する
    - `log_rc "${rc}"` で詳細ログへ記録した後、RC≠0 の場合は転送元・転送先を含むエラーメッセージを `log_error()` で出力して `exit 1` する（E505）
    - 転送完了時は `log_info()` で転送完了メッセージを出力する
    - _要件: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 7.2, 7.4, 7.5_

  - [ ] 4.8 run_server_b 関数の実装
    - リモート実行開始ログを `log_info()` で出力する
    - `log_cmd "ssh -i ${SSH_KEY} ${SSH_USER}@${SSH_HOST} bash ${CMD_B_REMOTE}"` でコマンド文字列を詳細ログへ記録する
    - `ssh -i "${SSH_KEY}" "${SSH_USER}@${SSH_HOST}" bash "${CMD_B_REMOTE}" 2>&1` を実行し、`rc=$?` で ReturnCode を退避する
    - `log_rc "${rc}"` で詳細ログへ記録した後、RC≠0 の場合はエラーコード・実行コマンド・RC値を `log_error()` で出力して `exit 1` する（E506）
    - 正常完了時は `log_info()` でリモート実行完了メッセージを出力する
    - _要件: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 7.1, 7.3, 7.4, 7.5_

- [ ] 5. チェックポイント
  - 全テストが通過していることを確認する。不明点があればユーザーに確認する。

- [ ] 6. ログ出力・フォーマット検証テスト

  - [ ]* 6.1 プロパティテストの実装（Property 1：ログ出力フォーマット準拠）
    - **Property 1: ログ出力フォーマット準拠**
    - **Validates: 要件 8.2**
    - ASCII・マルチバイト・特殊文字を含むランダムな任意文字列をジェネレーターで生成し、`log_info()`・`log_error()`・`log_cmd()`・`log_rc()` を呼び出したとき、出力される各行が `\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[(INFO|ERROR|CMD|RC)\]` の正規表現にマッチすることを `release_all.sh` および `CommandB.sh` の両スクリプトで100回以上のイテレーションで検証する
    - _要件: 8.2_

  - [ ]* 6.2 ログファイル生成確認テスト
    - `release_all.sh` 実行後に `release_all_YYYYMMDDHHMMSS.log` および `release_all_detail_YYYYMMDDHHMMSS.log` が `/var/log/release/` に生成されていることを確認する
    - 各フェーズ（サーバA処理開始・完了、SCP転送開始・完了、SSHリモート実行開始・完了）のログメッセージが `LOG_FILE` に記録されていることを確認する
    - ログファイルの権限が `644` であることを確認する
    - _要件: 8.1, 8.3, 8.5_

- [ ] 7. 結合テスト・エラーハンドリング検証

  - [ ]* 7.1 正常フロー結合テスト
    - SSH/SCP モックスクリプト（`exit 0` を返す代替スクリプト）を用意し、`release_all.sh` の完全フロー（`init_log` → `check_params` → `check_ssh_connection` → `run_server_a` → `scp_to_server_b` → `run_server_b`）が順序通り実行されることを確認する
    - 全フェーズのログが `LOG_FILE` および `DETAIL_LOG` に記録されることを確認する
    - _要件: 1.1, 1.2, 1.3_

  - [ ]* 7.2 エラーハンドリング検証テスト
    - `SSH_HOST` 空文字で起動 → E501 エラー出力・`exit 1`・SCP/SSH 不実行を確認する
    - 存在しない秘密鍵パスで起動 → E502 エラー出力・`exit 1` を確認する
    - 疎通確認モックが RC≠0 を返す → E503 エラー出力・`exit 1`・SCP/SSH 不実行を確認する
    - `CommandA.sh` モックが `exit 1` を返す → E504 エラー出力・`exit 1`・SCP 不実行を確認する
    - SCP モックが RC≠0 を返す → E505 エラー出力・`exit 1`・SSH 不実行を確認する
    - SSH モックが RC≠0 を返す → E506 エラー出力・`exit 1` を確認する
    - _要件: 1.4, 2.3, 6.2, 7.1, 7.2, 7.3_

- [ ] 8. 最終チェックポイント
  - 全テストが通過していることを確認する。不明点があればユーザーに確認する。

---

## Notes

- `*` が付いたサブタスクはオプションであり、MVP（最小実行可能製品）としてスキップ可能
- 各タスクの要件番号は `requirements.md` の対応する受け入れ基準を参照
- 共通関数（`log_info`・`log_error`・`log_cmd`・`log_rc`・`check_rc`・`check_str`）の仕様は `CommandA.sh` の実装と完全一致させること
- SSH/SCP コマンドの ReturnCode は `rc=$?` で変数に退避してから `check_rc()` に渡すこと（要件 7.4）
- SSH/SCP エラー出力は `2>&1` でリダイレクトしてからログへ記録すること（要件 7.5）
- `SSH_HOST`・`SSH_USER`・`SSH_KEY` はシェルスクリプト内にハードコードしないこと（要件 10.1）
- パスワード・パスフレーズはログに記録しないこと（要件 10.4）
- プロパティベーステストは bash 向けの PBT フレームワーク（bats + 自作ジェネレーター）または Python の Hypothesis を使用し、最低100回のイテレーションを実施すること

---

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.2", "2.3"] },
    { "id": 2, "tasks": ["1.4", "2.4", "2.5", "2.6"] },
    { "id": 3, "tasks": ["1.5", "2.7", "4.1"] },
    { "id": 4, "tasks": ["4.2", "4.3"] },
    { "id": 5, "tasks": ["4.4", "4.5", "4.6"] },
    { "id": 6, "tasks": ["4.7", "4.8"] },
    { "id": 7, "tasks": ["6.1", "6.2", "7.1", "7.2"] }
  ]
}
```
