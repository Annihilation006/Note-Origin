# Note Origin

轻量级 Android 个人笔记应用，Kotlin + Jetpack Compose 原生实现。

## 功能

- **日历笔记**：选择日期解密展示当日笔记内容
- **AI 助手**：接入 SiliconFlow 等 OpenAI 风格接口，对笔记内容做智能总结
- **设置**：应用内直接配置 API Key，即配即用
- **界面**：Material 3 设计，Material You 动态取色（Android 12+ 跟随壁纸），深浅色自适应
- 竖屏布局，数据本地存储

## 技术栈

- Kotlin 2.1 / Jetpack Compose（Material 3）
- OkHttp + Coroutines
- minSdk 26 / targetSdk 34

## 构建

```
./gradlew assembleDebug
```

产物在 `app/build/outputs/apk/debug/`。需要 Android SDK 34 与 JDK 17+。

## 目录

```
app/src/main/java/org/origin/noteorigin/
  MainActivity.kt   界面与交互
  CoreLogic.kt      核心逻辑层
  AiClient.kt       AI 请求
```
