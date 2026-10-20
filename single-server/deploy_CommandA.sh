#!/bin/bash
# ============================================================
# deploy_CommandA.sh - 資材配置シェル
# CommandA.sh を Linux環境の所定ディレクトリへ配置する
# ============================================================

set -u

# --- 定数定義 ---
readonly SCRIPT_DIR="/opt/release/scripts"
readonly SRC_FILE="./CommandA.sh"

# ============================================================
# 配置元ファイル存在確認
# ============================================================
check_src() {
    if [ ! -f "${SRC_FILE}" ]; then
        echo "[ERROR] E901: 配置元ファイル不存在: ${SRC_FILE}" >&2
        exit 1
    fi
}

# ============================================================
# 配置先ディレクトリ作成（存在しない場合）
# ============================================================
make_dir() {
    if [ ! -d "${SCRIPT_DIR}" ]; then
        mkdir -p "${SCRIPT_DIR}"
        if [ $? -ne 0 ]; then
            echo "[ERROR] E902: 配置先ディレクトリ作成失敗: ${SCRIPT_DIR}" >&2
            exit 1
        fi
        echo "[INFO]  配置先ディレクトリを作成しました: ${SCRIPT_DIR}"
    fi
}

# ============================================================
# ファイルコピー
# ============================================================
copy_file() {
    cp "${SRC_FILE}" "${SCRIPT_DIR}/CommandA.sh"
    if [ $? -ne 0 ]; then
        echo "[ERROR] E903: ファイルコピー失敗: ${SRC_FILE} -> ${SCRIPT_DIR}/CommandA.sh" >&2
        exit 1
    fi
}

# ============================================================
# 実行権限付与
# ============================================================
set_permission() {
    chmod 755 "${SCRIPT_DIR}/CommandA.sh"
    if [ $? -ne 0 ]; then
        echo "[ERROR] E904: 実行権限付与失敗: ${SCRIPT_DIR}/CommandA.sh" >&2
        exit 1
    fi
}

# ============================================================
# メイン処理
# ============================================================
main() {
    echo "[INFO]  deploy_CommandA.sh 処理開始"
    check_src
    make_dir
    copy_file
    set_permission
    echo "[INFO]  配置完了: ${SCRIPT_DIR}/CommandA.sh"
    exit 0
}

main
