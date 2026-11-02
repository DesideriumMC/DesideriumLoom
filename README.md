# DesideriumLoom

Gradle tooling for Minecraft 1.6.4 and DesideriumLoader: mod compilation, release remapping, Mixin support, source generation and development runs.

[中文](README.zh-CN.md)

## Installation

For mod development, start with [DesideriumModTemplate](https://github.com/DesideriumMC/DesideriumModTemplate). It includes the plugin and development dependencies until Maven artifacts are available.

Install JDK 17 for Gradle and compilation, and Java 8 to run the game. Set `JAVA_HOME` to JDK 17. The first build requires internet access.

### Windows

Run in your mod project:

```powershell
./gradlew.bat genSources genIdeaRuns
./gradlew.bat build
./gradlew.bat runClient
```

### Linux

Run in your mod project:

```bash
./gradlew genSources genIdeaRuns
./gradlew build
./gradlew runClient
```

Use `runServer` for a dedicated server. Import the mod project into IntelliJ IDEA with JDK 17 as the Gradle JVM.

## Building the plugin

In this repository, run `./gradlew.bat -p plugin build` on Windows or `./gradlew -p plugin build` on Linux, using JDK 17. Plugin JARs are written to `plugin/build/libs/`. Integration tests require a configured Loader development environment.

The plugin ID is `dev.desiderium.loom`; its configuration block is `desiderium`. To use this checkout in a mod project, point `loomPluginDir` at this repository's `plugin` directory.

## License

Derived from [Voldeloom](https://github.com/CrackedPolishedBlackstoneBricksMC/voldeloom). See [LICENSE](plugin/LICENSE) and [upstream notices](plugin/UPSTREAM.md). Bundled components retain their respective notices.
