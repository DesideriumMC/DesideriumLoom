"""Run an exported template server, assert lifecycle/injection, optionally attach JDWP."""
import argparse
import json
import pathlib
import subprocess
import threading
import time

p = argparse.ArgumentParser()
p.add_argument("launches", type=pathlib.Path)
p.add_argument("output", type=pathlib.Path)
p.add_argument("--debug-jdk", type=pathlib.Path)
p.add_argument("--marker", action="append")
a = p.parse_args()
launch = json.loads(a.launches.read_text())["server"]
a.output.mkdir(parents=True, exist_ok=True)
command = [launch["executable"], "-Xms256M", "-Xmx1G"]
if a.debug_jdk:
    command += ["-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5007"]
command += launch["jvmArgs"] + ["-cp", launch["classpath"], launch["mainClass"]] + launch["args"]
lines = []
with (a.output / "server.log").open("w", encoding="utf-8") as log:
    proc = subprocess.Popen(command, cwd=launch["directory"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    def drain():
        for line in proc.stdout:
            lines.append(line)
            log.write(line)
            log.flush()
    thread = threading.Thread(target=drain)
    thread.start()
    try:
        if a.debug_jdk:
            deadline = time.monotonic() + 30
            while not any("Listening for transport dt_socket" in line for line in lines):
                if time.monotonic() > deadline or proc.poll() is not None:
                    raise RuntimeError("JDWP did not start")
                time.sleep(0.2)
            source = pathlib.Path(__file__).with_name("L3BreakpointProbe.java").resolve()
            subprocess.run([str(a.debug_jdk / "bin/javac.exe"), "-d", str(a.output), str(source)], check=True)
            with (a.output / "debugger.log").open("w", encoding="utf-8") as debuglog:
                subprocess.run([str(a.debug_jdk / "bin/java.exe"), "--add-modules", "jdk.jdi", "-cp", str(a.output), "L3BreakpointProbe", "5007"], stdout=debuglog, stderr=subprocess.STDOUT, timeout=150, check=True)
        deadline = time.monotonic() + 120
        while not any('Done (' in line for line in lines):
            if time.monotonic() > deadline or proc.poll() is not None:
                raise RuntimeError("Server did not become ready")
            time.sleep(0.2)
        time.sleep(1)
        proc.stdin.write("stop\n")
        proc.stdin.flush()
        code = proc.wait(timeout=60)
        thread.join(timeout=10)
        text = "".join(lines)
        for marker in (a.marker or ["[EXAMPLE] initialized", "[EXAMPLE] World.getWorldTime injected"]) + ["Saving chunks", "Stopping server"]:
            if marker not in text:
                raise RuntimeError("Missing runtime marker: " + marker)
        if code != 0:
            raise RuntimeError("Server exit " + str(code))
        (a.output / "result.json").write_text(json.dumps({"passed": True, "exitCode": code, "jdwp": bool(a.debug_jdk)}, indent=2))
        print("L3 template server PASS")
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=15)
        thread.join(timeout=10)
