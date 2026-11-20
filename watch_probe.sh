#!/usr/bin/env bash
# watch_probe.sh —— 盯一个 URL，只在"状态变化"时说话（空输出 = 静默）
#
# 用法:
#   ./watch_probe.sh https://example.com/submit
#   watch_probe.sh https://example.com/ ./notify_push.sh
#
# 设计要点:
#   1) 只取状态码，不要正文（-o /dev/null -w "%{http_code}"）
#   2) 521 / 000 这类"常态故障"什么都不输出 —— 否则一天 48 条谁也受不了
#   3) 通知失败不影响探测结果
#
# 配合 notify_push.sh 使用；也可单独跑，只看 stdout。

TARGET="${1:?用法: ./watch_probe.sh <URL> [notify_push.sh 路径]}"
HERE=$(cd "$(dirname "$0")" && pwd)
NOTIFY="${2:-$HERE/notify_push.sh}"
TS=$(date '+%Y-%m-%d %H:%M')

CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 20 "$TARGET" 2>/dev/null)

case "$CODE" in
  200)
    MSG="✅ 已恢复：${TARGET} 返回 200（${TS}），可以干活了。"
    echo "$MSG"
    [ -x "$NOTIFY" ] && "$NOTIFY" "目标已恢复（200）" "$MSG" >/dev/null 2>&1
    ;;
  000|521)
    : # 仍然不通 —— 静默
    ;;
  404|502|503|504)
    MSG="⚠️ 状态变化：${TARGET} 返回 ${CODE}（${TS}），可能正在恢复，建议手动确认。"
    echo "$MSG"
    [ -x "$NOTIFY" ] && "$NOTIFY" "状态变化（${CODE}）" "$MSG" >/dev/null 2>&1
    ;;
  *)
    MSG="⚠️ 状态异常：${TARGET} 返回 ${CODE}（${TS}），建议手动确认。"
    echo "$MSG"
    [ -x "$NOTIFY" ] && "$NOTIFY" "状态异常（${CODE}）" "$MSG" >/dev/null 2>&1
    ;;
esac
