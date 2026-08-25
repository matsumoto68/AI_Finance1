#!/bin/bash
# ============================================================
# deploy_test.sh - 試験用資材配置シェル（単体試験・結合試験共通）
# CommandA.sh および試験データを Linux環境の所定ディレクトリへ配置する
# ============================================================

set -u

# --- 定数定義 ---
readonly SCRIPT_DIR="/opt/release/scripts"
readonly TEST_DATA_DIR="/tmp"
readonly SRC_MAIN="./CommandA.sh"
readonly SRC_DEPLOY="./deploy_CommandA.sh"
readonly SRC_TEST_DATA="./test_data.sh"

# ============================================================
# 配置元ファイル存在確認
# ============================================================
check_src() {
    local rc
    if [ ! -f "${SRC_MAIN}" ]; then
        echo "[ERROR] E901: 配置元ファイル不存在: ${SRC_MAIN}" >&2
        exit 1
    fi
    if [ ! -f "${SRC_DEPLOY}" ]; then
        echo "[ERROR] E901: 配置元ファイル不存在: ${SRC_DEPLOY}" >&2
        exit 1
    fi
    if [ ! -f "${SRC_TEST_DATA}" ]; then
        echo "[ERROR] E901: 試験データファイル不存在: ${SRC_TEST_DATA}" >&2
        exit 1
    fi
}

# ============================================================
# 配置先ディレクトリ作成（存在しない場合）
# ============================================================
make_dir() {
    local rc
    if [ ! -d "${SCRIPT_DIR}" ]; then
        mkdir -p "${SCRIPT_DIR}"
        rc=$?
        if [ "${rc}" -ne 0 ]; then
            echo "[ERROR] E902: 配置先ディレクトリ作成失敗: ${SCRIPT_DIR}" >&2
            exit 1
        fi
        echo "[INFO]  配置先ディレクトリを作成しました: ${SCRIPT_DIR}"
    fi
}

# ============================================================
# シェルスクリプトのコピー・権限付与
# ============================================================
deploy_scripts() {
    local rc

    # CommandA.sh のコピー
    cp "${SRC_MAIN}" "${SCRIPT_DIR}/CommandA.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E903: ファイルコピー失敗: ${SRC_MAIN} -> ${SCRIPT_DIR}/CommandA.sh" >&2
        exit 1
    fi
    chmod 755 "${SCRIPT_DIR}/CommandA.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E904: 実行権限付与失敗: ${SCRIPT_DIR}/CommandA.sh" >&2
        exit 1
    fi
    echo "[INFO]  配置完了: ${SCRIPT_DIR}/CommandA.sh (755)"

    # deploy_CommandA.sh のコピー
    cp "${SRC_DEPLOY}" "${SCRIPT_DIR}/deploy_CommandA.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E903: ファイルコピー失敗: ${SRC_DEPLOY} -> ${SCRIPT_DIR}/deploy_CommandA.sh" >&2
        exit 1
    fi
    chmod 755 "${SCRIPT_DIR}/deploy_CommandA.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E904: 実行権限付与失敗: ${SCRIPT_DIR}/deploy_CommandA.sh" >&2
        exit 1
    fi
    echo "[INFO]  配置完了: ${SCRIPT_DIR}/deploy_CommandA.sh (755)"
}

# ============================================================
# 試験データのコピー
# ============================================================
deploy_test_data() {
    local rc

    cp "${SRC_TEST_DATA}" "${TEST_DATA_DIR}/testfile.sh"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] E903: 試験データコピー失敗: ${SRC_TEST_DATA} -> ${TEST_DATA_DIR}/testfile.sh" >&2
        exit 1
    fi
    chmod 644 "${TEST_DATA_DIR}/testfile.sh"
    echo "[INFO]  試験データ配置完了: ${TEST_DATA_DIR}/testfile.sh"
}

# ============================================================
# 配置後確認
# ============================================================
verify() {
    local ng=0
    for f in "${SCRIPT_DIR}/CommandA.sh" "${SCRIPT_DIR}/deploy_CommandA.sh" "${TEST_DATA_DIR}/testfile.sh"; do
        if [ ! -f "${f}" ]; then
            echo "[ERROR] 配置確認失敗: ${f} が存在しません" >&2
            ng=$((ng + 1))
        fi
    done
    if [ "${ng}" -ne 0 ]; then
        echo "[ERROR] 配置確認で ${ng} 件の異常が発生しました" >&2
        exit 1
    fi
    echo "[INFO]  全ファイルの配置確認完了"
}

# ============================================================
# メイン処理
# ============================================================
main() {
    echo "[INFO]  deploy_test.sh 処理開始"
    check_src
    make_dir
    deploy_scripts
    deploy_test_data
    verify
    echo "[INFO]  deploy_test.sh 処理正常終了"
    exit 0
}

main
