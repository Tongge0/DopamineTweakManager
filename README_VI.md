# Dopamine Tweak Manager — source beta

Ứng dụng iOS dành cho Dopamine Rootless / Sileo, dự kiến cài qua TrollStore.

## Có trong bản beta
- Đọc danh sách package từ dpkg status.
- Tìm kiếm và chọn từng package.
- Ghi manifest package/version.
- Sao lưu repo Sileo và các plist Preferences.
- Mở backup folder và chọn package muốn phục hồi.

## Giới hạn cần biết
- Đây là mã nguồn, chưa phải IPA đã build/ký.
- Cần macOS + Xcode + XcodeGen để build.
- TrollStore không tự đảm bảo app có quyền đọc mọi đường dẫn Rootless. Nếu quyền truy cập bị chặn, app sẽ báo lỗi.
- Bản beta KHÔNG tự cài package. Restore chỉ đọc manifest và cho chọn package; cài lại thủ công qua Sileo sau khi kiểm tra tương thích.
- Bản beta lưu toàn bộ plist Preferences riêng, không thể tự khẳng định plist nào thuộc tweak nào.
- Chỉ copy DEB nếu chúng đã có trong apt cache; không phải package nào cũng có DEB.
- Không copy nguyên `/var/jb`, không copy DynamicLibraries, không ghi đè bootstrap.

## Build
1. Trên macOS cài Xcode và XcodeGen.
2. Tại thư mục này chạy `xcodegen generate`.
3. Mở `DopamineTweakManager.xcodeproj` trong Xcode và build.
4. Cài app bằng TrollStore theo quy trình IPA thông thường.

## Đường dẫn thường gặp (Procursus Rootless)
- `/var/jb/var/lib/dpkg/status`
- `/var/jb/etc/apt/sources.list.d`
- `/var/jb/var/cache/apt/archives`
- `/var/mobile/Library/Preferences`

Bootstrap/thiết bị có thể khác. Hãy kiểm thử trên máy phụ trước.
