package example;
import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;
@Mod(modid = "example", name = "Example Mod", version = "1.0.0")
public final class ExampleMod {
    @Mod.EventHandler
    public void init(FMLInitializationEvent event) {
        System.out.println("[EXAMPLE] initialized"); // Put your first breakpoint here.
    }
}
