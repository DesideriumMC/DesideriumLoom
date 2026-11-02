package dev.desiderium.mappingprobe.mixin;

import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;
import org.spongepowered.asm.mixin.gen.Invoker;

@Mixin(ItemStack.class)
public interface StackAccess {
    @Accessor("itemID") int desiderium$getItemId();
    @Invoker("getItem") Item desiderium$invokeGetItem();
}
