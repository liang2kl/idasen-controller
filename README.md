# Idasen

一个简洁的原生 macOS 菜单栏 app，通过蓝牙控制 IKEA IDÅSEN 及其他 LINAK 升降桌。灵感来自 [idasen-desk-controller](https://github.com/mehmetmuejde/idasen-desk-controller)，用 SwiftUI + CoreBluetooth 重写，没有任何第三方依赖。

## 功能

- **菜单栏常驻**：实时显示桌面高度，不占 Dock
- **无限预设**：任意数量的常用高度，可添加、编辑、删除、拖动排序
- **一键到位**：点击预设即移动到目标高度；移动中再次点击或按「停止」即停
- **按住移动**：按住 ⌃ / ⌄ 持续升降，轻点微调 1 cm
- **自动连接**：记住上次的桌子，断线后自动重连
- 登录时启动、菜单栏高度显示开关、中英文界面

## 构建

需要 Xcode 16+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

```bash
xcodegen generate
open IdasenController.xcodeproj
```

或命令行构建：

```bash
xcodebuild -project IdasenController.xcodeproj -scheme IdasenController -configuration Release -derivedDataPath build build
```

产物位于 `build/Build/Products/Release/Idasen.app`。

### 发布到 App Store

签名使用团队 `C5UH93T368` 的自动签名。需要先在 Xcode › Settings › Accounts 中登录该 Apple ID，然后归档并上传：

```bash
xcodebuild -project IdasenController.xcodeproj -scheme IdasenController -configuration Release -archivePath build/Idasen.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Idasen.xcarchive -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
```

也可以在 Xcode Organizer 中选择归档并点「Distribute App」。

## 首次使用

1. 启动后允许 Idasen 使用蓝牙。
2. 首次配对时，按住桌子控制器上的蓝牙按钮直到指示灯闪烁，app 会自动发现并连接。
3. 之后 app 会记住这张桌子；如需更换，在 ⋯ 菜单中选择「忘记此升降桌」。

## 协议

使用 LINAK DPG 蓝牙协议：

| 用途 | 特征 UUID |
| --- | --- |
| 指令（唤醒 / 停止） | `99FA0002-338A-1024-8A49-009C0215F78A` |
| 高度与速度（通知） | `99FA0021-338A-1024-8A49-009C0215F78A` |
| 目标高度输入 | `99FA0031-338A-1024-8A49-009C0215F78A` |

高度以 0.1 mm 为单位、相对最低位 62 cm 编码；移动时每 200 ms 写入一次目标高度，速度归零即到位。
