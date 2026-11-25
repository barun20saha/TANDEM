#!/usr/bin/env bash
# Runs all Stage A local verification checks with clear PASS/FAIL output and saved logs.
# Never swallows errors or fakes passes when a tool is missing.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence"
DATE_TAG="$(date +%Y-%m-%d)"
mkdir -p "${EVIDENCE_DIR}"

for extra in /tmp/tools/go/bin /tmp/tools/flutter/bin /tmp/tools; do
    if [[ -d "${extra}" && ":${PATH}:" != *":${extra}:"* ]]; then
        export PATH="${extra}:${PATH}"
    fi
done

export GOCACHE="${GOCACHE:-/tmp/gocache}"
export HOME="${HOME:-/tmp/flutter-home}"
export PUB_CACHE="${PUB_CACHE:-/tmp/pub_cache}"
mkdir -p "${GOCACHE}" /tmp/flutter-home

PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

run_step() {
    local label="$1"
    local log_file="$2"
    shift 2
    echo ">>> Running: ${label}"
    if "$@" >"${log_file}" 2>&1; then
        echo "PASS: ${label} (log: ${log_file})"
        RESULTS+=("PASS | ${label}")
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: ${label} (see ${log_file})"
        tail -n 25 "${log_file}" || true
        RESULTS+=("FAIL | ${label}")
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

require_tool() {
    local bin="$1"
    if ! command -v "${bin}" >/dev/null 2>&1; then
        echo "FAIL: ${bin} not found"
        RESULTS+=("FAIL | tool ${bin} missing")
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
    return 0
}

# Pre-flight tool checks
require_tool go || true
require_tool syncthing || true
require_tool flutter || true
require_tool python3 || true
require_tool ss || true

if command -v go >/dev/null 2>&1; then
    run_step "go vet (core)" "${EVIDENCE_DIR}/verify-go-vet-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/core' && go vet ./..."

    run_step "go build (core)" "${EVIDENCE_DIR}/verify-go-build-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/core' && go build ./..."

    run_step "go test -race (core)" "${EVIDENCE_DIR}/verify-go-race-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/core' && CGO_ENABLED=1 go test -race -count=1 ./..."

    run_step "OpenAPI contract & security tests (core/api)" "${EVIDENCE_DIR}/verify-contract-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/core' && go test -v -count=1 -run 'TestOpenAPIContractAndAuthParity|TestSecurity_' ./api"
fi

if command -v go >/dev/null 2>&1 && command -v syncthing >/dev/null 2>&1; then
    run_step "WS1 E2E suite (tests/e2e)" "${EVIDENCE_DIR}/verify-e2e-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/tests' && go test -v -count=1 -timeout 10m ./e2e"

    run_step "Live tandemd boot + ss -lntup port check" "${EVIDENCE_DIR}/verify-ports-${DATE_TAG}.log" \
        bash -c "
            set -euo pipefail
            TMP_BIN=\$(mktemp /tmp/tandemd-verify-XXXXXX)
            TMP_CFG=\$(mktemp -d /tmp/tandem-verify-cfg-XXXXXX)
            trap 'rm -rf \"\${TMP_BIN}\" \"\${TMP_CFG}\"' EXIT
            (cd '${REPO_ROOT}/core' && go build -o \"\${TMP_BIN}\" ./cmd/tandemd)
            \"\${TMP_BIN}\" -config \"\${TMP_CFG}\" -bind 127.0.0.1:18385 -sync-port 24200 -discovery-port 24127 -engine-gui 127.0.0.1:18384 -global-discovery=false -relays=false -nat=false >\"\${TMP_CFG}/daemon.log\" 2>&1 &
            PID=\$!
            trap 'kill \"\${PID}\" 2>/dev/null || true; wait \"\${PID}\" 2>/dev/null || true; rm -rf \"\${TMP_BIN}\" \"\${TMP_CFG}\"' EXIT
            for _ in \$(seq 1 40); do
                if [[ -s \"\${TMP_CFG}/api.key\" ]] && ss -lntu | grep -q ':18385' && ss -lntu | grep -q ':24200' && ss -lnu | grep -q ':24127'; then
                    break
                fi
                sleep 0.25
            done
            ss -lntup 2>&1 | grep -E '18385|24200|24127'
            ss -lnt | grep -q ':18385'
            ss -lnt | grep -q ':24200'
            ss -lnu | grep -q ':24200'
            ss -lnu | grep -q ':24127'
            KEY=\$(cat \"\${TMP_CFG}/api.key\")
            python3 -c \"import urllib.request, json; req = urllib.request.Request('http://127.0.0.1:18385/api/v1/health', headers={'Authorization': 'Bearer ' + '''\${KEY}'''}); data = json.loads(urllib.request.urlopen(req, timeout=5).read().decode()); assert data['engineReady'] and data['syncPortOpen'] and data['discoveryWorks'], data; print(json.dumps(data))\"
        "
fi

if command -v python3 >/dev/null 2>&1; then
    run_step "Design token, contrast & fake-data audit" "${EVIDENCE_DIR}/verify-design-audit-${DATE_TAG}.log" \
        python3 "${REPO_ROOT}/design/audit.py"
fi

if command -v flutter >/dev/null 2>&1; then
    FLUTTER_HOME_ENV="/tmp/flutter-home"
    if [[ -w "${HOME}" ]]; then
        FLUTTER_HOME_ENV="${HOME}"
    fi
    run_step "Flutter analyze" "${EVIDENCE_DIR}/verify-flutter-analyze-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/app' && HOME='${FLUTTER_HOME_ENV}' PUB_CACHE='${PUB_CACHE}' flutter analyze --no-pub --no-fatal-infos"

    run_step "Flutter test suite" "${EVIDENCE_DIR}/verify-flutter-test-${DATE_TAG}.log" \
        bash -c "cd '${REPO_ROOT}/app' && HOME='${FLUTTER_HOME_ENV}' PUB_CACHE='${PUB_CACHE}' flutter test --no-pub --reporter expanded"
fi

echo ""
echo "================ VERIFY_ALL SUMMARY ================"
for line in "${RESULTS[@]}"; do
    echo "  ${line}"
done
echo "Total: ${PASS_COUNT} passed, ${FAIL_COUNT} failed."
echo "===================================================="

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    exit 1
fi
