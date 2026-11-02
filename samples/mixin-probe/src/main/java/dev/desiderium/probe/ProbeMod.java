package dev.desiderium.probe;

import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;

@Mod(modid = "desideriump1", name = "Desiderium P1 Mixin Probe", version = "0.1.0-p1")
public final class ProbeMod {
    @Mod.EventHandler
    public void init(FMLInitializationEvent event) {
        System.out.println("[DESIDERIUM-P1] probe mod initialized");
    }
}
