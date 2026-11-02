package dev.desiderium.probe.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Constructor injection deliberately avoids the P2 member-refmap problem. */
@Mixin(targets = "net.minecraft.world.World", remap = false)
public abstract class CommonProbe {
    @Inject(method = "<init>", at = @At("RETURN"), remap = false)
    private void desiderium$worldCreated(CallbackInfo ci) {
        System.out.println("[DESIDERIUM-P1] COMMON World constructor injected");
    }
}
