package dev.desiderium.bootstrap;

import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.jar.JarFile;
import java.util.jar.Manifest;
import net.minecraft.launchwrapper.ITweaker;
import net.minecraft.launchwrapper.Launch;
import net.minecraft.launchwrapper.LaunchClassLoader;
import org.spongepowered.asm.launch.MixinTweaker;
import org.spongepowered.asm.mixin.Mixins;

/** P1 experiment: one shared Mixin runtime, loaded through Forge's cascading tweaker path. */
public final class DesideriumTweaker implements ITweaker {
    private final MixinTweaker delegate;

    public DesideriumTweaker() {
        Launch.classLoader.addClassLoaderExclusion("dev.desiderium.internal.");
        org.apache.logging.log4j.core.config.Configurator.setRootLevel(org.apache.logging.log4j.Level.INFO);
        delegate = new MixinTweaker();
        System.out.println("[DESIDERIUM-P1] bootstrap constructed");
    }

    public void acceptOptions(List<String> args, File gameDir, File assetsDir, String profile) {
        delegate.acceptOptions(args, gameDir, assetsDir, profile);
        String developmentConfigs = System.getProperty("desiderium.mixin.configs", "");
        addConfigs(developmentConfigs);
        File mods = new File(gameDir == null ? new File(".") : gameDir, "mods");
        File[] jars = mods.listFiles();
        if (jars == null) return;
        Arrays.sort(jars);
        for (File file : jars) {
            if (!file.getName().endsWith(".jar")) continue;
            try {
                JarFile jar = new JarFile(file);
                try {
                    Manifest manifest = jar.getManifest();
                    String configs = manifest == null ? null : manifest.getMainAttributes().getValue("DesideriumMixinConfigs");
                    if (configs != null) {
                        Launch.classLoader.addURL(file.getCanonicalFile().toURI().toURL());
                        // It is now on the classpath for early config loading,
                        // but FML must discover its @Mod only once, in mods/.
                        Class<?> manager = Class.forName("cpw.mods.fml.relauncher.CoreModManager", true, Launch.classLoader);
                        @SuppressWarnings("unchecked")
                        List<String> reparseable = (List<String>) manager.getMethod("getReparseableCoremods").invoke(null);
                        if (!reparseable.contains(file.getName())) reparseable.add(file.getName());
                        addConfigs(configs);
                    }
                } finally { jar.close(); }
            } catch (Exception e) {
                throw new IllegalStateException("Cannot discover Mixin configs in " + file, e);
            }
        }
    }

    private static void addConfigs(String configs) {
        for (String config : configs.split(",")) {
            if (config.trim().length() != 0) Mixins.addConfiguration(config.trim());
        }
    }

    public void injectIntoClassLoader(LaunchClassLoader loader) {
        // Explicit development --tweakClass does not traverse CoreModManager's
        // manifest discovery path, so register the same scanner exclusion here.
        try {
            File self = new File(DesideriumTweaker.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            Class<?> manager = Class.forName("cpw.mods.fml.relauncher.CoreModManager", true, loader);
            @SuppressWarnings("unchecked")
            List<String> ignored = (List<String>) manager.getMethod("getLoadedCoremods").invoke(null);
            if (!ignored.contains(self.getName())) ignored.add(self.getName());
        } catch (Exception e) {
            throw new IllegalStateException("Cannot exclude shared runtime from Forge ASM4 discovery", e);
        }
        delegate.injectIntoClassLoader(loader);
        System.out.println("[DESIDERIUM-P1] transformer chain=" + loader.getTransformers());
    }
    public String getLaunchTarget() { return delegate.getLaunchTarget(); }
    public String[] getLaunchArguments() { return delegate.getLaunchArguments(); }
}
