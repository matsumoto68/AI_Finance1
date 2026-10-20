#!/bin/bash
# ============================================================
# release_all.sh - オーケストレーターシェル（複数サーバ一括制御）
# サーバA処理 → サーバBへSCP転送 → サーバBリモート実行を一括制御
# ============================================================

set -u

# --- 定数定義 ---
readonly LOG_DIR="/var/log/release"
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly LOG_FILE="${LOG_DIR}/release_all_${TIMESTAMP}.log"
readonly DETAIL_LOG="${LOG_DIR}/release_all_detail_${TIMESTAMP}.log"
readonly SCRIPT_DIR="/opt/release/scripts"
readonly COMMAND_A="${SCRIPT_DIR}/CommandA.sh"
readonly COMMAND_B="${SCRIPT_DIR}/CommandB.sh"
readonly REMOTE_SCRIPT_DIR="/opt/release/scripts"

# --- 接続情報（外部から取得） ---
SERVER_B_HOST=""
SERVER_B_USER=""
SERVER_B_KEY=""
readonly SSH_TIMEOUT=10

# ============================================================
# 共通関数
# ============================================================

# INFOログ出力
log_info() {
    local msg="$1"
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${ts}] [INFO]  ${msg}" | tee -a "${LOG_FILE}"
}

# ERRORログ出力
log_error() {
    local msg="$1"
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${ts}] [ERROR] ${msg}" | tee -a "${LOG_FILE}" >&2
}

# コマンドログ出力（詳細ログ）
log_cmd() {
    local cmd="$1"
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${ts}] [CMD]   ${cmd}" >> "${DETAIL_LOG}"
}

# ReturnCodeログ出力（詳細ログ）
log_rc() {
    local rc="$1"
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${ts}] [RC]    ReturnCode=${rc}" >> "${DETAIL_LOG}"
}

# ReturnCodeチェック: 期待値以外の場合エラー終了
# $1: 実際のRC  $2: 期待するRC  $3: エラーコード  $4: エラーメッセージ
check_rc() {
    local actual_rc="$1"
    local expected_rc="$2"
    local err_code="$3"
    local err_msg="$4"
    log_rc "${actual_rc}"
    if [ "${actual_rc}" -ne "${expected_rc}" ]; then
        log_error "${err_code}: ${err_msg} (RC=${actual_rc})"
        exit 1
    fi
}

# ============================================================
# 初期化処理
# ============================================================
init_log() {
    local rc
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}"
        rc=$?
        if [ "${rc}" -ne 0 ]; then
            echo "[ERROR] E001: ログディレクトリ作成失敗: ${LOG_DIR}" >&2
            exit 1
        fi
    fi
    if [ ! -w "${LOG_DIR}" ]; then
        echo "[ERROR] E001: ログディレクトリ書き込み権限なし: ${LOG_DIR}" >&2
        exit 1
    fi
    # ヘッダー出力
    {
        echo "========================================"
        echo " スクリプト名: release_all.sh"
        echo " 実行開始日時: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
    } | tee -a "${LOG_FILE}" >> "${DETAIL_LOG}"
}

# ============================================================
# 接続情報読み込み
# ============================================================
load_config() {
    log_info "接続情報読み込み 開始"

    # 実行時引数から接続情報を取得
    # 使用方法: bash release_all.sh <ホスト名> <ユーザー名> <秘密鍵パス>
    if [ $# -ge 1 ]; then
        SERVER_B_HOST="$1"
    fi
    if [ $# -ge 2 ]; then
        SERVER_B_USER="$2"
    fi
    if [ $# -ge 3 ]; then
        SERVER_B_KEY="$3"
    fi

    # 空値チェック
    if [ -z "${SERVER_B_HOST}" ]; then
        log_error "E504: 接続情報読み込み失敗 - ホスト名が未指定"
        exit 1
    fi
    if [ -z "${SERVER_B_USER}" ]; then
        log_error "E504: 接続情報読み込み失敗 - ユーザー名が未指定"
        exit 1
    fi
    if [ -z "${SERVER_B_KEY}" ]; then
        log_error "E504: 接続情報読み込み失敗 - 秘密鍵パスが未指定"
        exit 1
    fi

    # 秘密鍵ファイル存在確認
    if [ ! -f "${SERVER_B_KEY}" ]; then
        log_error "E505: 秘密鍵ファイル不存在: ${SERVER_B_KEY}"
        exit 1
    fi

    log_info "接続情報読み込み完了 (HOST=${SERVER_B_HOST}, USER=${SERVER_B_USER})"
}

# ============================================================
# 事前チェック処理
# ============================================================
check_env() {
    log_info "事前チェック 開始"

    # CommandA.sh 存在確認
    if [ ! -f "${COMMAND_A}" ]; then
        log_error "E506: CommandA.sh 不存在: ${COMMAND_A}"
        exit 1
    fi
    log_info "CommandA.sh 存在確認完了: ${COMMAND_A}"

    # CommandB.sh 存在確認
    if [ ! -f "${COMMAND_B}" ]; then
        log_error "E507: CommandB.sh 不存在: ${COMMAND_B}"
        exit 1
    fi
    log_info "CommandB.sh 存在確認完了: ${COMMAND_B}"

    # サーバBへのSSH接続確認
    local out rc
    log_cmd "ssh -o ConnectTimeout=${SSH_TIMEOUT} -o StrictHostKeyChecking=no -i ${SERVER_B_KEY} ${SERVER_B_USER}@${SERVER_B_HOST} \"echo ok\""
    out=$(ssh -o ConnectTimeout="${SSH_TIMEOUT}" -o StrictHostKeyChecking=no -i "${SERVER_B_KEY}" "${SERVER_B_USER}@${SERVER_B_HOST}" "echo ok" 2>&1)
    rc=$?
    log_rc "${rc}"

    if [ "${rc}" -ne 0 ] || ! echo "${out}" | grep -q "ok"; then
        log_error "E500: SSH接続確認失敗 - サーバB (RC=${rc})"
        exit 1
    fi
    log_info "サーバB SSH接続確認完了"

    log_info "事前チェック 完了"
}

# ============================================================
# サーバA処理（CommandA.sh実行）
# ============================================================
exec_server_a() {
    local rc
    log_info "サーバA処理 開始"

    log_cmd "bash ${COMMAND_A}"
    bash "${COMMAND_A}"
    rc=$?
    log_rc "${rc}"

    if [ "${rc}" -ne 0 ]; then
        log_error "E502: サーバA処理失敗 - CommandA.sh (RC=${rc})"
        log_info "サーバB処理はスキップします"
        exit 1
    fi

    log_info "サーバA処理 完了"
}

# ============================================================
# サーバBへの資材転送（SCP）
# ============================================================
transfer_to_server_b() {
    local rc
    log_info "サーバBへの資材転送 開始"

    log_cmd "scp -o StrictHostKeyChecking=no -i ${SERVER_B_KEY} ${COMMAND_B} ${SERVER_B_USER}@${SERVER_B_HOST}:${REMOTE_SCRIPT_DIR}/"
    scp -o StrictHostKeyChecking=no -i "${SERVER_B_KEY}" "${COMMAND_B}" "${SERVER_B_USER}@${SERVER_B_HOST}:${REMOTE_SCRIPT_DIR}/"
    rc=$?
    log_rc "${rc}"

    if [ "${rc}" -ne 0 ]; then
        log_error "E501: SCP転送失敗 - CommandB.sh → サーバB (RC=${rc})"
        exit 1
    fi

    log_info "サーバBへの資材転送 完了"
}

# ============================================================
# サーバBリモート実行（SSH）
# ============================================================
exec_server_b() {
    local out rc
    log_info "サーバBリモート実行 開始"

    log_cmd "ssh -o StrictHostKeyChecking=no -i ${SERVER_B_KEY} ${SERVER_B_USER}@${SERVER_B_HOST} \"sudo bash ${REMOTE_SCRIPT_DIR}/CommandB.sh\""
    out=$(ssh -o StrictHostKeyChecking=no -i "${SERVER_B_KEY}" "${SERVER_B_USER}@${SERVER_B_HOST}" "sudo bash ${REMOTE_SCRIPT_DIR}/CommandB.sh" 2>&1)
    rc=$?
    log_rc "${rc}"

    if [ "${rc}" -ne 0 ]; then
        log_error "E503: サーバBリモート実行失敗 - CommandB.sh (RC=${rc})"
        # サーバBのエラー出力をオーケストレーターログに記録
        log_info "--- サーバB出力 開始 ---"
        echo "${out}" | while IFS= read -r line; do
            log_info "  ${line}"
        done
        log_info "--- サーバB出力 終了 ---"
        exit 1
    fi

    log_info "サーバBリモート実行 完了"
}

# ============================================================
# メイン処理
# ============================================================
main() {
    init_log
    log_info "release_all.sh 処理開始"
    load_config "$@"
    check_env
    exec_server_a
    transfer_to_server_b
    exec_server_b
    log_info "release_all.sh 処理正常終了"
    exit 0
}

main "$@"
