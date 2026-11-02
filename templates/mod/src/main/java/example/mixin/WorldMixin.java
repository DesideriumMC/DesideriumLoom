package example.mixin;
import net.minecraft.world.World;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(World.class)
public abstract class WorldMixin {
    private boolean example$reported;
    @Inject(method = "getWorldTime", at = @At("HEAD"))
    private void example$time(CallbackInfoReturnable<Long> callback) {
        if (!example$reported) {
            example$reported = true;
            System.out.println("[EXAMPLE] World.getWorldTime injected");
        }
    }
}
