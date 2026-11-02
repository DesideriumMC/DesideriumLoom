package dev.desiderium.mappingprobe.mixin;

import dev.desiderium.mappingprobe.MappingProbeMod;
import net.minecraft.item.ItemFood;
import net.minecraft.item.Item;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(ItemFood.class)
public abstract class FoodProbe extends Item {
    protected FoodProbe(int id) { super(id); }

    @Inject(method = "getHealAmount()I", at = @At("HEAD"))
    private void desiderium$inherited(CallbackInfoReturnable<Integer> callback) {
        MappingProbeMod.inherited = getMaxDamage() == 0;
    }
}
