#!/bin/bash
# ============================================================
# deploy_multi.sh - 複数サーバ向け資材配置シェル
# CommandA.sh・CommandB.sh・release_all.sh を所定ディレクトリへ配置
# ============================================================

set -u

# --- 定数定義 ---
readonly SCRIPT_DIR="/opt/release/scripts"
readonly SRC_COMMAND_A="./CommandA.sh"
readonly SRC_COMMAND_B="./CommandB.sh"
readonly SRC_RELEASE_ALL="./release_all.sh"

# ============================================================
# 配置元ファイル存在確認
# ============================================================
check_src() {
    echo "[INFO] 配置元ファイル存在確認 開始"

    if [ ! -f "${SRC_COMMAND_A}" ]; then
        echo "[ERROR] E901: 配置元ファイル不存在（CommandA.sh）: ${SRC_COMMAND_A}" >&2
        exit 1
    fi
    echo "[INFO] CommandA.sh 存在確認完了: ${SRC_COMMAND_A}"

    if [ ! -f "${SRC_COMMAND_B}" ]; then
        echo "[ERROR] E905: 配置元ファイル不存在（CommandB.sh）: ${SRC_COMMAND_B}" >&2
        exit 1
    fi
    echo "[INFO] CommandB.sh 存在確認完了: ${SRC_COMMAND_B}"

    if [ ! -f "${SRC_RELEASE_ALL}" ]; then
        echo "[ERROR] E906: 配置元ファイル不存在（release_all.sh）: ${SRC_RELEASE_ALL}" >&2
        exit 1
    fi
    echo "[INFO] release_all.sh 存在確認完了: ${SRC_RELEASE_ALL}"

    echo "[INFO] 配置元ファイル存在確認 完了"
}

# ============================================================
# 配置先ディレクトリ作成
# ============================================================
make_dir() {
    local rc
    echo "[INFO] 配置先ディレクトリ確認 開始"

    if [ ! -d "${SCRIPT_DIR}" ]; then
        echo "[INFO] ディレクトリ作成: ${SCRIPT_DIR}"
        mkdir -p "${SCRIPT_DIR}"
        rc=$?
        if [ "${rc}" -ne 0 ]; then
            echo "[ERROR] E902: 配置先ディレクトリ作成失敗: ${SCRIPT_DIR} (RC=${rc})" >&2
            exit 1
        fi
    fi

    echo "[INFO] 配置先ディレクトリ確認 完了: ${SCRIPT_DIR}"
}

# ============================================================
# ファイルコピー
# ============================================================
copy_files() {
    local rc
    echo "[INFO] ファイルコピー 開始"

    # CommandA.sh
    cp "${SRC_COMMAND_A}" "${SCRIPT_DIR}/CommandA.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E903: ファイルコピー失敗 - CommandA.sh (RC=${rc})" >&2
        exit 1
    fi
    echo "[INFO] コピー完了: ${SCRIPT_DIR}/CommandA.sh"

    # CommandB.sh
    cp "${SRC_COMMAND_B}" "${SCRIPT_DIR}/CommandB.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E903: ファイルコピー失敗 - CommandB.sh (RC=${rc})" >&2
        exit 1
    fi
    echo "[INFO] コピー完了: ${SCRIPT_DIR}/CommandB.sh"

    # release_all.sh
    cp "${SRC_RELEASE_ALL}" "${SCRIPT_DIR}/release_all.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E903: ファイルコピー失敗 - release_all.sh (RC=${rc})" >&2
        exit 1
    fi
    echo "[INFO] コピー完了: ${SCRIPT_DIR}/release_all.sh"

    echo "[INFO] ファイルコピー 完了"
}

# ============================================================
# 実行権限付与
# ============================================================
set_permission() {
    local rc
    echo "[INFO] 実行権限付与 開始"

    # CommandA.sh
    chmod 755 "${SCRIPT_DIR}/CommandA.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E904: 実行権限付与失敗 - CommandA.sh (RC=${rc})" >&2
        exit 1
    fi

    # CommandB.sh
    chmod 755 "${SCRIPT_DIR}/CommandB.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E904: 実行権限付与失敗 - CommandB.sh (RC=${rc})" >&2
        exit 1
    fi

    # release_all.sh
    chmod 755 "${SCRIPT_DIR}/release_all.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E904: 実行権限付与失敗 - release_all.sh (RC=${rc})" >&2
        exit 1
    fi

    echo "[INFO] 実行権限付与 完了"
}

# ============================================================
# メイン処理
# ============================================================
main() {
    echo "========================================"
    echo " deploy_multi.sh - 資材配置開始"
    echo " 実行日時: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"

    check_src
    make_dir
    copy_files
    set_permission

    echo "========================================"
    echo " 配置完了: ${SCRIPT_DIR}"
    echo "   - CommandA.sh"
    echo "   - CommandB.sh"
    echo "   - release_all.sh"
    echo "========================================"
    exit 0
}

main
