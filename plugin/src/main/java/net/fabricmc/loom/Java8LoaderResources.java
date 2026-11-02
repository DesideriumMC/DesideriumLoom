package net.fabricmc.loom;

import java.io.*;
import java.nio.file.*;
import java.util.jar.JarFile;
import java.util.zip.ZipFile;
import org.gradle.api.Project;
import org.gradle.api.GradleException;

/** Recover restricted MCP runtime data locally, never from a redistributed dev JAR. */
final class Java8LoaderResources {
    private static final String NAME = "deobfuscation_data-1.6.4.lzma";
    private static final String EXPECTED = "34c3aa04185eeac2efc546087a1827a8b6affc9c7cbb623987526f89c275b3a9";
    static void configure(Project project) {
        try {
            boolean needed = false;
            for (File file : project.getConfigurations().getByName(Constants.FORGE).getFiles()) {
                try (JarFile jar = new JarFile(file)) {
                    needed |= jar.getJarEntry("META-INF/desiderium-java.properties") != null && jar.getJarEntry(NAME) == null;
                }
            }
            if (!needed) return;
            Path directory = WellKnownLocations.getProjectCache(project).resolve("java8-resources").resolve(EXPECTED);
            Path destination = directory.resolve(NAME);
            if (!Files.isRegularFile(destination) || !net.fabricmc.loom.util.Checksum.compareFileHexHash(destination, EXPECTED, net.fabricmc.loom.util.Checksum.SHA256.get())) {
                byte[] data = null;
                for (File file : project.getConfigurations().getByName(Constants.MAPPINGS).getFiles()) {
                    if (!file.isFile()) continue;
                    try (ZipFile zip = new ZipFile(file)) {
                        java.util.zip.ZipEntry entry = zip.getEntry("forge/fml/common/" + NAME);
                        if (entry != null) try (InputStream in = zip.getInputStream(entry); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                            byte[] bytes = new byte[65536]; int n;
                            while ((n = in.read(bytes)) != -1) out.write(bytes, 0, n);
                            data = out.toByteArray();
                        }
                    }
                }
                if (data == null || !net.fabricmc.loom.util.Checksum.bytesHexHash(data, net.fabricmc.loom.util.Checksum.SHA256.get()).equals(EXPECTED))
                    throw new GradleException("Java 8 Loader needs local MCP runtime data from the fixed Forge .1345 source archive in mappings; expected SHA-256=" + EXPECTED);
                Files.createDirectories(directory);
                Path temp = Files.createTempFile(directory, "mapping-", ".tmp");
                try {
                    Files.write(temp, data);
                    Files.move(temp, destination, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
                } finally { Files.deleteIfExists(temp); }
            }
            project.getTasks().withType(net.fabricmc.loom.task.RunTask.class).configureEach(run -> run.classpath(project.files(directory.toFile())));
        } catch (IOException e) { throw new GradleException("Cannot prepare local Java 8 Loader resources", e); }
    }
}
