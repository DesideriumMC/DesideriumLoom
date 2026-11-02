package net.fabricmc.loom;

import org.gradle.testkit.runner.*;
import org.junit.*;
import org.junit.rules.TemporaryFolder;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.io.File;
import static org.junit.Assert.*;

/** Real template integration, opt in using the documented local Loader input properties. */
public class ProductTestKitTest {
    @Rule public TemporaryFolder tmp = new TemporaryFolder();
    private File project;
    @Before public void setup() throws Exception {
        Assume.assumeTrue("Set DESIDERIUM_TEST_PROPERTIES to run Loader integration tests", System.getenv("DESIDERIUM_TEST_PROPERTIES") != null);
        project = tmp.newFolder("new project");
        Path template = Paths.get("../templates/mod").toAbsolutePath();
        try (java.util.stream.Stream<Path> paths = Files.walk(template)) {
            paths.forEach(p -> {
                try {
                    Path target = project.toPath().resolve(template.relativize(p));
                    if (Files.isDirectory(p)) Files.createDirectories(target); else Files.copy(p, target);
                } catch (Exception e) { throw new RuntimeException(e); }
            });
        }
        Files.copy(Paths.get(System.getenv("DESIDERIUM_TEST_PROPERTIES")), project.toPath().resolve("gradle.properties"));
    }
    private void append(String text) throws Exception {
        Files.write(project.toPath().resolve("build.gradle"), text.getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);
    }
    private GradleRunner runner(String... tasks) {
        java.util.List<String> args = new java.util.ArrayList<>(java.util.Arrays.asList(tasks));
        args.add("--offline"); args.add("--stacktrace");
        args.add("--gradle-user-home"); args.add(System.getenv("DESIDERIUM_TEST_CACHE"));
        return GradleRunner.create().withProjectDir(project).withArguments(args);
    }
    @Test public void templateBuildAndPublicationUseRelease() throws Exception {
        BuildResult result = runner("build", "publish").build();
        assertNotNull(result.task(":remapJarForRelease"));
        Path release = project.toPath().resolve("build/libs/example-mod-1.0.0.jar");
        Path published = project.toPath().resolve("build/test-repository/example/example-mod/1.0.0/example-mod-1.0.0.jar");
        assertArrayEquals(Files.readAllBytes(release), Files.readAllBytes(published));
        try (java.util.stream.Stream<Path> paths = Files.walk(published.getParent())) { assertFalse(paths.anyMatch(p -> p.toString().contains("-dev"))); }
        assertEquals(TaskOutcome.UP_TO_DATE, runner("compileJava").build().task(":compileJava").getOutcome());
        byte[] first = Files.readAllBytes(release);
        runner("clean", "build").build();
        assertArrayEquals("Offline clean rebuild must reproduce release bytes", first, Files.readAllBytes(release));
    }
    @Test public void refusesDevPublication() throws Exception {
        append("\npublishing.publications.create('bad', MavenPublication) { artifact tasks.jar }\n");
        assertTrue(runner("publishBadPublicationToTestRepository").buildAndFail().getOutput().contains("Refusing to publish dev JAR"));
    }
    @Test public void java8ModRejectsLegacyLoaderClearly() throws Exception {
        String legacy = Paths.get("../../DesideriumLoader/.work/l2/build/desideriumloader-1.6.4-9.11.1.1345-L2.jar").toAbsolutePath().normalize().toString().replace('\\', '/');
        if (!Files.isRegularFile(Paths.get(legacy))) {
            // A relocated test checkout may keep the baseline beside the new Loader input.
            java.util.Properties props = new java.util.Properties();
            try (java.io.InputStream in = Files.newInputStream(Paths.get(System.getenv("DESIDERIUM_TEST_PROPERTIES")))) { props.load(in); }
            Path loader = Paths.get(props.getProperty("loaderJar"));
            Path root = loader;
            while (root != null && !root.getFileName().toString().equals(".work")) root = root.getParent();
            if (root == null) throw new IllegalStateException("Cannot locate frozen legacy Loader test input");
            legacy = root.resolve("l2/build/desideriumloader-1.6.4-9.11.1.1345-L2.jar").toString().replace('\\', '/');
        }
        append("\nconfigurations.forge.dependencies.clear()\ndependencies { forge files('" + legacy + "') }\n");
        assertTrue(runner("build").buildAndFail().getOutput().contains("Java 8 mod bytecode requires the Desiderium Java 8 Loader"));
    }
    @Test public void sanitizedLoaderGetsVerifiedLocalRuntimeData() throws Exception {
        append("\ntasks.register('verifyLocalRuntimeData') { doLast { def dirs = tasks.runServer.classpath.files.findAll { it.isDirectory() && new File(it, 'deobfuscation_data-1.6.4.lzma').isFile() }; assert dirs.size() == 1; println 'LOCAL MCP RESOURCE PASS' } }\n");
        // This test uses the sanitized, redistributable Java8 Loader configured
        // in DESIDERIUM_TEST_PROPERTIES, not the source-build-only full JAR.
        assertTrue(runner("verifyLocalRuntimeData").build().getOutput().contains("LOCAL MCP RESOURCE PASS"));
    }
    @Test public void isolatesSourceSetsAndRejectsDuplicateRefmap() throws Exception {
        append("\nsourceSets { other }\ndesiderium.mixin 'other', 'mixins.example.refmap.json'\n");
        assertTrue(runner("help").buildAndFail().getOutput().contains("Mixin refmap filename already registered"));
    }
    @Test public void reportsMissingRuntimeBeforeGameStarts() throws Exception {
        append("\nconfigurations.runtimeOnly.dependencies.clear()\n");
        assertTrue(runner("runServer").buildAndFail().getOutput().contains("Expected exactly one Desiderium Loader Mixin runtime dependency"));
    }
    @Test public void twoSourceSetsHaveSeparateApOutputs() throws Exception {
        Path mixin = project.toPath().resolve("src/main/java/example/mixin/WorldMixin.java");
        Path other = project.toPath().resolve("src/other/java/second/mixin/WorldMixin.java");
        Files.createDirectories(other.getParent());
        Files.write(other, new String(Files.readAllBytes(mixin), StandardCharsets.UTF_8).replace("package example.mixin;", "package second.mixin;").getBytes(StandardCharsets.UTF_8));
        append("\nsourceSets { other }\nconfigurations { otherImplementation.extendsFrom implementation; otherCompileOnly.extendsFrom compileOnly; otherAnnotationProcessor.extendsFrom annotationProcessor }\ndesiderium.mixin 'other', 'mixins.other.refmap.json'\ntasks.jar { from sourceSets.other.output }\n");
        runner("build").build();
        String first = new String(Files.readAllBytes(project.toPath().resolve("build/desiderium/mixin/main/mixins.example.refmap.json")), StandardCharsets.UTF_8);
        String second = new String(Files.readAllBytes(project.toPath().resolve("build/desiderium/mixin/other/mixins.other.refmap.json")), StandardCharsets.UTF_8);
        assertTrue(first.contains("example/mixin/WorldMixin")); assertFalse(first.contains("second/mixin/WorldMixin"));
        assertTrue(second.contains("second/mixin/WorldMixin")); assertFalse(second.contains("example/mixin/WorldMixin"));
        try (java.util.jar.JarFile jar = new java.util.jar.JarFile(project.toPath().resolve("build/libs/example-mod-1.0.0.jar").toFile())) {
            assertNotNull(jar.getEntry("second/mixin/WorldMixin.class"));
            assertNotNull(jar.getEntry("mixins.example.refmap.json")); assertNotNull(jar.getEntry("mixins.other.refmap.json"));
        }
    }
    @Test public void excludedRefmapCannotBeReleased() throws Exception {
        append("\ntasks.jar { exclude 'mixins.example.refmap.json' }\n");
        assertTrue(runner("build").buildAndFail().getOutput().contains("Missing Mixin refmap"));
    }
    @Test public void generatedMinecraftSourcesAreResolvableByIdeQuery() throws Exception {
        append("\ntasks.register('verifyIdeSources') { doLast {\n" +
            "def components = configurations.minecraftNamed.incoming.resolutionResult.allComponents*.id.findAll { it instanceof org.gradle.api.artifacts.component.ModuleComponentIdentifier && it.group == 'dev.desiderium.internal.minecraft' }\n" +
            "assert components.size() == 1\n" +
            "def result = dependencies.createArtifactResolutionQuery().forComponents(components).withArtifacts(org.gradle.jvm.JvmLibrary, org.gradle.language.base.artifact.SourcesArtifact).execute()\n" +
            "def sources = result.resolvedComponents.collectMany { it.getArtifacts(org.gradle.language.base.artifact.SourcesArtifact) }.findAll { it instanceof org.gradle.api.artifacts.result.ResolvedArtifactResult }\n" +
            "assert sources.size() == 1 : result\n" +
            "def jar = new java.util.jar.JarFile(sources[0].file); try { assert jar.getEntry('net/minecraft/world/World.java') != null } finally { jar.close() }\n" +
            "println 'IDE SOURCE QUERY PASS'\n} }\n");
        assertTrue(runner("verifyIdeSources").build().getOutput().contains("IDE SOURCE QUERY PASS"));
    }
}
