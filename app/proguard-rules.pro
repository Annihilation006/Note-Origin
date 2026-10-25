# okhttp/okio的一堆可选依赖警告，用不到的拒收
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn kotlin.**

# 项目里没有反射、没有序列化框架，应用类全部混淆，不写keep
