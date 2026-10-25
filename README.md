# Note Origin

个人记账 + 日历笔记 + AI 助手。Flutter 一套代码跑安卓/iOS/鸿蒙/Windows/macOS/Linux，全平台同一套 Material 3 设计语言。

## 功能

- **记账**：支出/收入、分类（内置16个可扩展）、多账户、备注、任意日期补记
- **统计**：月度分类饼图、每日支出柱状图、分类排行
- **预算**：月度总预算 + 分类预算，超支高亮
- **日历笔记**：手搓月历组件，有笔记的日子打点，一天可多条
- **AI 助手**：任意 OpenAI 兼容接口（硅基流动/DeepSeek/OpenAI/Ollama），填 Base URL + Key + 模型名，一键测试连通，AI 月度消费报告
- **导出**：CSV（带BOM，Excel直接开）
- **取色**：安卓12+ 跟随壁纸 Material You 动态色，其他平台种子色

## 平台支持

| 平台 | 状态 |
|---|---|
| Android 5.0+（含7）| ✅ |
| iOS | ✅（需Mac打包）|
| 鸿蒙 | ✅（华为官方 ohos 分支）|
| Windows 10+ | ✅ |
| macOS / Linux | ✅（ffi数据库已适配）|
| Windows 7 / BSD | ❌ 框架不支持，见下 |

Win7/BSD 说明：Flutter 引擎不支持这两个目标。如果非要覆盖，只能另起 Qt5.15 薄客户端共用数据格式，不在本项目范围内。

## 构建

```bash
flutter pub get
flutter build apk --release        # 安卓
flutter build linux                # Linux桌面
flutter build windows              # 需在Windows机器上
```

## 结构

```
lib/
  main.dart          入口/主题/底部导航/桌面端ffi数据库切换
  models/            数据模型（sqflite行映射）
  data/db.dart       数据库层+建表+种子数据
  data/store.dart    全局状态（ChangeNotifier）
  services/          AI接入（OpenAI兼容chat）
  pages/             五个tab页+记一笔+AI配置
  utils/fmt.dart     金额格式化/解析等
```

金额全部按"分"存整数，不碰浮点。
