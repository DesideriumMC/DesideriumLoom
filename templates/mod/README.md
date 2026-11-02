# Desiderium mod template

For a portable pre-Maven template, use `New-DesideriumMod.ps1 -Portable`.
See [中文临时模板说明](README.zh-CN.md) for setup and migration instructions.

Supported baseline: Minecraft 1.6.4, Forge 9.11.1.1345 / DesideriumLoader Java 8 (ASM 5.2), Mixin 0.8.7, Gradle 8.9.
Run Gradle and compile with JDK 17 / --release 8; run the game with Java 8. Mod development needs only these two Java installations. Legacy Java 6/7 mod binaries remain supported by the Loader.

Generate this project with `DesideriumLoom/scripts/New-DesideriumMod.ps1`. The generator copies the pinned Gradle wrapper and writes absolute local paths in `gradle.properties`:

```properties
loomPluginDir=D:/path/to/DesideriumLoom/plugin
loaderJar=D:/path/to/desideriumloader-java8.jar
loaderMixinJar=D:/path/to/desiderium-loader-mixin-0.8.7-0.1.0-l2.jar
org.gradle.java.installations.paths=C:/path/to/jdk-17,C:/path/to/jdk-8
```

The included build references the local plugin source. Historical L5 plugin/player archives remain frozen; the Java 8 changes require the new plugin source and Java 8 Loader. The generator checks the Loader capability before creating a project.

```powershell
$env:JAVA_HOME = 'C:/path/to/jdk-17'
./gradlew.bat build publish genSources genIdeaRuns
./gradlew.bat runClient
./gradlew.bat runServer
```

`build/libs/example-mod-1.0.0.jar` is the SRG release mod. The `-dev.jar` uses MCP names and is only for development.
`publish` writes release to `build/test-repository`; the plugin rejects a publication containing the dev JAR.
The default `mod` publication includes direct external api/implementation/runtimeOnly dependencies and original mod coordinates from modImplementation/modRuntimeOnly. File dependencies and game libraries are not published. Configure custom POM metadata for dependency exclusions, classifiers or other advanced Maven features.

Import this directory as a Gradle project in IntelliJ, using Gradle JVM 17. Run `genSources`, then reload the Gradle project to attach generated Minecraft/Forge sources and line-number-adjusted binaries. Generated sources are local caches and must not be published.
Set a breakpoint on the println in `example.ExampleMod.init`, then run:

```powershell
./gradlew.bat runServer --debug-jvm
```

Attach IntelliJ's Remote JVM Debug to `localhost:5005` with module `example-mod.main`. The game waits until the debugger attaches. Resume after checking the event parameter. After world generation, `stop` saves and closes the server. Client debugging uses `runClient --debug-jvm` in the same way.
For a Minecraft breakpoint, open `net.minecraft.world.World.getWorldTime` from generated sources. Reload Gradle after `genSources` before starting the debug process.

For additional Mixin SourceSets, create the SourceSet first, configure its compileOnly/annotationProcessor dependencies, call `desiderium.mixin 'name', 'unique.refmap.json'`, and include its output in `jar`. Each SourceSet owns its AP outputs. Duplicate SourceSets/refmap filenames fail early. Mixin configuration JSON must name the same refmap, and register each config with `desiderium.mixinConfig 'mixins.name.json'`. This writes `DesideriumMixinConfigs` and enables development discovery before game classes load.

To migrate a `volde` build, use plugin ID `dev.desiderium.loom`, rename the block to `desiderium`, retain dependency configurations and `runs`, and remove custom code selecting/publishing `jar`. This is a new DSL entry point; old ForgeGradle `minecraft {}` is not emulated.


IDE source attachment uses a project-local Maven module and sources classifier. Use the same Gradle user home for genSources and IntelliJ import, then reload Gradle. Import your mod project, not the plugin source project. Local Minecraft modules are development caches and must not be published.


IntelliJ source download setting: Settings (Ctrl+Alt+S) > Advanced Settings > Build Tools. Gradle > Download sources. Enable it and reload Gradle, then reopen World. JetBrains documents this as the project dependency source download setting; Attach scripts dependencies sources applies only to buildscript dependencies. See https://www.jetbrains.com/help/idea/advanced-settings.html .

Java 8 mods require the new Loader capability marker and global ASM 5.2. Selecting an old Loader for Java 8 output fails with an explicit build error. Java 9+ class files are rejected before publication/launch. The Java 8 remap path preserves TYPE_USE annotations, MethodParameters and interface method invocation information. Ordinary mod dependencies still must be compatible with Java 8 and the selected Forge API.

The Java 8 handoff package includes sanitized developer JARs under dev/. Loom recovers the required MCP runtime resource locally from the fixed Forge source mapping dependency and validates its SHA-256, without redistributing the data. Ordinary mod developers do not need the legacy Loader reconstruction toolchain.
