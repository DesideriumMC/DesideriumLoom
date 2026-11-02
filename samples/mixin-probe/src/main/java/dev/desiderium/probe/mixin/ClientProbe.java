package dev.desiderium.probe.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets = "net.minecraft.client.gui.GuiMainMenu", remap = false)
public abstract class ClientProbe {
    @Inject(method = "<init>", at = @At("RETURN"), remap = false)
    private void desiderium$menuCreated(CallbackInfo ci) {
        System.out.println("[DESIDERIUM-P1] CLIENT GuiMainMenu constructor injected");
    }
}
