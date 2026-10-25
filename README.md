# Note Origin (Kotlin)

轻量级 Android 个人笔记应用，原生 Kotlin + Jetpack Compose 重写版。

## 功能

- 日历选择日期 → 核心逻辑层产出混淆串并本地还原展示（语义与原 Swift 内核一致：XOR 0x07 可逆变换，用于混淆而非加密）
- 设置界面配置 SiliconFlow API Key（SharedPreferences 存储）
- 调用 Qwen 模型对笔记内容做 AI 总结
- Material You 动态取色（Android 12+ 取壁纸色，低版本回退默认浅色）
- 竖屏、Material 3

## 技术栈

- Kotlin 2.1 + Jetpack Compose（BOM 2025.01，Material 3）
- OkHttp（AI 请求）+ Kotlin Coroutines
- minSdk 26 / target & compile SDK 34
- 单模块 Gradle 构建（AGP 8.7，Gradle 8.14.3）

## 构建

```bash
./gradlew assembleDebug
# 产物: app/build/outputs/apk/debug/app-debug.apk
```

需要 Android SDK 34 与 JDK 17+。

## 历史

本项目前身为 Python/Kivy + Swift 混合架构版本（见 git 历史），因交叉工具链维护成本过高
（Buildozer/p4a + Swift-Android artifactbundle + 运行时 .so 依赖闭包管理）重写为纯 Kotlin。
