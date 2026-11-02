import com.sun.jdi.*;
import com.sun.jdi.connect.*;
import com.sun.jdi.event.*;
import com.sun.jdi.request.*;
import java.util.*;

/** Real JDWP breakpoints in template code and generated Minecraft sources. */
public class L3BreakpointProbe {
    public static void main(String[] args) throws Exception {
        AttachingConnector connector = Bootstrap.virtualMachineManager().attachingConnectors().stream()
            .filter(c -> c.name().equals("com.sun.jdi.SocketAttach")).findFirst().get();
        Map<String, Connector.Argument> options = connector.defaultArguments();
        options.get("hostname").setValue("127.0.0.1"); options.get("port").setValue(args[0]);
        VirtualMachine vm = connector.attach(options);
        Map<String, String> targets = new HashMap<>();
        targets.put("example.ExampleMod", "init"); targets.put("net.minecraft.world.World", "getWorldTime");
        for (String name : targets.keySet()) {
            ClassPrepareRequest request = vm.eventRequestManager().createClassPrepareRequest();
            request.addClassFilter(name); request.setSuspendPolicy(EventRequest.SUSPEND_ALL); request.enable();
        }
        Set<String> seen = new HashSet<>();
        long deadline = System.currentTimeMillis() + 120000;
        while (seen.size() < targets.size() && System.currentTimeMillis() < deadline) {
            EventSet events = vm.eventQueue().remove(2000);
            if (events == null) continue;
            for (Event event : events) {
                if (event instanceof ClassPrepareEvent) {
                    ReferenceType type = ((ClassPrepareEvent) event).referenceType();
                    Method method = type.methodsByName(targets.get(type.name())).get(0);
                    Location location = method.allLineLocations().get(0);
                    BreakpointRequest request = vm.eventRequestManager().createBreakpointRequest(location);
                    request.setSuspendPolicy(EventRequest.SUSPEND_ALL); request.enable();
                    System.out.println("ARMED " + location + " source=" + location.sourcePath());
                } else if (event instanceof BreakpointEvent) {
                    BreakpointEvent hit = (BreakpointEvent) event;
                    Location location = hit.location();
                    System.out.println("HIT " + location.declaringType().name() + "." + location.method().name() + " source=" + location.sourcePath() + ":" + location.lineNumber());
                    System.out.println("FRAME " + hit.thread().frame(0).location() + " locals=" + hit.thread().frame(0).visibleVariables());
                    seen.add(location.declaringType().name()); hit.request().disable();
                } else if (event instanceof VMDeathEvent || event instanceof VMDisconnectEvent) throw new IllegalStateException("VM exited before breakpoints: " + seen);
            }
            events.resume();
        }
        vm.dispose();
        if (seen.size() != targets.size()) throw new IllegalStateException("Missing breakpoint: " + seen);
        System.out.println("L3 JDWP PASS");
    }
}
