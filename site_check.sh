#!/usr/bin/env bash
U="${1:?用法: ./site_check.sh https://example.com/ [对照URL]}"
CTRL="${2:-https://www.baidu.com/}"
echo "== 1) DNS / CDN =="
HOST=$(echo "$U" | sed -E 's#https?://##; s#/.*##')
dig +short "$HOST"
echo "== 2) 状态码 =="
curl -sS -o /dev/null -w "code=%{http_code} size=%{size_download} time=%{time_total}s\n" --max-time 20 "$U"
echo "== 3) 响应头 =="
curl -sS -D - -o /dev/null --max-time 20 "$U" | head -8
echo "== 4) 对照组（${CTRL}）=="
curl -sS -o /dev/null -w "对照 code=%{http_code}\n" --max-time 15 "$CTRL"

echo "== 判读 =="
echo "  5xx → 它的锅（521 回源失败 / 502 网关 / 503 不可用 / 504 超时 / 526 证书）"
echo "  4xx → 先查自己（403/429 限流 / 404 路径 / 410 永久移除）"
echo "  000 → 没连上（DNS / 端口 / 代理）"
echo "  对照 200 而目标 5xx → 不是你的网络问题"
