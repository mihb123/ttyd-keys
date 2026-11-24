# AGENTS.md

Áp dụng cho mọi agent (Claude, Codex, Gemini/agy…) và người sửa repo này.

## Đọc gì

| Việc | Đọc |
|---|---|
| Tổng quan, mục lục | [docs/index.md](docs/index.md) |
| Sửa một tính năng | file tương ứng trong [docs/feature/](docs/index.md#tính-năng), mục Code map |
| Đổi giao thức với server | [docs/api_specifications.md](docs/api_specifications.md) |
| Build, cài, CI | [docs/deployment_guide.md](docs/deployment_guide.md) |

## Lệnh

| Lệnh | Khi nào |
|---|---|
| `make analyze` | Sau mỗi thay đổi Dart, phải sạch |
| `make docs-check` | Sau mỗi thay đổi `.md`, phải sạch |
| `make ios-ipa` / `make android-apk` | Lấy bản build sau khi push `main` |

## Quy tắc code

- Import widget từ `package:material_ui/material_ui.dart` như code hiện có.
- Giữ ranh giới module trong [docs/architecture.md](docs/architecture.md#2-module) (vd `ttyd_client.dart` không import Flutter).
- Thông báo cho người dùng bằng tiếng Việt.
- Không commit/push khi chưa được yêu cầu; push `main` sẽ kích hoạt build Codemagic.

## Cập nhật tài liệu sau mỗi thay đổi

Làm xong một tính năng, sửa lỗi hoặc cải thiện thì cập nhật docs **trong cùng thay đổi**:

| Thay đổi | Cập nhật |
|---|---|
| Hành vi/tính năng có sẵn | `docs/feature/<tên>.md` tương ứng (Phạm vi, Luồng, Quy tắc, Còn để lại) |
| Tính năng mới | Tạo `docs/feature/<tên>.md` từ [docs/templates/feature.md](docs/templates/feature.md), thêm dòng vào bảng Tính năng + Trạng thái trong [docs/index.md](docs/index.md), thêm gạch đầu dòng ở README nếu người dùng nhìn thấy |
| Thêm/đổi/xoá file trong `lib/` | Code map của feature + bảng Module trong `docs/architecture.md` |
| Endpoint, khung WS, timeout | `docs/api_specifications.md` |
| Key lưu trữ, mặc định cài đặt | Bảng trong `docs/feature/cai-dat.md` |
| Package, phiên bản Flutter | `docs/techstack.md` |
| Lệnh `make`, biến môi trường, `codemagic.yaml` | `docs/deployment_guide.md` |
| Màn hình mới | Bảng Màn hình trong `docs/architecture.md` |
| Xong/đổi trạng thái một mục | Bảng Trạng thái tính năng + ngày trong `docs/index.md` |
| Phát hiện lỗi chưa sửa | Mục "Còn để lại" của feature tương ứng |

Định dạng (để mọi agent viết giống nhau):

- Theo [quy ước viết tài liệu](docs/index.md#quy-ước-viết-tài-liệu); file feature giữ đúng 7 mục `##` và thứ tự của mẫu (mục không áp dụng ghi `Không có.`), `make docs-check` sẽ báo nếu lệch.
- Con số, tên hàm, key phải khớp code hiện tại; ghi kèm file/hàm.
- Chạy `make docs-check` trước khi báo xong.

## CHANGELOG

Mỗi thay đổi thêm 1 dòng vào [CHANGELOG.md](CHANGELOG.md), dưới mục ngày hôm nay (`## YYYY-MM-DD`, mới nhất ở trên):

```markdown
## 2026-11-25

- Thanh phím: thêm phím F1–F12 ([thanh-phim](docs/feature/thanh-phim.md)).
- Sửa: tự nối lại sau khi đăng xuất.
```

- Một dòng, bắt đầu bằng nhóm (`Kết nối`, `Thanh phím`, `Bàn phím ảo`, `Cài đặt`, `Build`, `Tài liệu`, hoặc tên tính năng mới) hoặc `Sửa:`; nói người dùng thấy gì thay đổi, không kể quá trình. Link tới feature là tuỳ chọn.
- Một thay đổi chưa commit chỉ có một dòng; sửa tiếp thì cập nhật dòng đó, không thêm dòng mới.
