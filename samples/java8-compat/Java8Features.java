package dev.desiderium.java8probe;

import cpw.mods.fml.common.Mod;
import cpw.mods.fml.common.event.FMLInitializationEvent;
import java.lang.annotation.*;
import java.util.Arrays;
import java.util.function.IntSupplier;
import java.util.function.IntUnaryOperator;

@Mod(modid = "desiderium_java8_probe", name = "Java 8 compatibility probe", version = "0.2.0")
public final class Java8Features {
    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.TYPE_USE)
    public @interface Marker {}
    public interface Features {
        default int value() { return 41; }
        static int increment(int value) { return value + 1; }
    }
    public static final class Implementation implements Features {}
    public @Marker String annotatedField;
    public void namedParameter(String value) {}

    @Mod.EventHandler public void init(FMLInitializationEvent event) throws Exception {
        if (!System.getProperty("java.specification.version").equals("1.8")) throw new AssertionError("Expected Java 8 game JVM");
        final int captured = 40;
        IntSupplier lambda = () -> captured + 2;
        IntUnaryOperator reference = Features::increment;
        if (lambda.getAsInt() != 42 || reference.applyAsInt(new Implementation().value()) != 42) throw new AssertionError("lambda/interface dispatch");
        if (Arrays.asList("a", "bb").stream().mapToInt(String::length).sum() != 3) throw new AssertionError("Java 8 API");
        if (Java8Features.class.getField("annotatedField").getAnnotatedType().getAnnotation(Marker.class) == null) throw new AssertionError("Lost TYPE_USE annotation");
        if (!Java8Features.class.getMethod("namedParameter", String.class).getParameters()[0].getName().equals("value")) throw new AssertionError("Lost MethodParameters");
        System.out.println("[DESIDERIUM-JAVA8] PASS lambda method-reference default-interface static-interface stream type-annotation parameters runtime8");
    }
}
