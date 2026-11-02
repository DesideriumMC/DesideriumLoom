# Maven 发布前的临时 Gradle 模板

面向 Minecraft 1.6.4 / DesideriumLoader Java 8。Gradle 8.9 使用 JDK 17，模组编译为 Java 8，游戏使用 Java 8。

在工作区根目录执行（将两个 JAR 路径替换为当前 Java 8 开发包的工件）：

```powershell
./DesideriumLoom/scripts/New-DesideriumMod.ps1 `
  -Directory 'D:/mods/MyMod' `
  -LoaderJar 'D:/sdk/dev/desideriumloader-java8.jar' `
  -LoaderMixinJar 'D:/sdk/dev/desiderium-loader-mixin.jar' `
  -Portable
```

`-Portable` 将 Loom 插件源码复制到 `build-tools/loom`，两个本地工件复制到 `libs`，并生成相对路径配置和 Gradle Wrapper。生成后可以移动整个目录，也可以压缩交给其他开发者；不再依赖原工作区，不需要将自有工件发布至 Maven。请选择开发包中已清理的工件，开发包不应包含 MCP 数据或游戏缓存。

不传 `-Portable` 时保留原来的工作区联调模式，引用本机插件源码和 JAR 的绝对路径。

## 构建和运行

设置 `JAVA_HOME` 为 JDK 17。在生成项目的 `gradle.properties` 中填写本机 JDK 路径（使用正斜杠）：

```properties
org.gradle.java.installations.paths=C:/Java/jdk-17,C:/Java/jdk-8
org.gradle.java.installations.auto-download=false
```

```powershell
./gradlew.bat build
./gradlew.bat genSources genIdeaRuns
./gradlew.bat runClient
./gradlew.bat runServer
```

首次构建需联网获取 Gradle、第三方库及 Forge 映射。此模板不包含离线依赖缓存。Linux/macOS 使用 `sh ./gradlew`。

修改 `settings.gradle` 中的项目名、`build.gradle` 中的 group/version，以及 `src/main` 中的示例模组、Mixin 配置和 refmap 名称。正式模组产物为 `build/libs/<项目名>-<版本>.jar`；`-dev.jar` 供开发使用。

## 切换到 Maven

工件正式发布后，用实际 Maven 仓库和插件版本替换 `settings.gradle` 的 `includeBuild` 配置，再将 `forge files(loaderJar)` 和 `runtimeOnly files(loaderMixinJar)` 改为发布坐标，并移除相应本地文件检查。届时可删除 `build-tools/loom`、`libs` 和三个本地路径属性。具体坐标以正式发布为准。

更多 IDE、断点、Mixin 和发布说明见 [README.md](README.md)。
