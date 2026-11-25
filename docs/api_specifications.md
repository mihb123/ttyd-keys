# Giao thức với server (ttyd-auth + ttyd)

App không có backend riêng; nó nói chuyện với **ttyd-auth** (reverse proxy có đăng nhập, mã nguồn không nằm trong repo này) đứng trước **ttyd 1.7.4**. Mọi request đi qua HTTPS/WSS tới `host` (mặc định `remote-ocl.mihb.site`). Code: `lib/ttyd_client.dart`.

Hành vi client (retry, tự đăng nhập lại, reconnect): [feature/ket-noi-ttyd.md](feature/ket-noi-ttyd.md).

## 1. HTTP

| Method | Path | Gửi | Kết quả app chờ | Xử lý lỗi |
|---|---|---|---|---|
| POST | `/login` | `application/x-www-form-urlencoded`: `username`, `password`; không theo redirect | `303` + cookie tên bắt đầu `ttyd_` | `429` → "Sai quá nhiều lần, thử lại sau 15 phút."; `401` → sai tài khoản (`wrongCredentials`); khác → "Đăng nhập lỗi (HTTP n)" |
| GET | `/` | header `Cookie: ttyd_<id>=...`; không theo redirect | `200`, HTML chứa `var k="<khóa tab>"` (regex `var k="([^"]+)"`) | Không có khóa hoặc khác 200 → "Không lấy được khóa phiên (HTTP n)." |

- Timeout: kết nối TCP 15 s (`_httpClient`), cả bước đăng nhập 30 s (`login`).
- `normalizeHost` bỏ `scheme://` và phần path. Host có cổng hiện lỗi ở bước WS ([ket-noi-ttyd.md](feature/ket-noi-ttyd.md#còn-để-lại)).
- Lỗi mạng được đổi thành `AuthException` (Socket/TLS/HTTP/Format).

## 2. WebSocket

`wss://<host>/ws?k=<khóa tab>`

| Thuộc tính | Giá trị |
|---|---|
| Subprotocol | `tty` |
| Header | `Cookie` (từ `/login`), `Origin: https://<host>` |
| Timeout mở | 15 s |
| Ping | mỗi 10 s (`pingInterval`) |
| Cookie hết hạn | server từ chối handshake; app nhận `WebSocketException` có chứa `401` → đăng nhập lại |

### Khung tin nhắn (ttyd 1.7.4)

Byte đầu là loại lệnh (ký tự ASCII), phần sau là payload.

| Chiều | Byte đầu | Payload | Hàm |
|---|---|---|---|
| Client → server (khung đầu, không có byte loại) | — | JSON `{"AuthToken":"","columns":c,"rows":r}` | `TtydConnection.open` |
| Client → server | `0` (0x30) | bytes UTF-8 của input | `input` |
| Client → server | `1` (0x31) | JSON `{"columns":c,"rows":r}` | `resize` |
| Server → client | `0` (0x30) | output terminal (UTF-8, có thể cắt giữa ký tự) | `_onMessage` → decoder chunked |
| Server → client | `1` (0x31) | tiêu đề cửa sổ | `onTitle` |
| Server → client | khác | bỏ qua | — |

- Output giải mã bằng `Utf8Decoder(allowMalformed: true).startChunkedConversion` để ký tự nhiều byte bị cắt giữa hai khung vẫn đúng.
- `input`/`resize` không gửi khi socket không ở trạng thái `open`.
- Không dùng khung PAUSE `2`/RESUME `3`: ttyd 1.7.4 gọi `pty_resume` sau mỗi khung output (`LWS_CALLBACK_SERVER_WRITEABLE` trong `protocol.c`) nên PAUSE vô tác dụng. Chặn luồng bằng `TtydConnection.pause`/`resume` = dừng/đọc tiếp socket (`StreamSubscription.pause`), TCP đầy thì ttyd ngừng đọc pty.
- Socket dừng đọc quá `pingInterval` 10 s thì `dart:io` đóng kết nối (1001) vì không thấy pong.
- Mỗi WebSocket mới là một shell mới phía ttyd; giữ phiên bằng `tmux` (xem [feature/cai-dat.md](feature/cai-dat.md)).
