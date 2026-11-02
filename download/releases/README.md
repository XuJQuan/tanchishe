++
# 构建产物目录

把各平台构建产物按下表命名放进本目录后，`../index.html` 对应卡片的按钮即可直接下载。

| 平台 | 文件名 | 生成方式 |
| --- | --- | --- |
| 安卓 | `snake-android-arm64-v8a.apk` | `snake` 目录下 `flutter build apk`，取 `build/app/outputs/flutter-apk/app-release.apk` |
| iOS | `snake-ios.ipa` | 需 macOS：`flutter build ios --release` 后用 Xcode 归档导出 |
| 鸿蒙 | `snake-harmonyos.hap` | 需 DevEco Studio + OpenHarmony Flutter 工具链，见 `../../docs/cross-platform.md` |
| Windows | `snake-windows-x64.zip` | `flutter build windows`，把 `build/windows/x64/runner/Release/` 压成 zip |
| Linux | `snake-linux-x64.tar.gz` | `flutter build linux`，把 `build/linux/x64/release/bundle/` 打包 |
| macOS | `snake-macos.dmg` | 需 macOS：`flutter build macos` 后创建 DMG |

Web 版无需放入本目录：在 `snake/` 下执行 `flutter build web`，
然后把 `snake/build/web/` 作为静态服务的根目录打开
（例如 `python -m http.server 8080 --directory build\web` 后访问 `http://127.0.0.1:8080`）。
