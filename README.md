# Note Origin

个人记账 + 日历笔记 + AI 助手。

## 功能

**记账**
- 支出 / 收入记录，按天分组展示，月度收支结余一目了然
- 内置常用分类（餐饮、交通、购物、娱乐等 16 个），支持自定义
- 多账户（现金 / 支付宝 / 微信 / 银行卡，可自行添加）
- 支持补记任意历史日期，长按删除，点击编辑

**统计**
- 月度分类支出饼图
- 每日支出柱状图
- 分类排行与占比

**预算**
- 月度总预算 + 分类预算
- 已用 / 剩余进度，超支高亮提醒

**日历笔记**
- 月历视图，有笔记的日期自动打点
- 一天可记多条，随时补充

**AI 助手**
- 支持三种接口格式：OpenAI 兼容 / Anthropic Messages / Gemini generateContent
- 硅基流动、DeepSeek、OpenAI、Claude、Gemini、本地 Ollama / vLLM 均可接入
- 自定义 Base URL、API Key、模型名，一键测试连通
- AI 月度消费报告：消费习惯总结、省钱建议、下月预算参考

**其他**
- 今日页每日一句（Hitokoto 一言，无网络时自动切本地句库）
- CSV 导出（Excel 可直接打开）
- 深色模式，Android 12+ 跟随壁纸动态取色
- 数据全部本地存储

## 平台

Android 5.0+ / iOS / HarmonyOS / Windows / macOS / Linux，同一套界面与交互。

## 构建

```
flutter pub get
flutter build apk --release
```

## 目录

```
lib/
  main.dart       入口、主题、导航
  models/         数据模型
  data/           数据库与全局状态
  services/       AI 接入、同步预留、本地存储
  pages/          页面
  utils/          工具函数
```
