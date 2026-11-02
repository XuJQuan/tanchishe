++
# 贪吃蛇 · 一套代码六个平台

经典单机贪吃蛇，用来验证"一套 Flutter 代码同时适配 Android / iOS / 鸿蒙 / Windows / Linux / macOS + Web"的完整实现路径。

## 仓库结构

```
tanchishe/
├── snake/                  # Flutter 工程（全部游戏逻辑在 lib/ 下，纯 Dart）
│   ├── lib/game/           #   游戏规则：GameState / GameEngine / ScoreStorage
│   ├── lib/ui/             #   界面：棋盘绘制、HUD、触屏方向键、键盘/滑动操作
│   └── test/               #   单元测试 + Widget 冒烟测试（29 条）
├── download/
│   ├── index.html          # 本地下载页（双击即可打开，无需服务器）
│   └── releases/           # 各平台构建产物放这里，下载页按钮即生效
└── docs/
    └── cross-platform.md   # 核心文档：一套代码多端适配的原理与构建步骤
```

## 快速开始

要求：Flutter SDK（本工程验证于 Flutter 3.44 stable）。

```powershell
cd snake
flutter pub get

# 跑测试
flutter analyze
flutter test

# 本机（Windows）能直接玩起来的版本：Web
flutter build web
# 产物在 build/web/，必须以静态服务的"根目录"打开（页面里 <base href="/"> 是绝对路径）
python -m http.server 8080 --directory build\web
# 然后浏览器打开 http://127.0.0.1:8080
# 或者开发模式直接跑：flutter run -d chrome
```

操作方式：

- 桌面 / Web：方向键或 WASD 转向，空格暂停，R 重开
- 手机：棋盘上滑动转向，或点屏幕下方的方向键

## 各平台出包

每条命令都在 `snake/` 目录下执行，产物命名与放置位置见 `download/releases/README.md`：

| 平台 | 命令 | 本机（Windows）能否构建 |
| --- | --- | --- |
| Web | `flutter build web` | 能（已验证） |
| Windows | `flutter build windows` | 需装 VS C++ 组件 |
| 安卓 | `flutter build apk` | 需装 Android SDK |
| iOS / macOS | `flutter build ios` / `flutter build macos` | 不能，需 macOS + 签名 |
| Linux | `flutter build linux` | 不能，需 Linux + GTK |
| 鸿蒙 | DevEco Studio 打包 | 不能，需 OHOS 工具链 |

工具链安装步骤与"一套代码多端"的原理详解，全部在 [docs/cross-platform.md](docs/cross-platform.md)。
