package dev.desiderium.mappingprobe;

import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;
import dev.desiderium.mappingprobe.mixin.StackAccess;
import net.minecraft.item.Item;
import net.minecraft.item.ItemFood;
import net.minecraft.item.ItemStack;

@Mod(modid = "desideriump2", name = "Desiderium P2 Mapping Probe", version = "0.1.0-p2")
public final class MappingProbeMod {
    public static boolean injected, redirected, overwritten, inherited;

    @Mod.EventHandler
    public void init(FMLInitializationEvent event) {
        ItemStack stack = new ItemStack(Item.appleRed);
        StackAccess access = (StackAccess) (Object) stack;
        check(access.desiderium$getItemId() == Item.appleRed.itemID, "Accessor");
        check(access.desiderium$invokeGetItem() == Item.appleRed, "Invoker descriptor");
        check(stack.getMaxStackSize() == 64 && injected && redirected, "Inject Redirect Shadow");
        check(stack.isStackable() && overwritten, "Overwrite extra mapping");
        check(((ItemFood) Item.appleRed).getHealAmount() > 0 && inherited, "Inherited member");
        System.out.println("[DESIDERIUM-P2] ALL MEMBER CHECKS PASSED");
    }

    public static void check(boolean result, String name) {
        if (!result) throw new IllegalStateException("[DESIDERIUM-P2] FAILED " + name);
        System.out.println("[DESIDERIUM-P2] PASS " + name);
    }
}
