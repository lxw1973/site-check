# site-check

一条命令判断：**网站挂了，还是你网坏了。**

不用打开浏览器、不用看白屏猜症状，`dig` + `curl` 四步给出可判读的结论：状态码、响应体积、谁在应答、对照组是否正常。

## 为什么需要它

网站打不开时，浏览器只会给你一张白屏（有时附一个图标），不给你任何诊断信息。你会先去重启路由器、换 WiFi、开热点——折腾一圈才发现是对方站挂了。

真正的判据是四样，全在你看不到的地方：

| 判据 | 在哪 |
|---|---|
| HTTP 状态码 | 响应头第一行 |
| 响应体积 | `curl -w %{size_download}` |
| 谁在应答（CDN / 源站） | `server`、`x-via-*`、`cf-ray` |
| 是不是普遍现象 | 对照组站点 |

## 用法

```bash
curl -sSL https://raw.githubusercontent.com/lxw1973/site-check/main/site_check.sh -o site_check.sh
chmod +x site_check.sh
./site_check.sh https://example.com/
```

也可以克隆：

```bash
git clone https://github.com/lxw1973/site-check.git
cd site-check && ./site_check.sh https://example.com/
```

## 输出示例

```
== 1) DNS / CDN ==
xxxx.cdn.jiashule.com.
<CDN 节点 IP>
== 2) 状态码 ==
code=521 size=857 time=0.34s
== 3) 响应头 ==
HTTP/2 521
server: nginx
x-via-jsl: 8c027b4,-
== 4) 对照组 ==
对照 code=200
```

判读：**状态码 521 + `x-via-jsl` + 对照组 200** → CDN 正常、源站连不上，且不是你本地网络的问题。

## 判读表

| 状态码 | 大概率是什么 | 该谁修 |
|---|---|---|
| **521** | 回源失败：CDN 正常，源站连不上（加速乐/Cloudflare 特有） | 网站方 |
| **502 / 503** | 源站错误 / 服务不可用 | 网站方 |
| **504** | 网关超时 | 网站方 |
| **526** | CDN 到源站的证书有问题 | 网站方 |
| **403 / 429** | 可能被风控/限流拦截（换网络再试可确认） | 你或网站方 |
| **404** | 路径不存在（**不代表站挂了**） | 你 |
| **410** | 资源已被永久移除（域名停用/页面下架） | 你（先确认域名） |
| **000** | 根本没连上：DNS / 端口 / 代理 | 你 |
| **200 但内容不对** | 软 404、缓存页、WAF 挑战页 | 看内容 |

一句话：**5xx 是它的事，4xx 先想想是不是自己的事，000 是自己的事。**

## 用响应头认系统

| 看到的头 | 说明 |
|---|---|
| `server: nginx` + `x-via-jsl` | 加速乐在应答 |
| `server: nginx` + `cf-ray` | Cloudflare 在应答 |
| `server: openresty` | 通常自建（nginx + Lua） |
| `server: Caddy` | 现代反代，个人站/停放页/内部工具常见 |
| `Via` / `X-Cache` | 中间过了缓存层 |
| `alt-svc: h3=":443"` | 支持 HTTP/3（QUIC），现代服务器默认行为 |
| 无任何 CDN 头 + 5xx | 源站直接出事，没有中间层兜 |
| 无任何 CDN 头 + 410/404 + `content-length: 0` | 多半是停放域名，别查了 |

判断"是不是同一个系统"，不要看域名像不像，**看 `server` 头与 CDN 头**。

## 浏览器里怎么看状态码

```
F12 → Network → 勾上 Disable cache → Ctrl+Shift+R（Mac: Cmd+Shift+R）
→ 看列表第一行（Type = document）的 Status 列
```

白屏 ≠ 断网。真正的断网会给你 `ERR_CONNECTION_REFUSED`、`ERR_NAME_NOT_RESOLVED` 这类明确错误码；白屏 + 一个图标，恰恰是 CDN/WAF 错误页的典型长相。

## 说明

- 本脚本只做**只读探测**：一次 DNS 查询、一次 HEAD 级请求、一次对照请求，不构造任何攻击载荷、不扫描路径、不做爆破。
- 请只用于自有站点、故障排查或已获授权的目标。
- 依赖：`bash`、`curl`、`dig`（macOS/Linux 自带；Windows 用 WSL 或 Git Bash + `dig`）。
