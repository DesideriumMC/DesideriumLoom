package net.fabricmc.loom;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.jar.JarFile;
import org.gradle.api.GradleException;

/** Checks the actual archive, so excluded resources and stale AP outputs cannot pass. */
final class ModValidation {
    static void loader(org.gradle.api.Project project, File mod) {
        boolean java8 = false;
        try (JarFile jar = new JarFile(mod)) {
            java.util.Enumeration<java.util.jar.JarEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                java.util.jar.JarEntry e = entries.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                try (java.io.DataInputStream in = new java.io.DataInputStream(jar.getInputStream(e))) {
                    in.readInt(); in.readUnsignedShort(); java8 |= in.readUnsignedShort() == 52;
                }
            }
            if (!java8) return;
            for (File file : project.getConfigurations().getByName(Constants.FORGE).getFiles()) {
                try (JarFile loader = new JarFile(file)) {
                    java.util.jar.JarEntry e = loader.getJarEntry("META-INF/desiderium-java.properties");
                    if (e == null) continue;
                    java.util.Properties capability = new java.util.Properties();
                    try (java.io.InputStream in = loader.getInputStream(e)) { capability.load(in); }
                    if ("8".equals(capability.getProperty("runtime")) && "52".equals(capability.getProperty("modClassMajorMax")) && "5.2".equals(capability.getProperty("asm"))) return;
                }
            }
        } catch (java.io.IOException e) { throw new GradleException("Cannot inspect Loader/mod Java compatibility", e); }
        throw new GradleException("Java 8 mod bytecode requires the Desiderium Java 8 Loader (ASM 5.2); the selected legacy Forge/Loader has no Java 8 capability. Use the new Loader or explicitly target Java 6/7.");
    }

    static void archive(File file) {
        try (JarFile jar = new JarFile(file)) {
            java.util.Enumeration<java.util.jar.JarEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                java.util.jar.JarEntry entry = entries.nextElement();
                if (!entry.getName().endsWith(".class")) continue;
                try (java.io.DataInputStream in = new java.io.DataInputStream(jar.getInputStream(entry))) {
                    if (in.readInt() != 0xCAFEBABE) throw new GradleException("Invalid class header: " + file + "!" + entry.getName());
                    int minor = in.readUnsignedShort(), major = in.readUnsignedShort();
                    if (major > 52 || minor == 65535)
                        throw new GradleException("Game runs on Java 8: unsupported class major=" + major + " in " + file + "!" + entry.getName() + "; compile with --release 8 (Java 6/7 legacy bytecode remains supported).");
                }
            }
            if (jar.getManifest() == null) return;
            String configs = jar.getManifest().getMainAttributes().getValue("DesideriumMixinConfigs");
            if (configs == null) return;
            for (String name : configs.split(",")) {
                name = name.trim();
                if (jar.getJarEntry(name) == null) throw new GradleException("Missing Mixin config '" + name + "' in " + file);
                try (InputStreamReader reader = new InputStreamReader(jar.getInputStream(jar.getJarEntry(name)), StandardCharsets.UTF_8)) {
                    JsonObject config = new JsonParser().parse(reader).getAsJsonObject();
                    if (!config.has("refmap") || jar.getJarEntry(config.get("refmap").getAsString()) == null)
                        throw new GradleException("Missing Mixin refmap for '" + name + "' in " + file + "; configure desiderium.mixin(SourceSet, refmap) and enable its annotationProcessor.");
                }
            }
        } catch (java.io.IOException e) { throw new GradleException("Cannot validate mod archive " + file, e); }
    }

    static void runtime(Iterable<File> classpath) {
        int count = 0;
        for (File file : classpath) {
            if (!file.isFile() || !file.getName().endsWith(".jar")) continue;
            try (JarFile jar = new JarFile(file)) {
                if (jar.getJarEntry("dev/desiderium/loader/LoaderMixinTweaker.class") != null) count++;
            } catch (java.io.IOException e) { throw new GradleException("Cannot inspect runtime dependency " + file, e); }
        }
        if (count != 1) throw new GradleException("Expected exactly one Desiderium Loader Mixin runtime dependency, found " + count + "; add runtimeOnly files(loaderMixinJar). Do not bundle Mixin into your mod.");
    }
}
