| 组件                    | 项目 (flutter-music)     | Dockerfile                |
|-----------------------|------------------------|---------------------------|
| Flutter SDK           | 3.44.1                 | `3.44.1`                  |
| Dart                  | >=3.10.0               | 随 Flutter 捆绑              |
| JDK                   | 21 (temurin)           | `openjdk-21-jdk-headless` |
| compileSdk            | 36                     | `platforms;android-36`    |
| build-tools           | -                      | `build-tools;36.0.0`      |
| NDK                   | 29.0.14206865          | `ndk;29.0.14206865`       |
| Kotlin / AGP / Gradle | 2.3.21 / 9.2.1 / 9.5.1 | 由项目 wrapper 自动下载          |

**使用方式：**

```bash
# 构建镜像
docker build -t flutter-build flutter

# 构建 APK（挂载 Flutter 项目源码）
docker run --rm -v ~/flutter-music:/app flutter-build \
  flutter build apk --release --target-platform android-arm64
```

构建产物将输出到宿主机的 `~/flutter-music/build/app/outputs/flutter-apk/` 目录。