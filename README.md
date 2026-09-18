# 真果鉴

Flutter 多端独立短剧应用，原名“短剧库 APP”。站源请求、解析、下载和播放均在设备上完成，不依赖旧项目或自建服务。当前版本：**0.2.1+7**。

更名保留原 Android 应用标识及数据目录；使用同一签名的新 APK 覆盖升级，继续保留追剧、观看记录和下载任务。

## 使用

| 功能 | 操作 |
| --- | --- |
| 浏览 | “发现”切换站源，顶部刷新或下拉更新，底部加载更多 |
| 搜索 | 红果联网搜索；输入停顿 300 毫秒显示官网联想词，匹配文字高亮，点击候选搜索。其他站源筛选已加载短剧 |
| 详情 | 点击标题或封面均会补充剧集信息，再播放、选集或继续观看 |
| 追剧与历史 | 每个用户独立保存；每 5 秒及退出播放时记录进度，已看完的分集从下一集续播 |
| VIP | 默认“VIP：隐藏”表示隐藏 VIP 内容；点击变为“VIP：显示”。VIP 视频可能只有试看 |
| 手机播放 | 视频区域上滑下一集、下滑上一集，双击暂停；支持进度跳转、倍速、源站画质选择和自动连播 |
| 横竖屏 | 按视频比例显示，横屏视频可跟随手机旋转，也可用全屏按钮手动切换 |
| Windows | 空格暂停，左右方向键快退 / 快进 10 秒，F11 或 Ctrl+F 全屏，Esc 退出全屏或返回 |
| 外观 | “更多 → 设置与备份 → 外观主题”选择浅色、深色或跟随系统；默认延续深色，记住本机选择，配置备份也包含主题 |
| 更多 | 用户管理、设置与备份、界面模式、关于 |

| 站源 | 浏览与播放 | 搜索 |
| --- | --- | --- |
| 红果 | 真人剧、漫剧、AI 剧及分集 | 联网搜索与官网搜索联想 |
| 黄豆 | 列表、VIP 标记及分集 | 筛选已加载短剧 |
| 黄果视频 | 列表、详情及分集 | 筛选已加载短剧 |
| 黄果 AI | 列表、详情及分集 | 筛选已加载短剧 |

站源可用性、清晰度和区域限制取决于源站及网络；应用不解除源站 VIP 或其他授权限制。

### 主题与导航

浅色主题使用暖白背景、深色文字，首页、追剧、详情、下载、用户和设置同步切换；播放器保持深色，返回后恢复所选主题。切换主题保留当前页面、站源及导航位置。

手机底部导航使用图标、常显文字和细线标记选中项；系统虚拟按键 / 手势区域延续当前背景，系统图标随主题调整明暗。导航支持系统大字设置、键盘焦点和无障碍选中状态。

设计参考 [Android 系统栏与边到边布局](https://developer.android.com/develop/ui/views/layout/edge-to-edge)、[Flutter 系统栏适配](https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge)和 [NN/g 图标可用性](https://www.nngroup.com/articles/icon-usability/)：处理系统安全区，保留文字标签，并提供颜色之外的选中标记。

### 缓存与播放恢复

目录及分页位置缓存 15 分钟；过期后先显示缓存再更新，失败保留原列表，手动刷新立即联网。搜索联想失败不影响手动搜索。

海报在设备内处理和缓存，首页、详情和追剧共用；有效期 30 天，上限 256 MB / 2000 张，超限清理较久未使用的图片。过期更新失败时继续显示缓存，失败海报可手动重试。黄果 AI 加密海报由本地核心处理。

正常播放与下载**不转码、不降低清晰度**。随包的 media_kit / libmpv 在设备解码；MP4 直接读取，需要改写请求头或密钥的 HLS 使用应用自身的设备内服务，不经远程中转。

播放失败或前台连续 20 秒无进度时，优先尝试备用地址。自动画质先试同画质备用地址及兼容编码，再试较低画质；手选画质只切同画质线路。备用地址耗尽后最多重新解析一次，每轮最多自动恢复 3 次，之后提供手动重试。切线保留进度和倍速；暂停、后台不会触发卡顿切线。

### 用户与权限

“更多 → 用户管理”提供独立界面。初始用户为管理员；先设置至少 6 位管理员密码，才能创建其他用户。

管理员可勾选用户能访问的站源，设置“允许下载和本地媒体”。关闭后仅能在线观看，下载、目录、合并和导出入口隐藏，相关调用也检查权限。有密码的用户在切换或冷启动时需要解锁；存在其他用户时不能取消管理员密码。

追剧和观看记录按用户隔离。下载文件在本机共享，有下载权限的用户只能在应用中访问获准站源的内容。这些用户属于当前设备，不是远程服务器账号。

“设置与备份”可导出和恢复用户、密码校验信息、追剧、观看记录和偏好设置。备份不含视频、原生下载密钥或其他插件私有配置；恢复前校验格式并确认覆盖，视频文件保留。密码使用随机盐和 PBKDF2-HMAC-SHA256 校验值，不保存明文。

### 下载、后台运行与空间

在详情点击“下载选集”，选择分集和画质。默认选择非 VIP 集，也可全选或手动选择；VIP 集可能仅有试看。重复任务跳过，指定画质缺失时使用源站可用版本。

“下载”提供状态筛选、暂停、继续、取消、删除和整队列操作。同时最多下载 2 集，播放和切集不会取消下载。源站支持有效的 Range 校验时续传当前文件；文件变化或不支持续传时重新下载该文件，完整 HLS 分片可复用。

- Android 使用前台服务持续下载，通知显示进度并提供“暂停下载”。系统终止进程、关机或后台服务达到系统时限后，保留任务与完整文件，重开应用可手动继续。
- Windows 下载时保持应用运行。iOS 当前采用前台下载，进入后台暂停下载和本地媒体处理，回前台后可继续下载。
- “设置与备份 → 下载目录与空间”查看占用、剩余空间，迁移视频、合并成品和导出内容。迁移先暂停下载，复制并保存新位置成功后才清理旧目录；失败保留原文件。
- Android 可选应用内部目录及设备 / SD 卡上的应用专属目录，iOS 可迁移到“文件”App 可见目录，Windows 可选普通文件夹。Android 应用专属目录随卸载或清除应用数据删除。

“本地播放”读取设备文件，可断网、跳转和续播。详情播放也优先用已下载分集；本地损坏时只有手动选择“改为在线播放”才联网。

下载保存原始 MP4 / CENC MP4 及所需密钥；HLS 保存所选画质列表、分片、初始化片段、AES-128 密钥及关联默认音轨 / 字幕。暂不支持直播、未结束的 HLS 和需要额外授权的加密方式。列表缓存不等于已下载视频。

### 合并与本地成品

“下载 → 本地媒体 → 合并成品”选择已下载的剧。按集数合并，原分集保留；未下载全集时显示实际已下载数量。

1. 先在本地解密或换封装，保留码流。
2. 相同格式直接合并；仅音频不同就只处理音频。
3. 视频确需统一时，以数量最多的格式为目标，仅转换不一致分集；数量相同时优先保留总时长较长的格式。
4. 无音轨分集按需补静音，不丢掉其他分集的声音；不能可靠转换的编码或混合 HDR 色彩格式会明确失败并保留原文件。

视频转换目标支持 H.264 / HEVC，不会自动把全部视频重新转码。一次处理一个媒体任务，编码线程限制为 2；显示进度、支持取消，处理期间禁止迁移目录或删除输入分集。

成品保存在下载目录的 `library`，可在“合并成品”播放、续播和删除；合并全部分集时显示“全集播放”。成品进度单独保存，不覆盖原分集进度。

### Emby 导出与海报

“下载 → 本地媒体 → Emby 导出”按剧或批量导出已下载分集；“设置与备份 → 下载完成后自动导出 Emby”开启自动处理。

~~~text
exports/
  剧名 [站源-标识]/
    tvshow.nfo
    Season 01/
      S01E001.mkv
      S01E001.nfo
      S01E002.mkv
      S01E002.nfo
~~~

导出保存在下载目录的 `exports`，无损解密 / 换封装，不重新编码、不依赖临时播放地址。NFO 提供剧名、简介、季 / 集编号、唯一标识及海报 URL，减少对片名自动刮削的依赖。

默认只写海报 URL；源站海报需要解密或外部读取失败时，可开启“同时导出海报文件”，在后续导出时使用本地处理后的海报。已导出的剧再次手动导出会补齐海报与 NFO，不重复处理视频。

将 `exports` 加入 Emby **电视节目库**并启用实时监控或定时扫描。Emby 在其他设备上时，需共享目录、NAS 或复制文件，手机私有路径不能直接用于另一台机器。本功能不运行媒体服务器，也不将过期站源地址写成长期订阅。

相同任务不重复处理。删除导出文件后该分集不再自动导出，可手动重新导出；导出文件和原下载分集独立，删除一份不影响另一份。

### Android TV

手机与电视共用 APK，电视桌面有启动入口；自动识别，也可在“更多 → 界面模式”中手选。聚焦按钮和海报显示亮色边框。

| 场景 | 遥控器操作 |
| --- | --- |
| 浏览、弹窗、下载队列 | 方向键移动、确认选择、返回关闭或返回 |
| 控制条隐藏 | 左右快退 / 快进 10 秒，上下或确认显示控制条 |
| 控制条显示 | 方向键选择播放、切集、选集、设置，确认执行 |
| 进度条 | 左右快退 / 快进，确认暂停 / 继续 |
| 选集 | 定位当前集，可滚动到未显示的集数，保留 VIP 标记 |
| 播放设置 | 倍速、画质、追剧；切画质保留进度和暂停状态 |
| 首页返回 | 先返回发现，再清空搜索；发现且无搜索词时退出 |

支持专用播放 / 暂停、上一集、下一集按键。播放中无操作 5 秒后隐藏控制条，暂停和操作弹窗时保持可见。竖屏视频保持原比例，不裁剪填满电视。

## 安装包与平台状态

| 平台 | 包与状态 |
| --- | --- |
| Android 8.0+ 手机 | ARM64、ARMv7、x86_64 APK；普通手机选 `arm64-v8a`，Intel Android 才选 `x86_64` |
| Windows 10/11 x64 | 完整 ZIP 解压后运行 `zhenguojian.exe`，保留所有 DLL 和 `data`；完整包运行验收需 Windows / Actions |
| Android TV | 与手机共用 APK，电视界面与遥控已覆盖自动化；待电视实机验收 |
| iOS 15.1+ | 已加入工程、Go 核心链接、媒体依赖、文件管理和构建脚本；待 Xcode 构建与真机验收，没有已签名 IPA |

`INSTALL_FAILED_NO_MATCHING_ABIS` 表示 APK 与设备架构不匹配，请更换对应架构安装包。

### GitHub Actions

将 `guoapp` 源码发布到仓库根目录，保留 `.github`、锁文件、`native` 和平台工程；不用上传 SDK、依赖目录、SO、DLL 或缓存。

推送 `main` / `master`、`v*` 标签、提交 PR，或手动运行 **Build app packages**，会先检查再构建：

| Artifact | 内容 |
| --- | --- |
| `zhenguojian-android` | 三种架构 APK 和 SHA256 |
| `zhenguojian-windows` | 完整 ZIP 和 SHA256；从解压包验证原生核心、FFprobe、换封装及播放器启动 |
| `zhenguojian-ios-unsigned` | 未签名 `.app` ZIP 和 SHA256，不能直接当已签名 IPA 安装 |

产物保留 14 天，不自动创建 GitHub Release。首次平台构建结果以实际 Actions 输出为准。

Android 正式发布持续使用同一签名并递增构建号，在仓库 Secrets 配置：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | JKS 文件 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 签名文件密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

未配置时生成预览 APK，不同构建机的预览签名可能无法相互覆盖。创建签名文件并保存到项目外：

~~~sh
keytool -genkeypair -v -keystore zhenguojian-release.jks -storetype JKS -alias zhenguojian -keyalg RSA -keysize 2048 -validity 10000
~~~

本地不入库的 `android/key.properties`：

~~~properties
storeFile=/absolute/path/zhenguojian-release.jks
storePassword=你的密码
keyAlias=zhenguojian
keyPassword=你的密码
~~~

## 开发与构建

Flutter `3.47.4`、Dart `3.12+`、Go `1.24.1+`、Python `3.10+`。Android 需要 JDK 17、SDK 36、NDK `28.2.13676358`；Windows 需要 Visual Studio 的 C++ 桌面组件及 MinGW-w64 x64；iOS 需要 macOS、完整 Xcode 和 CocoaPods。

将 Flutter、Go、Python 加入 PATH，Android 设置 `ANDROID_HOME`。构建脚本对子进程默认设置 `GOPROXY=https://goproxy.cn,direct`、`GOSUMDB=off`，不改全局配置；同名环境变量可覆盖。

~~~sh
python3 scripts/build_android.py
python3 scripts/build_android.py --abi arm64-v8a
python3 scripts/build_android.py --cn-mirrors
~~~

Windows PowerShell：

~~~powershell
.\scripts\build_windows.ps1
.\scripts\build_windows.ps1 -ChinaMirrors
~~~

国内构建可使用以上镜像开关：Flutter/pub 使用 `storage.flutter-io.cn` / `pub.flutter-io.cn`，Android 的 Google、Maven Central 和 Gradle 插件依赖优先使用阿里云镜像，同时保留官方仓库。已有环境变量优先；镜像配置仅作用于本次构建，保留锁定的依赖版本与 SHA256 校验值；结束后恢复原锁文件并清理临时 Gradle 配置，不改全局代理。GitHub Actions 默认使用官方源。镜像可能有同步延迟，遇到镜像缺失或异常可去掉开关重试；此开关不替代 Flutter SDK 和 Gradle 发行包的初次安装。

iOS 未签名构建、只生成核心、或额外生成模拟器核心（不会启动模拟器）：

~~~sh
python3 scripts/build_ios.py
python3 scripts/build_ios.py --core-only
python3 scripts/build_ios.py --core-only --simulator
~~~

签名 IPA 使用自己在 Xcode 配置的签名身份、描述文件与 ExportOptions：

~~~sh
python3 scripts/build_ios.py --export-options /path/to/ExportOptions.plist
~~~

产物在 `dist/android`、`dist/windows`、`dist/ios`。iOS 脚本将 Go 核心生成 XCFramework，再经 CocoaPods 链接并检查 FFI 导出符号；媒体库随应用打包。

首次 Android 调试先编译对应架构核心：

~~~sh
python3 scripts/build_native.py --platform android --abi arm64-v8a
flutter pub get --enforce-lockfile
flutter run
~~~

Windows 对应 `--platform windows` 和 `flutter run -d windows`。

播放器使用 [media_kit](https://github.com/media-kit/media-kit) / libmpv，合并和导出使用 [FFmpegKit min-gpl](https://github.com/sk3llo/ffmpeg_kit_flutter)，含 FFmpeg、x264 / x265 等 GPL 媒体组件，各组件适用上游许可证。FFmpegKit 不参与正常播放或下载的转码；系统 FFmpeg 只用于开发验证，用户不用另装。

### 集中检查与真机回归

先完整实施本轮功能，再统一检查：

~~~sh
python3 -m unittest discover -s scripts -p 'test_*.py'
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze --fatal-infos lib test integration_test test_driver
flutter test --dart-define=DISABLE_REMOTE_IMAGES=true
cd native
go test -race ./...
~~~

合成媒体验证需要开发机安装 `ffmpeg` / `ffprobe`。测试覆盖权限隔离、备份校验、搜索防抖与旧结果、仅少数分集转码、CENC 解密换封装、Emby 元数据及删除原文件后的完整解码，不请求站源图片。

Android 回归使用独立 `.debug` 包。连接并授权 USB 调试、保持设备解锁：

~~~sh
python3 scripts/create_test_media.py
python3 scripts/serve_test_media.py
~~~

另一终端运行：

~~~sh
adb reverse tcp:38473 tcp:38473
flutter drive --driver=test_driver/playback.dart --target=integration_test/playback_test.dart --dart-define=DISABLE_REMOTE_IMAGES=true --dart-define=FIXTURE_BASE_URL=http://127.0.0.1:38473
~~~

多设备时指定序列号，可加 `--dart-define=CHECK_LIVE_CATALOG=true` 检查红果目录元数据。用例覆盖 MP4 / AES HLS / CENC、切线、切集、横屏、离线下载、合并 / 导出及最小化后的后台下载。结果在 `build/device-test/results/`；结束后停服务并执行 `adb reverse --remove tcp:38473`。

### 源码同步与恢复

每次完成任务并通过必要检查后执行：

~~~sh
python3 scripts/finish_task.py --message "本次实际完成的变更"
python3 scripts/sync_source.py --check
~~~

脚本同步纯源码到同级 `../guoapp`，保留 `.git` 历史，创建本地提交和带说明的 tag；默认 `v<版本号>`，同版本后续修复加时间后缀，不覆盖旧标签，不自动推送 GitHub。

只同步用 `python3 scripts/sync_source.py`；在 `guoapp` 内工作时跳过向自身同步。保留必要源码、资源、锁文件、测试、平台工程和 Actions，排除依赖、SDK、缓存、产物、签名及个人配置。

恢复示例：

~~~sh
cd ../guoapp
git switch -c restore-v0.2.1 v0.2.1
~~~

从恢复分支继续工作，避免用尚未还原的开发目录再次覆盖；安装包和个人配置不属于源码恢复点。

| 目录 | 内容 |
| --- | --- |
| `lib` | 页面、播放器、本地用户、FFI、下载和媒体处理 |
| `native/core`、`native/bridge` | 独立站源核心、缓存、下载、目录迁移及 C ABI |
| `android`、`windows`、`ios` | 平台工程与必要资源 |
| `scripts`、`.github/workflows` | 构建、签名、验证、同步和版本快照 |
| `test`、`integration_test` | 自动化与设备回归 |

## TODO 与当前验证

| 优先级 | 功能 | 进度 |
| --- | --- | --- |
| P0 | 独立运行、四源浏览 / 详情 / 播放、Android 三架构、Windows 工程与 Actions | 已实现 |
| P1 | 追剧 / 历史、切集 / 横屏、VIP、画质 / 倍速、缓存、自动切线 | 已实现 |
| P1 | 浅色 / 深色 / 跟随系统、系统栏融合与底部导航美化 | 本轮完成 |
| P1 | 红果官网联想、防抖、高亮与点击搜索 | 已实现 |
| P1 | Android / Windows 国内依赖镜像开关、保持版本锁定 | 本轮完成 |
| P2 | TV 布局、遥控器、统一 APK、电视入口 | 已实现，待电视实机验收 |
| P3 | 下载、离线播放、Android 后台服务和通知 | 已实现，后台行为待真机回归 |
| P3 | 下载目录迁移与空间统计 | 本轮完成 |
| P3 | 合并、仅转换少数不一致分集、成品本地播放 | 本轮完成 |
| P3 | Emby 批量 / 自动导出、NFO、海报 URL / 可选海报文件 | 本轮完成 |
| P3 | 本地用户、站源 / 下载权限、记录隔离和备份 | 本轮完成 |
| P4 | iOS 工程、核心链接、文件目录、前后台处理、构建流程 | 已实施，待 Xcode 构建与真机验收 |

本轮通过 Dart 静态检查、52 项 Flutter 回归和 13 项构建镜像 / 同步 / 版本快照测试。新增覆盖主题持久化、备份兼容、打开页面即时换色、保持导航位置、跟随系统、三 / 四项导航大字布局及键盘操作、播放器深色主题和返回后的系统栏恢复。

Android ARM64 合成数据调试包已构建成功；正式安装包仍为 `dist/android/zhenguojian-0.2.0+6-{arm64-v8a,armeabi-v7a,x86_64}.apk`，本轮 `0.2.1+7` 正式 APK 尚未重打。调试包用于自动化验收，不作为正式安装包交付。

本轮手机调试连接断开，尚未完成真实系统虚拟按键区域的视觉验收，未启动模拟器。Windows 完整包运行验收需 Windows / Actions；本机缺少 iPhoneOS SDK，iOS 尚未完成 Xcode 构建和真机验收，也未执行远程 Actions。

此前 Go 核心竞态回归、合成 CENC 换封装、少数分集合并转码及 Emby 成品独立解码验证已通过。本轮未修改 Go 核心。国内 pub 严格锁文件与 Gradle 镜像配置此前已验证；完整镜像构建仍以实际依赖可用性为准。
