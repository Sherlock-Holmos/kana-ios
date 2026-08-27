# KanaStudy iOS

SwiftUI 版本的 [kana-study](../kana-study) N5 日语学习 App。内容数据复用 `kana-study/content/generated/*.json`，SRS 复习数据存本地 `UserDefaults`，本仓库不依赖任何三方包。

## 项目结构

```
kana-ios/
├── project.yml                       # XcodeGen 配置（入库）
├── KanaStudy/
│   ├── KanaStudyApp.swift            # @main 入口
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/                       # Kana / Vocabulary / Grammar / Kanji / Sentence / SRSStore
│   ├── Services/ContentService.swift # 加载 bundle 里的 JSON
│   ├── Views/                        # Home / Learn / Kana / Vocab / Review / Library / Progress
│   └── Resources/Content/            # 内容 JSON（与 kana-study 同源）
└── .github/workflows/ios.yml         # macOS runner 上的 iOS 编译
```

## 本地开发（macOS）

需要 Xcode 15+ 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
xcodegen generate
open KanaStudy.xcodeproj
```

在 Xcode 里选一个 iOS 16+ 模拟器，⌘R 运行。

## CI 编译（Windows 用户主路径）

`.github/workflows/ios.yml` 在 `macos-14` runner 上：

1. 拉代码
2. 安装 XcodeGen
3. `xcodegen generate`
4. `xcodebuild -scheme KanaStudy -destination 'generic/platform=iOS Simulator' build`
5. 把 `KanaStudy.app` 作为 artifact 上传

不需要 Apple Developer 账号 —— 这是 **simulator build**（无签名），用于验证代码能编过。

## 真机 / App Store

当前 `project.yml` 关闭了代码签名（`CODE_SIGNING_ALLOWED: NO`），CI 出的是模拟器包。如果要跑真机或上架：

1. 在 Xcode 里选自己的 Team，下载 provisioning profile。
2. 把 `project.yml` 里的 `CODE_SIGNING_*` 行注释或改成 `YES`。
3. 增加 ExportOptions.plist + `xcodebuild archive` 步骤。

这部分需要 Apple Developer 账号（年费 USD 99），不做也行，模拟器包已经足够开发验证。

## 内容同步

当 `kana-study/content/generated/*.json` 更新后，重新拷贝到 `KanaStudy/Resources/Content/` 即可。MVP 没有引入增量更新，启动时一次性解码进内存（kana.json 152KB / vocab.json 316KB，启动 < 50ms）。

## 路线图（MVP 之后）

| 模块 | 状态 | 备注 |
|---|---|---|
| 假名浏览器 | ✅ | 平假名 + 片假名分组网格 |
| 词汇闪卡 | ✅ | 显示 / 释义切换 |
| SRS 复习 | ✅ 极简 | 自写简化 SM-2，本地 UserDefaults 持久化 |
| 语法 / 汉字 / 例句 | 占位 | JSON 已入 bundle |
| Speaking 跟读 | 待 | 需录音权限 + AVFoundation |
| Supabase 同步 | 待 | 与 Web 版共用后端 |
| Adaptive Planner | 待 | 服务端能力 |

## 已知限制

- 只跑过 CI 编译验证，没有手动跑过模拟器（开发者本机是 Windows）。第一次上 Xcode 时如果发现模型字段对不上 JSON，先比对 `kana-study/content/generated/kana.json` 与 `Models/KanaItem.swift`。
- 默认无应用图标（`AppIcon.appiconset` 是空的），首次启动会显示占位。