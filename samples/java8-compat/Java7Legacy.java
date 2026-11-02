package dev.desiderium.java7probe;
@cpw.mods.fml.common.Mod(modid="desiderium_java7_probe",name="Java 7 legacy probe",version="1.0")
public final class Java7Legacy {
    @cpw.mods.fml.common.Mod.EventHandler
    public void init(cpw.mods.fml.common.event.FMLInitializationEvent event) {
        System.out.println("[DESIDERIUM-JAVA7] PASS legacy major51 on Java8");
    }
}
