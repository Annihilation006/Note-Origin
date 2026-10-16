Note Origin

用 Swift 写内核、用 Python 写界面 —— 一次 Android 混合架构实验

这是什么

Note Origin 是一个跑在 Android 上的个人笔记应用。它的特别之处在于用了两种语言各干各的活：

界面是 Python 写的（Kivy + KivyMD），负责按钮、日历、弹窗、动画
核心逻辑是 Swift 写的，编译成 Android 能直接加载的 .so 共享库
两边通过 C 接口打电话通信
最后用 Buildozer 一键打包成 APK

不追求“一次编写全平台跑”，而是故意让不同语言在不同层级上各展所长。

能干什么

按日期选一条笔记，Swift 内核返回经过轻量变换的内容
支持 Android 12+ 的 Material You 动态取色，界面颜色跟着壁纸走
可以在设置里填一个 AI API Key，选完笔记后自动调用云端模型帮你提炼要点
笔记内容在 Swift 侧做过一次可逆混淆，不是明文躺在内存里

怎么跑起来的

用户点日期
↓
Python (Kivy) 层收到事件
↓
ctypes 调用 .so 里的 execute_data_purge(date, lang)
↓
Swift 层：拼接消息 → XOR 混淆 → 返回 C 字符串指针
↓
Python 层：读取指针 → 释放内存 → XOR 还原 → 显示原文
↓
子线程异步请求 AI 接口 → 主线程把结果贴到界面上

涉及的关键技术：

界面：Kivy 2.3.0 + KivyMD 1.2.0，负责 Material Design UI、日期选择器、弹窗
内核：Swift 6.3，负责字符串处理，编译为 arm64-v8a 的 .so
打包：Buildozer + NDK 25b，自动编译 Swift、打包 APK
通信：ctypes + C ABI，Python 调用 .so 函数
网络：httpx (async)，调 SiliconFlow 的 Qwen 模型
存储：Kivy JsonStore，记住你的 API Key

文件长什么样

Note-Origin-main/
main.py              应用入口：界面 + 业务逻辑都在这里
core/
Logic.swift      Swift 内核：字符串混淆与还原
buildozer.spec       Buildozer 打包配置
requirements.txt     Python 依赖清单
LICENSE              开源协议
.github/workflows/
build.yml        GitHub Actions：每次提交自动构建 APK

怎么构建

本地跑：

pip install buildozer cython==3.0.11
buildozer android debug
拿到 APK: bin/*.apk

CI 会自动做这些事：清磁盘 → 装系统依赖 → 下 Swift 工具链 → 编译 Swift 内核 → Buildozer 打包 → 上传 APK。

一点提醒

这里的“混淆”不是加密。XOR 换个编码而已，密钥就写在代码里，拿到 APK 就能还原。适合记日记、备忘这类不需要防破解的场景，不适合存密码或敏感信息。

适合看这个项目的人

想试试 Android 上 Python + Swift 混搭开发的
对 Swift for Android 工具链好奇的
想了解 Buildozer 打包流程的
想学 ctypes 跨语言调用的

从代码到编译到打包，全流程都可以在本项目里追一遍。

License

见 LICENSE。
