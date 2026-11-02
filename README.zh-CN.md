# DesideriumLoom

面向 Minecraft 1.6.4 和 DesideriumLoader 的 Gradle 开发工具，提供模组编译、发布重映射、Mixin 支持、源码生成和开发启动。

[English](README.md)

## Installation

开发模组请从 [DesideriumModTemplate](https://github.com/DesideriumMC/DesideriumModTemplate) 开始。Maven 工件发布前，模板已包含插件和开发依赖。

安装 JDK 17 用于 Gradle 和编译，安装 Java 8 用于运行游戏。将 `JAVA_HOME` 设置为 JDK 17，首次构建需要联网。

### Windows

在模组项目中运行：

```powershell
./gradlew.bat genSources genIdeaRuns
./gradlew.bat build
./gradlew.bat runClient
```

### Linux

在模组项目中运行：

```bash
./gradlew genSources genIdeaRuns
./gradlew build
./gradlew runClient
```

使用 `runServer` 启动专用服务端。IntelliJ IDEA 导入模组项目时，Gradle JVM 选择 JDK 17。

## Building the plugin

在本仓库使用 JDK 17，Windows 执行 `./gradlew.bat -p plugin build`，Linux 执行 `./gradlew -p plugin build`。产物位于 `plugin/build/libs/`。集成测试需要已配置的 Loader 开发环境。

插件 ID 为 `dev.desiderium.loom`，配置块为 `desiderium`。要在模组项目中使用本仓库源码，将 `loomPluginDir` 指向本仓库的 `plugin` 目录。

## License

基于 [Voldeloom](https://github.com/CrackedPolishedBlackstoneBricksMC/voldeloom)。见 [LICENSE](plugin/LICENSE) 和[上游说明](plugin/UPSTREAM.md)，内含组件保留各自的许可证声明。
