#!/usr/bin/env bash
# notify_push.sh —— 一条消息推到多个通道（填哪个通哪个）
#
# 用法: ./notify_push.sh "标题" "正文"
# 输出: channels_sent=N（成功发出的通道数）
#
# 配置：优先读 ~/.hermes/scripts/notify.conf，其次读本脚本同目录的 notify.conf
#       文件权限务必 600（里面有推送密钥）

TITLE="${1:-告警}"
BODY="${2:-}"
HERE=$(cd "$(dirname "$0")" && pwd)

if [ -f "$HOME/.hermes/scripts/notify.conf" ]; then
  CONF="$HOME/.hermes/scripts/notify.conf"
elif [ -f "$HERE/notify.conf" ]; then
  CONF="$HERE/notify.conf"
else
  CONF=""
fi
[ -n "$CONF" ] && { set -a; . "$CONF"; set +a; }

sent=0

# 1) macOS 本地通知（零配置，非 macOS 自动跳过）
if [ "${MACOS_NOTIFY:-1}" = "1" ] && command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$(printf '%s' "$BODY" | head -c 180)\" with title \"$(printf '%s' "$TITLE")\" sound name \"Glass\"" >/dev/null 2>&1 && sent=$((sent+1))
fi

# 2) Server酱（微信）：https://sct.ftqq.com 扫码取 SendKey
if [ -n "${SERVERCHAN_KEY:-}" ]; then
  curl -sS --max-time 15 -X POST "https://sctapi.ftqq.com/${SERVERCHAN_KEY}.send" \
    --data-urlencode "title=${TITLE}" --data-urlencode "desp=${BODY}" >/dev/null 2>&1 && sent=$((sent+1))
fi

# 3) PushPlus（微信）：https://www.pushplus.plus 扫码取 token
if [ -n "${PUSHPLUS_TOKEN:-}" ]; then
  curl -sS --max-time 15 -X POST "https://www.pushplus.plus/send" \
    -H 'Content-Type: application/json' \
    -d "{\"token\":\"${PUSHPLUS_TOKEN}\",\"title\":\"${TITLE}\",\"content\":\"${BODY}\"}" >/dev/null 2>&1 && sent=$((sent+1))
fi

# 4) 企业微信群机器人
if [ -n "${WECOM_WEBHOOK:-}" ]; then
  curl -sS --max-time 15 -X POST "$WECOM_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"${TITLE}\n${BODY}\"}}" >/dev/null 2>&1 && sent=$((sent+1))
fi

# 5) 邮件（SMTP over SSL，用授权码/应用专用密码）
if [ -n "${SMTP_HOST:-}" ] && [ -n "${SMTP_USER:-}" ] && [ -n "${SMTP_TO:-}" ]; then
  python3 - "$TITLE" "$BODY" <<'PY' >/dev/null 2>&1 && sent=$((sent+1))
import os, smtplib, ssl, sys
from email.mime.text import MIMEText
from email.header import Header
host = os.environ["SMTP_HOST"]; port = int(os.environ.get("SMTP_PORT", "465"))
user = os.environ["SMTP_USER"]; pwd = os.environ["SMTP_PASS"]; to = os.environ["SMTP_TO"]
msg = MIMEText(sys.argv[2], "plain", "utf-8")
msg["Subject"] = Header(sys.argv[1], "utf-8"); msg["From"] = user; msg["To"] = to
ctx = ssl.create_default_context()
with smtplib.SMTP_SSL(host, port, context=ctx, timeout=20) as s:
    s.login(user, pwd); s.sendmail(user, [to], msg.as_string())
PY
fi

echo "channels_sent=${sent}"
