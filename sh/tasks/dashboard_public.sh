#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

STATE_DIR="${AUTOCLAW_STATE:-$(pwd)/sh/state}"
mkdir -p "$STATE_DIR"
FLAG="$STATE_DIR/dashboard_public_ok.json"
TS="$(date +%Y%m%d-%H%M%S)"

PORT="${AUTOCLAW_PORT:-8787}"
BIND="${AUTOCLAW_BIND:-127.0.0.1}"
ROOT_DIR="${AUTOCLAW_ROOT:-$(pwd)}"

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

log "dashboard-public: 시작 — VPS 주소로 대시보드(:${PORT}) 접속 허용 상태를 점검/적용한다."

if is_wsl; then
  log "dashboard-public: WSL 환경 감지 → VPS 공인 IP 공개 단계는 스킵"
  cat > "$FLAG" <<JSON
{ "ok": true, "checkedAt": "${TS}", "port": ${PORT}, "bind": "${BIND}", "wsl": true }
JSON
  log "dashboard-public: flag written: $FLAG"
  log "dashboard-public: 완료"
  exit 0
fi

if command -v ufw >/dev/null 2>&1; then
  if sudo -n true >/dev/null 2>&1; then
    UFW_STATUS="$(sudo -n ufw status 2>/dev/null || true)"
    if echo "$UFW_STATUS" | head -n1 | grep -qi "inactive"; then
      log "dashboard-public: ufw 비활성 상태 → 포트 규칙 추가 없이 진행"
    else
      log "dashboard-public: ufw ${PORT}/tcp 허용 규칙 적용"
      sudo -n ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
      sudo -n ufw status 2>/dev/null | sed 's/^/[ufw] /' || true
    fi
  else
    log "dashboard-public: sudo 비대화형 권한이 없어 ufw 자동 설정은 건너뜀"
  fi
else
  log "dashboard-public: ufw 미설치 → 방화벽 규칙 단계 스킵"
fi

if command -v ss >/dev/null 2>&1; then
  log "dashboard-public: ${PORT} 포트 리스닝 점검(ss)"
  ss -ltn 2>/dev/null | awk -v p=":${PORT}" '$4 ~ p {print "[ss] " $0}' || true
elif command -v lsof >/dev/null 2>&1; then
  log "dashboard-public: ${PORT} 포트 리스닝 점검(lsof)"
  lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN | sed 's/^/[lsof] /' || true
fi

if [[ "$BIND" != "0.0.0.0" ]]; then
  log "dashboard-public: 현재 대시보드 bind=${BIND} (원격 접속 제한)"
  log "dashboard-public: 아래 명령으로 재실행하면 VPS 주소로 접속할 수 있다."
  log "dashboard-public:   cd ${ROOT_DIR}"
  log "dashboard-public:   AUTOCLAW_BIND=0.0.0.0 AUTOCLAW_PORT=${PORT} node server/index.js"
  log "dashboard-public: 현재 실행 중인 대시보드를 Ctrl+C로 종료 후 위 명령으로 다시 실행해 주세요."
  log "dashboard-public: ERROR: bind가 loopback 상태라 단계를 완료 처리할 수 없음"
  exit 1
fi

cat > "$FLAG" <<JSON
{ "ok": true, "checkedAt": "${TS}", "port": ${PORT}, "bind": "${BIND}", "wsl": false }
JSON

log "dashboard-public: flag written: $FLAG"
log "dashboard-public: 완료"
