#!/bin/bash
# ============================================================
# CommandA.sh - リリース作業自動化シェルスクリプト
# 対象: test_data_CommandA.xlsx 記載の全25コマンドを自動実行
# ============================================================

set -u

# --- 定数定義 ---
readonly LOG_DIR="/var/log/release"
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly LOG_FILE="${LOG_DIR}/CommandA_${TIMESTAMP}.log"
readonly DETAIL_LOG="${LOG_DIR}/CommandA_detail_${TIMESTAMP}.log"
readonly WORK_DIR="/tmp/testdir"
readonly WORK_DIR_BK="/tmp/testdir_bk"
readonly TARGET_FILE="${WORK_DIR}/test.txt"
readonly DATA_FILE="${WORK_DIR}/data.txt"
readonly DATA_BK_FILE="${WORK_DIR}/data_bk.txt"
readonly RENAMED_FILE="${WORK_DIR}/renamed.txt"
readonly TARGET_SH="/tmp/testfile.sh"
readonly SERVICE_NAME="nginx"

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

# 出力文字列チェック
# $1: コマンド出力  $2: 確認文字列  $3: must_contain or must_not_contain
# $4: エラーコード  $5: エラーメッセージ
check_str() {
    local output="$1"
    local keyword="$2"
    local mode="$3"
    local err_code="$4"
    local err_msg="$5"
    if [ "${mode}" = "must_contain" ]; then
        if ! echo "${output}" | grep -q "${keyword}"; then
            log_error "${err_code}: ${err_msg}"
            exit 1
        fi
    elif [ "${mode}" = "must_not_contain" ]; then
        if echo "${output}" | grep -q "${keyword}"; then
            log_error "${err_code}: ${err_msg}"
            exit 1
        fi
    fi
}

# ============================================================
# 初期化処理
# ============================================================
init_log() {
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}"
        if [ $? -ne 0 ]; then
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
        echo " スクリプト名: CommandA.sh"
        echo " 実行開始日時: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
    } | tee -a "${LOG_FILE}" >> "${DETAIL_LOG}"
}

# ============================================================
# 事前チェック処理
# ============================================================
check_env() {
    log_info "事前チェック開始"
    # systemctl コマンド存在確認
    if ! command -v systemctl > /dev/null 2>&1; then
        log_error "E002: systemctl コマンド不存在"
        exit 1
    fi
    log_info "事前チェック完了"
}

# ============================================================
# ディレクトリ操作処理
# ============================================================
proc_dir() {
    log_info "ディレクトリ操作処理 開始"

    # ステップ1: ディレクトリ作成（正常）
    log_cmd "mkdir ${WORK_DIR}"
    mkdir "${WORK_DIR}"
    check_rc $? 0 "E101" "ディレクトリ作成失敗: ${WORK_DIR}"
    log_info "ディレクトリ作成完了: ${WORK_DIR}"

    # ステップ2: ディレクトリ作成（既存・エラー確認）
    log_cmd "mkdir ${WORK_DIR} 2>&1"
    out=$(mkdir "${WORK_DIR}" 2>&1)
    log_rc $?
    check_str "${out}" "File exists" "must_not_contain" "E101" "ディレクトリ作成失敗（既存）: ${WORK_DIR}"
    log_info "ディレクトリ作成（既存）エラー確認完了"

    # ステップ3: ディレクトリ作成（権限なし・エラー確認）
    log_cmd "mkdir /root/noperm 2>&1"
    out=$(mkdir /root/noperm 2>&1)
    log_rc $?
    check_str "${out}" "Permission denied" "must_not_contain" "E102" "ディレクトリ作成失敗（権限なし）: /root/noperm"
    log_info "ディレクトリ作成（権限なし）エラー確認完了"

    # ステップ4: ディレクトリ移動（正常）
    log_cmd "cd ${WORK_DIR}"
    cd "${WORK_DIR}"
    check_rc $? 0 "E103" "ディレクトリ移動失敗: ${WORK_DIR}"
    log_info "ディレクトリ移動完了: ${WORK_DIR}"

    # ステップ5: ディレクトリ移動（不存在・エラー確認）
    log_cmd "cd /tmp/notexist 2>&1"
    out=$(cd /tmp/notexist 2>&1)
    log_rc $?
    check_str "${out}" "No such file or directory" "must_not_contain" "E103" "ディレクトリ移動失敗（不存在）: /tmp/notexist"
    log_info "ディレクトリ移動（不存在）エラー確認完了"

    # ステップ6: ディレクトリコピー
    log_cmd "cp -r ${WORK_DIR} ${WORK_DIR_BK}"
    cp -r "${WORK_DIR}" "${WORK_DIR_BK}"
    check_rc $? 0 "E104" "ディレクトリコピー失敗: ${WORK_DIR} -> ${WORK_DIR_BK}"
    log_info "ディレクトリコピー完了: ${WORK_DIR_BK}"

    # ステップ7: ディレクトリ削除（空）
    log_cmd "rmdir ${WORK_DIR_BK}"
    rmdir "${WORK_DIR_BK}"
    check_rc $? 0 "E105" "ディレクトリ削除失敗（空）: ${WORK_DIR_BK}"
    log_info "ディレクトリ削除（空）完了: ${WORK_DIR_BK}"

    # ステップ8: ディレクトリ削除（非空・エラー確認）
    log_cmd "rmdir ${WORK_DIR} 2>&1"
    out=$(rmdir "${WORK_DIR}" 2>&1)
    log_rc $?
    check_str "${out}" "Directory not empty" "must_not_contain" "E105" "ディレクトリ削除失敗（非空）: ${WORK_DIR}"
    log_info "ディレクトリ削除（非空）エラー確認完了"

    # ステップ9: ディレクトリ強制削除
    log_cmd "rm -rf ${WORK_DIR}"
    rm -rf "${WORK_DIR}"
    check_rc $? 0 "E106" "ディレクトリ強制削除失敗: ${WORK_DIR}"
    log_info "ディレクトリ強制削除完了: ${WORK_DIR}"

    log_info "ディレクトリ操作処理 完了"
}

# ============================================================
# ファイル操作処理（proc_dir 実行後に再度 WORK_DIR を作成して実施）
# ============================================================
proc_file() {
    log_info "ファイル操作処理 開始"

    # ファイル操作用にWORK_DIRを再作成
    mkdir -p "${WORK_DIR}"

    # ステップ1: ファイル作成（touch）
    log_cmd "touch ${TARGET_FILE}"
    touch "${TARGET_FILE}"
    check_rc $? 0 "E201" "ファイル作成失敗（touch）: ${TARGET_FILE}"
    log_info "ファイル作成（touch）完了: ${TARGET_FILE}"

    # ステップ2: ファイル作成（echo）
    log_cmd "echo hello > ${DATA_FILE}"
    echo hello > "${DATA_FILE}"
    check_rc $? 0 "E202" "ファイル作成失敗（echo）: ${DATA_FILE}"
    log_info "ファイル作成（echo）完了: ${DATA_FILE}"

    # ステップ3: ファイル内容確認
    log_cmd "cat ${DATA_FILE}"
    out=$(cat "${DATA_FILE}")
    check_rc $? 0 "E203" "ファイル内容確認失敗: ${DATA_FILE}"
    check_str "${out}" "hello" "must_contain" "E203" "ファイル内容確認失敗（hello が含まれない）: ${DATA_FILE}"
    log_info "ファイル内容確認完了: ${DATA_FILE}"

    # ステップ4: ファイルコピー
    log_cmd "cp ${DATA_FILE} ${DATA_BK_FILE}"
    cp "${DATA_FILE}" "${DATA_BK_FILE}"
    check_rc $? 0 "E204" "ファイルコピー失敗: ${DATA_FILE} -> ${DATA_BK_FILE}"
    log_info "ファイルコピー完了: ${DATA_BK_FILE}"

    # ステップ5: ファイルコピー（上書き）
    log_cmd "cp -f ${DATA_FILE} ${DATA_BK_FILE}"
    cp -f "${DATA_FILE}" "${DATA_BK_FILE}"
    check_rc $? 0 "E204" "ファイルコピー（上書き）失敗: ${DATA_FILE} -> ${DATA_BK_FILE}"
    log_info "ファイルコピー（上書き）完了: ${DATA_BK_FILE}"

    # ステップ6: ファイル移動（リネーム）
    log_cmd "mv ${TARGET_FILE} ${RENAMED_FILE}"
    mv "${TARGET_FILE}" "${RENAMED_FILE}"
    check_rc $? 0 "E205" "ファイル移動（リネーム）失敗: ${TARGET_FILE} -> ${RENAMED_FILE}"
    log_info "ファイル移動（リネーム）完了: ${RENAMED_FILE}"

    # ステップ7: ファイル削除
    log_cmd "rm ${DATA_BK_FILE}"
    rm "${DATA_BK_FILE}"
    check_rc $? 0 "E206" "ファイル削除失敗: ${DATA_BK_FILE}"
    log_info "ファイル削除完了: ${DATA_BK_FILE}"

    # ステップ8: ファイル削除（不存在・エラー確認）
    log_cmd "rm /tmp/testdir/notexist.txt 2>&1"
    out=$(rm /tmp/testdir/notexist.txt 2>&1)
    log_rc $?
    check_str "${out}" "No such file or directory" "must_not_contain" "E206" "ファイル削除失敗（不存在）: /tmp/testdir/notexist.txt"
    log_info "ファイル削除（不存在）エラー確認完了"

    log_info "ファイル操作処理 完了"
}

# ============================================================
# サービス操作処理
# ============================================================
proc_service() {
    log_info "サービス操作処理 開始"

    # ステップ1: サービス起動
    log_cmd "systemctl start ${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"
    check_rc $? 0 "E301" "サービス起動失敗: ${SERVICE_NAME}"
    log_info "サービス起動完了: ${SERVICE_NAME}"

    # ステップ2: サービス起動失敗確認（エラーメッセージチェック）
    log_cmd "systemctl start ${SERVICE_NAME} 2>&1"
    out=$(systemctl start "${SERVICE_NAME}" 2>&1)
    log_rc $?
    check_str "${out}" "Failed" "must_not_contain" "E301" "サービス起動失敗（Failed検出）: ${SERVICE_NAME}"
    log_info "サービス起動失敗確認完了"

    # ステップ3: 起動確認
    log_cmd "systemctl is-active ${SERVICE_NAME}"
    out=$(systemctl is-active "${SERVICE_NAME}")
    check_rc $? 0 "E302" "サービス起動確認失敗: ${SERVICE_NAME}"
    check_str "${out}" "active" "must_contain" "E302" "サービス起動確認失敗（active でない）: ${SERVICE_NAME}"
    log_info "起動確認完了: ${SERVICE_NAME}"

    # ステップ4: サービス停止
    log_cmd "systemctl stop ${SERVICE_NAME}"
    systemctl stop "${SERVICE_NAME}"
    check_rc $? 0 "E303" "サービス停止失敗: ${SERVICE_NAME}"
    log_info "サービス停止完了: ${SERVICE_NAME}"

    # ステップ5: 停止確認
    log_cmd "systemctl is-active ${SERVICE_NAME}"
    out=$(systemctl is-active "${SERVICE_NAME}")
    log_rc $?
    check_str "${out}" "inactive" "must_contain" "E304" "サービス停止確認失敗（inactive でない）: ${SERVICE_NAME}"
    log_info "停止確認完了: ${SERVICE_NAME}"

    # ステップ6: サービス状態確認
    log_cmd "systemctl status ${SERVICE_NAME}"
    out=$(systemctl status "${SERVICE_NAME}" 2>&1)
    log_rc $?
    check_str "${out}" "Active" "must_contain" "E305" "サービス状態確認失敗（Active が含まれない）: ${SERVICE_NAME}"
    log_info "サービス状態確認完了: ${SERVICE_NAME}"

    log_info "サービス操作処理 完了"
}

# ============================================================
# 一覧表示・権限変更処理
# ============================================================
proc_misc() {
    log_info "一覧表示・権限変更処理 開始"

    # ステップ1: 一覧表示
    log_cmd "ls -la /tmp"
    out=$(ls -la /tmp)
    check_rc $? 0 "E401" "一覧表示失敗: /tmp"
    check_str "${out}" "total" "must_contain" "E401" "一覧表示失敗（total が含まれない）: /tmp"
    log_info "一覧表示完了: /tmp"

    # ステップ2: ファイル権限変更
    log_cmd "chmod 755 ${TARGET_SH}"
    chmod 755 "${TARGET_SH}"
    check_rc $? 0 "E402" "ファイル権限変更失敗: ${TARGET_SH}"
    log_info "ファイル権限変更完了: ${TARGET_SH} -> 755"

    log_info "一覧表示・権限変更処理 完了"
}

# ============================================================
# メイン処理
# ============================================================
main() {
    init_log
    log_info "CommandA.sh 処理開始"
    check_env
    proc_dir
    proc_file
    proc_service
    proc_misc
    log_info "CommandA.sh 処理正常終了"
    exit 0
}

main
