#!/usr/bin/env bash
U="${1:?用法: ./site_check.sh https://example.com/}"
echo "== 1) DNS / CDN =="
HOST=$(echo "$U" | sed -E 's#https?://##; s#/.*##')
dig +short "$HOST"
echo "== 2) 状态码 =="
curl -sS -o /dev/null -w "code=%{http_code} size=%{size_download} time=%{time_total}s\n" --max-time 20 "$U"
echo "== 3) 响应头 =="
curl -sS -D - -o /dev/null --max-time 20 "$U" | head -8
echo "== 4) 对照组 =="
curl -sS -o /dev/null -w "对照 code=%{http_code}\n" --max-time 15 https://www.baidu.com/
