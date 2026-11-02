++
# 一套代码，六个平台：Flutter 跨平台实现原理

本文配套本仓库（贪吃蛇）讲解：如何用**一份 Dart 代码**同时产出安卓、iOS、鸿蒙、
Windows、Linux、macOS 六个平台的原生应用，外加一个 Web 版。

## 1. 先说结论

- **技术选型**：只用 Flutter。Electron 出局，因为它把 Chromium 内核塞进桌面壳，
  没有手机端的发行渠道和能力（手机系统不允许你随便装一个完整浏览器引擎当应用壳）。
- **没有后端**：游戏是纯单机，最高分存在设备本地（`shared_preferences`），
  不需要任何服务器，因此也不需要 Python 之类的后端语言。
- **"一套代码"的准确含义**：`snake/lib/` 下的全部 Dart 代码只写一份；
  各平台目录（`android/`、`ios/`、`windows/` …）只是很薄的"启动壳"，
  由 `flutter create` 生成，几乎不需要手改。

## 2. 共享的到底是什么

```
snake/
├── lib/                  ← 唯一的"业务代码"，六个平台共用
│   ├── main.dart         入口：建 MaterialApp
│   ├── game/             纯 Dart 游戏逻辑，不 import 任何平台 API
│   │   ├── game_state.dart    棋盘/蛇/碰撞/分数（规则即单元测试）
│   │   ├── game_engine.dart   Timer 驱动 tick（150ms 起步，越吃越快）
│   │   └── score_storage.dart 最高分读写（shared_preferences）
│   └── ui/               界面：CustomPainter 画棋盘 + HUD + 触屏方向键
├── android/  ios/  macos/  windows/  linux/  web/
│                       ← 平台壳：原生启动代码 + 构建配置，各写各的
└── pubspec.yaml          依赖清单（Dart 侧）
```

关键点：

1. `lib/game/` 里**一行平台代码都没有**——没有 `import 'dart:io'`，
   没有任何 Android/iOS API。这样的代码在任何 Dart 运行时都能跑，
   也就能被同一套编译管线送进所有目标平台。
2. 连 UI 都是共享的。Flutter 的界面不是"安卓上跑安卓控件、iOS 上跑 iOS 控件"，
   而是所有平台都用**同一套自绘 UI**（见第 3 节），所以 `lib/ui/` 也只有一份。
3. 平台壳目录里各平台语言不同（Kotlin/Java、Objective-C++、Swift、C++、C++/GTK），
   但它们干的活是一样的：创建窗口、启动 Flutter 引擎、把窗口递给引擎画。

## 3. 画出来的 UI 是怎么跑起来的：渲染管线

Dart 代码本身不画像素。Flutter 在底层带了一个与平台无关的渲染引擎：

- **Skia**：Google 开源的 2D 图形库，Flutter 默认长期使用的渲染后端；
- **Impeller**：Flutter 3.7+ 起在新设备上逐步替换 Skia 的后端，
  把"录制+回放"的 GPU 管线前置编译，消除首帧卡顿。

流程大致是：

```
Dart 代码构建 Widget 树
        ↓
Layout/Paint 阶段生成"图层指令"（画什么、画在哪）
        ↓
渲染引擎（Skia 或 Impeller）把指令变成 GPU 命令
        ↓
各平台的原生图形接口提交到 GPU：
  Android → ANativeWindow/OpenGL|Vulkan
  iOS/macOS → Metal
  Windows → ANGLE(OpenGL→DirectX 11)
  Linux → EGL(OpenGL/Vulkan)
  Web → 直接画进 <canvas>
```

因为像素是"自己画"的，同一份 Dart 代码画出来的界面在六个平台上一致，
代价是它不是原生控件（不能直接复用系统 Material/ Cupertino 组件的实现，
而是 Flutter 自己按 Material Design / Cupertino 规范重画了一套）。

## 4. 需要原生能力时：Platform Channel 与插件

本游戏的"最高分"用 `shared_preferences` 插件持久化。插件就是"一套代码多端"
思想的最小实例：

```
shared_preferences（一个 pub 包）
├── shared_preferences 平台无关 Dart API   ← 你只 import 这一层
├── shared_preferences_android   用 SharedPreferences(Java) 实现
├── shared_preferences_foundation 用 NSUserDefaults 实现
├── shared_preferences_windows   用注册表实现
├── shared_preferences_linux     用 glib keyfile 实现
└── shared_preferences_web       用 localStorage 实现
```

Dart 层调用 `SharedPreferences.setInt(...)` 后，底层走 **Platform Channel**：
一条从 Dart isolate 到平台线程的消息通道（Android 上是 Java 侧的
`MethodChannel`，iOS 上是 Objective-C 侧的 `FlutterMethodChannel`）。
`flutter create` 已经把这些平台实现接好了，所以 `lib/` 里对最高分的读写
在六个平台是同一行 Dart 代码。

换句话说：**能纯 Dart 解决的就纯 Dart 写；解决不了的能力，用插件在各端壳里
各写一遍原生实现，Dart 侧仍然只面对一个 API。** 这就是"一套代码 + 少量
原生适配层"的完整分工。

## 5. 为什么 Electron 进不了这个方案

Electron = Chromium + Node.js，本质是"在电脑上开一个完整的浏览器窗口"。
它跑不了手机：Android/iOS/鸿蒙没有 Electron 运行时，也没有对应的商店分发形态；
它的体积（动辄 100MB+）和内存模型同样不适合手机。所以"一套代码覆盖
手机+电脑"只能选 Flutter（或 React Native / 原生 + KMM 等路线），
Electron 最多只能覆盖它自己那三类桌面端，还要求用户装 Node。

本项目选 Flutter 的另一个原因：渲染引擎自带，UI 六端像素级一致，
不用为"安卓长这样、iOS 长那样"写两套布局。

## 6. 各平台出包命令与前置条件

以下命令都在 `snake/` 目录下执行。

| 平台 | 命令 | 产物位置 | 前置条件 |
| --- | --- | --- | --- |
| Web | `flutter build web` | `build/web/` | 无（本机已验证） |
| Windows | `flutter build windows` | `build/windows/x64/runner/Release/` | Visual Studio 2022 + "使用 C++ 的桌面开发"工作负载 |
| 安卓 APK | `flutter build apk` | `build/app/outputs/flutter-apk/app-release.apk` | Android SDK（含 cmdline-tools）、Java 17 |
| 安卓 AAB（上架） | `flutter build appbundle` | `build/app/outputs/bundle/release/` | 同上 + 签名配置 |
| Linux | `flutter build linux` | `build/linux/x64/release/bundle/` | Linux + `clang cmake ninja-build libgtk-3-dev` |
| macOS | `flutter build macos` | `build/macos/Build/Products/Release/*.app` | macOS + Xcode + 开发者证书 |
| iOS | `flutter build ios --release` | Xcode 归档导出 .ipa | macOS + Xcode + 开发者证书 + 真机/设备描述文件 |
| 鸿蒙 | 见第 8 节 | DevEco 签名打包 .hap | OHOS Flutter 工具链 + DevEco Studio |

把产物按 `download/releases/README.md` 的命名放进去，`download/index.html`
的按钮就能用了。

## 7. 本机（Windows）缺什么、怎么补

本项目在一台 Windows 10 机器上用 Flutter 3.44 stable 开发，当前状态：

| 能力 | 状态 |
| --- | --- |
| `flutter analyze` / `flutter test` | 可用，已全绿（29 条） |
| Web 构建与游玩 | 可用（`flutter build web`） |
| Windows 桌面版 | 缺 Visual Studio C++ 组件 |
| 安卓 APK | 缺 Android SDK |
| Linux / macOS / iOS | 本机无法构建（需要对应系统） |
| 鸿蒙 HAP | 本机无法构建（需要 OHOS 工具链 + DevEco Studio） |

### 7.1 补上 Windows 桌面构建

1. 安装 [Visual Studio 2022](https://visualstudio.microsoft.com/)（Community 免费版即可），
   安装器里勾选工作负载 **"使用 C++ 的桌面开发"**（会自动带上 MSVC、Windows 10/11 SDK、Ninja）。
2. 验证：`flutter doctor` 中 "Windows desktop support" 变绿。
3. 出包：`flutter build windows`，把 `build/windows/x64/runner/Release/`
   整个目录压成 `snake-windows-x64.zip` 放进 `download/releases/`。

### 7.2 补上安卓构建

1. 安装 [Android Studio](https://developer.android.com/studio)（只为拿
   SDK 也行），或只装命令行组件：下载
   [Android SDK commandlinetools-win zip](https://developer.android.com/studio#command-line-tools-only)，
   解压到例如 `C:\Android\sdk\cmdline-tools\latest`，并设环境变量
   `ANDROID_HOME=C:\Android\sdk`。
2. 接受许可：`sdkmanager --licenses`（全选 y）。
3. 验证：`flutter doctor` 中 "Android toolchain" 变绿
   （需要 JDK 17，Android Studio 自带）。
4. 出包：`flutter build apk --release`，产物在
   `build/app/outputs/flutter-apk/app-release.apk`，
   重命名为 `snake-android-arm64-v8a.apk` 放进 `download/releases/`。
   注意：debug/release 默认用 Flutter 内置调试证书签名，
   上架 Google Play 前需换成自己的 keystore（`build.gradle` 里配置 signingConfigs）。

## 8. 鸿蒙 NEXT：工具链与构建步骤

官方 stable 频道的 `flutter create` **没有** `ohos` 平台选项，
鸿蒙支持来自 OpenHarmony SIG 维护的 Flutter 分支，步骤：

1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)
   （NEXT 对应的 5.x 版本），它自带 OpenHarmony SDK 和构建/签名工具。
2. 按 OpenHarmony SIG 的 Flutter 仓库
   （`openharmony-sig/flutter_flutter`）说明，下载/构建对应
   HarmonyOS NEXT 的 Flutter SDK 二进制（注意要与 DevEco 的
   HarmonyOS SDK API 版本匹配）。
3. 用该 SDK 的 `flutter` 给工程生成鸿蒙壳：
   `flutter create --platforms=ohos .`（只补壳，不覆盖 `lib/`）。
4. 在 `ohos/` 下配置应用信息（bundleName、图标），
   用 DevEco Studio 打开 `ohos/` 工程，配置签名（个人开发者证书即可本地安装测试），
   Build → Build Hap(s)/APP(s) → Build Hap(s)。
5. 产物 `.hap` 重命名为 `snake-harmonyos.hap` 放进 `download/releases/`。

`lib/` 里的代码不需要为鸿蒙改一行：游戏逻辑是纯 Dart，UI 走 Flutter 自绘管线，
OHOS 壳只负责启动引擎。这也是"一套代码"最直观的体现——
新增一个平台 = 多一个壳 + 平台特有插件的原生实现。

## 9. 本机已完成的验证

- `flutter analyze`：0 问题
- `flutter test`：29 条全过
  - 规则层（`game_state_test.dart`）：方向/180° 拒绝/尾格让位/撞墙撞身/
    吃食物加速/暂停恢复/重开/通关
  - 引擎层（`game_engine_test.dart`）：Timer 持续 tick、暂停冻结、重开、dispose
  - 界面层（`widget_test.dart`）：开局、键盘转向、撞墙结算与重开、最高分持久化
- `flutter build web --release`：成功，浏览器实机可玩（键盘 + 触屏方向键）

一个顺带收获：测试抓到过引擎的真实 bug——tick 定时器是一次性的，
蛇只走一步就停。这正是"逻辑写成纯 Dart 函数"的红利：
不需要任何真机，单测就能把这种时序 bug 逼出来。

## 10. GitHub Actions 云端出包（本仓库的做法）

本机只是一台 Windows 10，出不了 iOS / Linux / macOS / 鸿蒙的包。
所以本仓库把四个可云端构建的平台（Android / Windows / Linux / macOS）
交给 GitHub Actions：并行构建，产物自动发布到 GitHub Release，
下载页的按钮全部指向 Release 资产。好处是下载页不再依赖本机的
本地静态服务器，换任何一台设备、任何网络都能打开并下载。

### 10.1 流水线结构

`.github/workflows/` 下两个 workflow：

- `build-and-release.yml`：push `v*` tag 或手动触发
  - 四个 job 并行：ubuntu-latest（Android APK、Linux tar.gz）、
    windows-latest（Windows zip）、macos-latest（macOS 通用 zip）
  - `release` job 汇总产物发布到 GitHub Release
  - `ios` job 仅在仓库配置了 `APPLE_CERTIFICATE` Secret 时启用
- `web-pages.yml`：push master 或手动触发
  - `flutter build web --release` → 部署到 GitHub Pages，
    下载页"Web 在线版"卡片指向 `https://xujquan.github.io/tanchishe/`

### 10.2 各平台说明

- **Android / Windows / Linux**：公共 runner 自带对应工具链
  （Android SDK / VS C++ / GTK），`flutter build` 直接跑通，无需额外配置
- **macOS**：无 Apple 开发者账号，产物是**未签名**的 zip（内含
  `Snake.app`）。macOS 首次打开需右键 → 打开，或执行
  `xattr -d com.apple.quarantine Snake.app`。构建用
  `--universal`，Intel 与 Apple Silicon 都能装
- **iOS**：`flutter build ipa` 必须用 Apple 开发者账号（$99/年）
  签发的证书 + 描述文件。流水线已写好，只需在仓库
  Settings → Secrets and variables → Actions 配置四个值：
  - `APPLE_CERTIFICATE`（.p12 的 base64）
  - `APPLE_CERTIFICATE_PASSWORD`（p12 密码）
  - `APPLE_PROVISIONING_PROFILE`（.mobileprovision 的 base64，
    必须覆盖 bundle id `com.xujq.snake.Runner`）
  - `APPLE_KEYCHAIN_PASS`（临时 keychain 密码，任意字符串）
  配好后下一次打 tag 会自动多出一个 IPA
- **鸿蒙 NEXT**：公共 runner 上没有 OpenHarmony 工具链，打 HAP
  需要自托管 runner（在自己的机器装 OpenHarmony SIG 的 Flutter
  fork + DevEco SDK 并注册到 Actions）。对学习型项目不值得，
  维持本地 DevEco 构建

### 10.3 发版流程

```bash
git tag v0.2.0
git push origin v0.2.0
```

等 10–20 分钟（四平台并行构建），GitHub Release `v0.2.0` 即有
Android / Windows / Linux / macOS 四个包（配了 iOS Secrets 则是五个）。
升级版本时把 `download/index.html` 里各 href 的
`releases/download/v0.2.0/...` 版本号改一下即可。

费用：公共仓库的 Actions 分钟数免费，本项目一次发版全部 job
合计约 15–25 分钟。
