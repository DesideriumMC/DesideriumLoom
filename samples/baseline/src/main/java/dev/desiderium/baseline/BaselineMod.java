package dev.desiderium.baseline;

import cpw.mods.fml.common.FMLLog;
import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;
import net.minecraft.item.Item;

/** A common-side marker exercises both FML discovery and Minecraft member remapping. */
@Mod(modid = "desideriumbaseline", name = "DesideriumLoom P0 Baseline", version = "0.1.0")
public final class BaselineMod {
    @Mod.Init
    public void initialize(FMLInitializationEvent event) {
        FMLLog.info("[DESIDERIUM-P0] initialized; diamond item ID=%d", Item.diamond.itemID);
    }
}
