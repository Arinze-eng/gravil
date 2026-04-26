# Keep tun2socks engine + gomobile glue
-keep class engine.** { *; }
-keep class go.** { *; }

# Keep Flutter embedding
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
