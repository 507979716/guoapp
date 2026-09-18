# 短剧库 APP

基于 Flutter 的独立短剧应用。安装后直接在设备上请求站源、解析和播放，无需部署旧短剧库、Go 服务或外部 FFmpeg。

优先支持 Android 手机和 Windows 电脑，其次 Android TV，最后 iOS。当前版本为 `0.1.4+5`。

## 使用

- 在“发现”中切换站源，点击顶部刷新按钮手动更新，下拉也可刷新；列表底部可加载更多。
- 点击标题或封面都会补充剧集详情，随后可以立即播放、选集或继续上次进度。
- “追剧”和“最近观看”保存在当前设备。播放器每 5 秒及退出时保存进度，详情页同步更新续播按钮和选集高亮；已看完的分集会从下一集续播。
- `VIP：隐藏` 表示正在隐藏 VIP 内容，是默认状态；点一下切换为 `VIP：显示`。VIP 图标表示源站可能只提供试看，不会解除源站限制。
- 手机在视频区域上滑播放下一集，下滑播放上一集，双击暂停/继续；拖动进度条可以跳转。横屏视频跟随手机横屏显示，也可点全屏按钮手动切换。
- Windows 支持空格暂停/继续、左右方向键快进/后退 10 秒、F11 或 Ctrl+F 全屏、Esc 退出全屏/返回。
- Android TV 自动使用电视界面，也可以在“更多 → 界面模式”中选择“电视 / 遥控器”或“手机 / 电脑”；选择保存在设备上。手机和电视共用 APK，电视桌面会显示启动入口。
- 可以选择站源提供的清晰度和播放倍速；播放失败时点击“重试播放”会重新解析地址。自动选择时优先兼容的高清版本。
- 播放失败或前台播放连续 20 秒没有进度时，优先切换源站提供的备用地址，并保留进度和倍速。自动清晰度先尝试同清晰度的备用地址及兼容编码，再尝试较低清晰度；手选清晰度时只切换同清晰度线路，该集不提供时使用可用版本。单条线路或备用线路耗尽后，可自动重新解析一次地址，每轮最多自动恢复 3 次，之后提供手动重试入口。暂停和进入后台不会触发卡顿超时切线。
- 目录和分页位置保存在设备上，15 分钟内再次打开或切换站源直接使用缓存；过期后先展示已有列表再更新，更新失败仍保留原列表。顶部刷新或下拉刷新会立即联网更新。
- 海报在设备内解密并保存到磁盘，首页、详情和追剧共用缓存，重启后仍可复用。海报有效期为 30 天，上限 256 MB / 2000 张，超限清理较久未使用的图片；过期刷新失败时继续使用已有图片。加载失败可点击海报上的重试按钮。

| 站源 | 浏览与播放 | 搜索 |
| --- | --- | --- |
| 红果 | 真人剧、漫剧、AI 剧及分集 | 联网搜索 |
| 黄豆 | 列表、VIP 标记及分集 | 筛选当前已加载短剧 |
| 黄果视频 | 列表、详情及分集 | 筛选当前已加载短剧 |
| 黄果 AI | 列表、详情及分集 | 筛选当前已加载短剧 |

站源由第三方提供，可用性、清晰度和区域限制取决于源站及设备网络。列表缓存不代表视频已下载；完成下载后可离线播放。

### 下载与离线播放

在剧集详情点击“下载选集”，选择集数和画质后加入队列。默认选择非 VIP 集；也可全选、清空或手动选择。VIP 集可能只能下载试看。指定画质不存在时使用源站可用版本，重复任务会跳过；需要重新选择画质时，先取消或删除原任务。

首页“下载”中可以筛选未完成 / 已下载、暂停、继续、重试和取消；“队列操作”提供全部暂停 / 全部继续。队列同时最多下载 2 集，切集或退出播放器不会取消下载。支持应用运行期间下载，手机请保持应用在前台；退出应用后记录保留，重开后手动继续。源服务器支持有效的 Range 校验时续传当前文件；文件变化或不支持续传时重新下载该文件，已完整的 HLS 分片可复用。

“本地播放”直接读取设备上的已下载视频，可断网播放、跳转和续播，选集仅列出已完成的分集；从剧集详情播放时也优先使用本地文件。本地文件缺失或播放失败会提示重试，只有手动点击“改为在线播放”才会重新取源站视频。

下载保留原始媒体，不降低清晰度、不转码。MP4 / CENC MP4 保存原文件及所需密钥；HLS 将所选画质的列表、分片、初始化片段、AES-128 密钥和关联默认音轨 / 字幕保存到设备。暂不支持直播、未结束的 HLS 和需要额外授权的加密方式。文件存于应用数据目录，删除已下载任务会删除对应视频；Android 卸载或清除应用数据也会删除这些文件。Android 后台持续下载和通知尚未接入。

### 电视遥控器

聚焦的按钮和海报显示亮色边框。方向键可以切换站源、选择短剧、滚动长列表和选集；列表末尾的“加载更多”也可遥控操作。首页的“搜索”使用设备的系统输入法。

| 场景 | 操作 |
| --- | --- |
| 浏览列表和弹窗 | 方向键移动，确认键选择；返回键关闭弹窗或返回上一页 |
| 播放控制条隐藏时 | 左右快退 / 快进 10 秒，上下或确认键显示控制条 |
| 播放控制条显示时 | 方向键选择播放 / 暂停、上一集、下一集、选集、播放设置；确认键执行 |
| 聚焦播放进度时 | 左右快退 / 快进 10 秒，确认键暂停 / 继续 |
| 选集 | 自动定位当前集，方向键可滚动到未显示的集数；VIP 分集保留标记 |
| 播放设置 | 调整倍速、清晰度或追剧；切换清晰度保留观看进度与暂停状态 |
| 下载 | 方向键选择任务，确认键打开本地播放、暂停、继续或删除操作 |
| 返回 | 播放器返回上一页；追剧、最近观看或下载返回发现；有搜索词时先清空搜索 |

控制条在播放中无操作 5 秒后隐藏，暂停和弹窗操作期间保持可见。带专用播放 / 暂停、上一集、下一集按键的遥控器也可直接控制。电视视频按原始比例完整显示，不裁剪竖屏内容。

## 安装包与 GitHub Actions

开发目录每次完成任务并通过检查后，按 `AGENTS.md` 的约定同步源码到同级 `../guoapp`，创建本地 Git 提交和带说明的恢复标签：

```sh
python3 scripts/finish_task.py --message "本次完成的功能或修复"
python3 scripts/sync_source.py --check
```

脚本只使用 Python 标准库。它保留目标已有的 `.git`，更新源码并清理目标中的多余文件；保留源码、必要资源、构建配置、锁文件、测试和 Actions，排除 SDK、下载的依赖、编译产物、缓存、签名文件、个人配置与生成的插件注册文件。Gradle 包装器及插件注册文件由 Flutter 在构建时生成。收尾目标必须是独立 Git 仓库，并已配置提交身份；可通过 `--destination` 指定其他仓库。

标签默认取 `pubspec.yaml` 的版本号，例如 `v0.1.4`；同版本再次修改时添加时间后缀，不覆盖已有标签，源码未变化则复用对应恢复点。脚本只本地提交，不自动推送。只需同步文件时使用 `python3 scripts/sync_source.py`，该命令不创建提交。在 `guoapp` 内运行收尾脚本会跳过向自身复制，并直接保存当前源码。

恢复时在 `guoapp` 中从标签创建分支，直接在该分支继续开发；例如恢复 `v0.1.2`：

```sh
cd ../guoapp
git switch -c restore-v0.1.2 v0.1.2
```

不要在切换旧版本后继续用尚未还原的开发目录覆盖该仓库。提交与标签都保存在 `guoapp/.git`；安装包和个人配置不属于源码恢复点。

将 `guoapp` 中的内容发布到 GitHub 仓库根目录，保留 `.github`、`pubspec.lock`、`native`、`android` 和 `windows`。不需要提交 SDK、缓存、DLL 或 SO；工作流会编译原生核心并放入安装包。

推送 `main` / `master`、推送 `v*` 标签、提交 PR，或在 Actions 中手动运行 **Build app packages**，会依次执行检查，然后并行构建 Android 和 Windows。构建成功后，在该次运行的 Artifacts 下载：

| 产物 | 使用方法 |
| --- | --- |
| `duanju-android` | 解压后选择 APK；通常使用 `arm64-v8a`，旧款 32 位设备使用 `armeabi-v7a`，Intel Android 设备使用 `x86_64` |
| `duanju-windows` | 将其中的 Windows ZIP 完整解压，运行 `duanju_app.exe`，保留旁边的 DLL 和 `data` 目录 |
| `SHA256SUMS.txt` | 随产物提供，用于核对下载文件完整性 |

Android 手机和电视最低支持 Android 8.0，Windows 面向 Windows 10/11 x64。Artifacts 保留 14 天；工作流只生成构建产物，不自动创建 GitHub Release。

| 平台 | 当前交付状态 |
| --- | --- |
| Android 手机 | 已提供 APK，普通 ARM64 手机选择 `arm64-v8a`；`x86_64` 仅用于对应架构的设备 |
| Windows | 已有工程、原生 DLL 和 Actions 构建流程，尚未完成完整 Windows 包的构建及运行验收；本机 macOS 无法用 Flutter 交叉编译 Windows 应用，需 Windows 构建机或 Actions |
| Android TV | 已实现设备识别、电视界面、遥控操作和桌面入口，与手机共用 APK；尚未完成电视实机验收 |
| iOS | 尚未实现原生核心链接、平台工程和签名打包，当前没有可安装的 IPA |

### Android 固定签名

未配置签名时可以直接构建预览 APK。GitHub 的临时构建机可能使用不同预览签名，后续 APK 不一定能覆盖安装；正式发布应使用固定签名，并持续增加 `pubspec.yaml` 中 `+` 后的版本号。

在仓库 **Settings → Secrets and variables → Actions** 中配置以下四个 Secrets：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | JKS 签名文件的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | 签名文件密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

首次可以用 JDK 的 `keytool` 生成签名文件，放在项目目录外并自行备份：

```sh
keytool -genkeypair -v -keystore duanju-release.jks -storetype JKS -alias duanju -keyalg RSA -keysize 2048 -validity 10000
```

工作流会临时还原签名文件，完成后删除，不将其放入 Artifacts。签名文件、密码及其 Base64 内容都不要提交到仓库。

## 本地开发与构建

工具版本：Flutter `3.47.4`、Go `1.24.1+`、Python `3.10+`。Android 另需 JDK 17、Android SDK 36 和 NDK `28.2.13676358`；Windows 另需 Visual Studio 2022 的“使用 C++ 的桌面开发”和 MinGW-w64 x64。

把 Flutter、Go、Python 加入 PATH，Android 设置 `ANDROID_HOME`。构建脚本默认使用 `GOPROXY=https://goproxy.cn,direct`、`GOSUMDB=off`，只作用于构建进程；可通过同名环境变量覆盖。

Android 完整构建：

```sh
python3 scripts/build_android.py
```

只构建常用手机架构：

```sh
python3 scripts/build_android.py --abi arm64-v8a
```

Windows 在 PowerShell 中执行：

```powershell
.\scripts\build_windows.ps1
```

结果分别在 `dist/android` 和 `dist/windows`。脚本会检查包内是否包含站源核心和播放器原生库，Windows 还会附带所需的 VC++ 运行库。

本地 Android 固定签名可创建不入库的 `android/key.properties`，Windows 路径使用正斜杠：

```properties
storeFile=/absolute/path/duanju-release.jks
storePassword=你的签名文件密码
keyAlias=duanju
keyPassword=你的密钥密码
```

首次调试需先编译当前平台原生库，再执行 Flutter 命令：

```sh
python3 scripts/build_native.py --platform android --abi arm64-v8a
flutter pub get --enforce-lockfile
flutter run
```

Windows 对应 `--platform windows` 和 `flutter run -d windows`。手机架构要与所连接设备一致。

### 检查

先实现当前阶段，再集中执行：

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze lib test integration_test test_driver
flutter test --dart-define=DISABLE_REMOTE_IMAGES=true
cd native
go test -race ./...
```

测试使用合成元数据，不请求站源图片；安装了 FFmpeg 时，还会生成合成加密 HLS，验证改写后的播放列表可被真实解码器读取。FFmpeg 仅用于此项开发验证，不是应用运行依赖。

Flutter 3.47.4 的 `flutter analyze` 在部分中文路径下可能出现工具通信错误，本项目直接使用 `dart analyze lib test`。不要为此另建一份临时源码。

### 真机回归

调试包使用独立的 `.debug` 应用标识。`integration_test/playback_test.dart` 使用合成视频，不依赖站源媒体；可选的红果联网检查只请求目录元数据。

先连接并授权 Android 真机，在项目目录生成媒体并启动本机服务：

```sh
python3 scripts/create_test_media.py
python3 scripts/serve_test_media.py
```

保持服务运行，在另一终端执行（多台设备时为 adb 和 Flutter 指定设备序列号）：

```sh
adb reverse tcp:38473 tcp:38473
flutter drive --driver=test_driver/playback.dart --target=integration_test/playback_test.dart --dart-define=DISABLE_REMOTE_IMAGES=true --dart-define=FIXTURE_BASE_URL=http://127.0.0.1:38473
```

增加 `--dart-define=CHECK_LIVE_CATALOG=true` 可检查红果目录联网。首次安装按手机提示确认，避免悬浮窗口遮住安装按钮。结果在 `build/device-test/results/`；结束后停止本机服务并执行 `adb reverse --remove tcp:38473`。

### 工程结构

| 目录 | 内容 |
| --- | --- |
| `lib` | Flutter 页面、本地记录、播放器及 FFI 调用 |
| `native/core` | 独立站源解析、请求限流/退避、播放地址解析、设备内 HLS 读取 |
| `native/bridge` | Go 原生库的 C ABI 入口 |
| `android`、`windows` | 平台工程 |
| `scripts`、`.github/workflows` | 构建、签名、打包和持续集成 |
| `test`、`native/core/*_test.go` | 自动化验证 |

视频由随包的 media_kit / libmpv 在设备解码。MP4 直接读取；需要改写密钥或请求头的 HLS 经应用自身的 `127.0.0.1` 随机端口读取，不经过旧项目或自建服务器，也不做实时转码。备用线路复用本次解析结果，使用时才创建 HLS 会话；退出、换集和切线后释放旧会话。当前已接入红果的备用地址及兼容编码选项，只有单条地址的站源会尝试重新解析，不会将其他剧集当作备用内容。

## 开发待办

### P0：最小可用首版（Android 手机、Windows）

- [x] 创建独立工程和本地站源核心。
- [x] 浏览剧库、切换站源、红果联网搜索及其他站源本地筛选。
- [x] 剧集详情、选集、在线播放、失败重试。
- [x] 手机触控与 Windows 窗口布局。
- [x] GitHub Actions 检查、Android / Windows 打包、可选固定签名。
- [x] Android 三种架构的 APK 构建及包内原生库检查。
- [x] Android 真机合成视频播放、滑动切集、旋转、续播及红果目录联网验证。
- [ ] Windows 完整 ZIP 构建和运行验收。

### P1：完善观看体验

- [x] 本地观看记录、断点续播、追剧收藏。
- [x] 连续播放、切集手势、横竖屏与全屏。
- [x] VIP 标记与默认隐藏筛选。
- [x] 清晰度选择与播放倍速。
- [x] 黄果 AI 加密海报读取、磁盘缓存和失败重试。
- [x] 目录缓存有效期、分页状态恢复和手动强制更新。
- [x] 自动切换备用播放线路、卡顿超时恢复、保留进度及限制重试次数。

### P2：Android TV

- [x] 电视首页与遥控器焦点导航。
- [x] 遥控选集、快进、返回和播放控制。
- [x] 手机 / 电视统一 APK 构建与电视启动入口检查。
- [ ] Android TV 实机播放和遥控器验收。

### P3：本地媒体与高级功能

- [x] 下载队列、选集与画质、暂停、继续、取消和重启恢复。
- [x] 已下载视频本地播放、优先读取本地文件、断点续播及显式在线回退。
- [ ] Android 后台持续下载、进度通知和下载目录管理。
- [ ] 合并全集并优先保留原有码流。
- [ ] Emby 导出与海报元数据。
- [ ] 按独立应用场景设计本地用户、站源权限和配置备份。

### P4：iOS

- [ ] iOS 原生核心与媒体库接入。
- [ ] 播放、文件管理和后台任务适配。
- [ ] 签名、构建与真机验证。

## 当前状态

2026-09-18（`0.1.4`）：本轮完成下载队列、选集和画质选择、暂停 / 继续 / 取消、重启保留记录，以及已下载文件的本地播放。手机、电脑和电视均有下载入口；详情播放优先读取本地，失败时由用户选择是否切换在线。下载保存原始媒体，不进行转码。

Dart 格式与静态检查无问题，36 项 Flutter 回归、Go 核心竞态检查和 9 项源码同步 / 版本快照脚本测试通过。新增验证覆盖 VIP 选集、下载状态操作、遥控器长队列、本地元数据直接播放、断点续播、显式在线回退，以及 Range / If-Range 续传、源文件变化、残缺文件、队列并发与取消、重启恢复。合成 AES-128 HLS 下载后关闭源 HTTP 服务，使用 FFmpeg 仅允许本地协议解码通过；FFmpeg 只用于开发验证，成品不依赖它。

Android `0.1.4+5` 三种架构发布模式 APK 已生成，版本、签名、电视启动入口、原生库、16 KB 对齐及 SHA256 核验通过，签名与 `0.1.3` 一致。记录保存在本地 `build/android-release-verification.json`。Windows 原生核心 DLL 已重新交叉编译成功。

真机回归新增了下载选集、队列完成、MP4 / AES HLS / CENC 本地解码及跳转、源服务停止提供媒体后的请求计数和文件缺失提示；独立 `.debug` 调试包已编译。本轮连接的 vivo V2453A / Android 15 手机处于锁屏状态，尚未运行本轮真机回归。源码测试与构建结果不能代替实机验收。

此前该手机已验证 Go FFI 初始化、三类合成视频在线播放、加密 / 普通视频切换、跳转、滑动切集、横屏、自动连播、退出保存进度及播放会话释放；已有证据位于本地 `build/device-test/results/`。本轮没有请求站源图片。

待验证：本轮下载和自动切线的真机体验、Android TV 实机遥控及长时间播放、Windows 完整 ZIP 构建与运行。远程 Actions 未执行；iOS 尚未实施。下一步优先补 Android 后台下载与通知，再实现合并全集、Emby 导出。
