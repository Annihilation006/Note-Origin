[app]
title = Note Origin
package.name = noteorigin
package.domain = org.origin
version = 0.1.0
source.dir = .
source.include_exts = py, png, jpg, kv, so, json
android.add_libs_arm64_v8a = liblogic.so, libswiftCore.so, libswiftGlibc.so, libswiftDispatch.so, libswift_Concurrency.so, libswift_StringProcessing.so, libswiftRegexBuilder.so, libFoundation.so

requirements = python3, kivy==2.3.0, kivymd==1.2.0, pyjnius, httpx

android.permissions = INTERNET, ACCESS_NETWORK_STATE, READ_EXTERNAL_STORAGE
android.api = 34
android.minapi = 26
android.archs = arm64-v8a
p4a.branch = master

[buildozer]
log_level = 2
warn_on_root = 0
