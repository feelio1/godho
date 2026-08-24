# Kakao Map SDK — required so its native map classes survive code
# shrinking/obfuscation in release builds (see kakao_map_sdk README).
-keep class com.kakao.vectormap.** { *; }
-keep interface com.kakao.vectormap.**
