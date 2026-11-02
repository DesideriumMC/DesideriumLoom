"""Snapshot compact L3 automated evidence without claiming unconfirmed manual acceptance."""
import hashlib
import json
import pathlib
import shutil
import xml.etree.ElementTree as ET
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
work = root / ".work/l3"
out = root / "docs/evidence/l3"
out.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
tests = []
for path in sorted((root / "plugin/build/test-results/test").glob("TEST-*.xml")):
    suite = ET.parse(path).getroot()
    tests.append({key: suite.attrib[key] for key in ["name", "tests", "failures", "errors", "skipped"]})
    shutil.copy2(path, out / path.name)
assert sum(int(t["tests"]) for t in tests) == 19
assert all(int(t[k]) == 0 for t in tests for k in ["failures", "errors", "skipped"])
runtime = {}
for name in ["runtime-debug-002", "runtime-production", "runtime-regression", "runtime-ide-fix", "runtime-readability"]:
    result = json.loads((work / name / "result.json").read_text(encoding="utf-8"))
    assert result["passed"] and result["exitCode"] == 0
    runtime[name] = result
    shutil.copy2(work / name / "result.json", out / (name + ".json"))
    text = (work / name / "server.log").read_text(encoding="utf-8")
    markers = [line for line in text.splitlines() if any(x in line for x in ["[EXAMPLE]", "[DESIDERIUM-P0]", "[DESIDERIUM-P1]", "[DESIDERIUM-P2]", "Done (", "Saving chunks", "Stopping server"])]
    (out / (name + "-markers.log")).write_text("\n".join(markers) + "\n", encoding="utf-8")
shutil.copy2(work / "runtime-readability/debugger.log", out / "debugger.log")
sources = json.loads((work / "source-report.json").read_text(encoding="utf-8"))
assert not sources["failedFiles"]
shutil.copy2(work / "source-report.json", out / "source-report.json")
client = (work / "template-client.log").read_text(encoding="utf-8")
assert client.count("logged in with entity id") >= 2
assert "[EXAMPLE] World.getWorldTime injected" in client and "Stopping!" in client and "BUILD SUCCESSFUL" in client
(out / "client-markers.log").write_text("\n".join(line for line in client.splitlines() if any(x in line for x in ["[EXAMPLE]", "logged in with entity id", "Saving chunks", "Stopping!", "BUILD SUCCESSFUL"])) + "\n", encoding="utf-8")
artifacts = {}
for path in [root / "plugin/build/libs/voldeloom-2.5.jar", work / "fresh-mod/build/libs/example-mod-1.0.0.jar", work / "fresh-mod/build/libs/example-mod-1.0.0-dev.jar", work / "fresh-mod/build/test-repository/example/example-mod/1.0.0/example-mod-1.0.0.jar"]:
    artifacts[path.relative_to(root).as_posix()] = sha(path)
def contents(path):
    with zipfile.ZipFile(path) as jar:
        return {n: hashlib.sha256(jar.read(n)).hexdigest() for n in jar.namelist() if not n.endswith("/")}
release = work / "fresh-mod/build/libs/example-mod-1.0.0.jar"
published = work / "fresh-mod/build/test-repository/example/example-mod/1.0.0/example-mod-1.0.0.jar"
assert contents(release) == contents(published)
assert contents(release) == contents(work / "production-server/mods/example-mod-1.0.0.jar")
logs = {}
for name in ["readability-tests.log", "readability-generate-idea.log", "readability-reimport.log", "ide-fix-build-002.log", "final-build.log", "generated-build.log", "regression-build.log", "ide-client-prepare.log", "template-client.log"]:
    path = work / name
    assert "BUILD SUCCESSFUL" in path.read_text(encoding="utf-8")
    logs[name] = sha(path)
fingerprint = {}
for directory in [root / "plugin/src", root / "templates/mod"]:
    for path in sorted(directory.rglob("*")):
        if path.is_file(): fingerprint[path.relative_to(root).as_posix()] = sha(path)
manual = json.loads((out / "manual.json").read_text(encoding="utf-8"))
complete = all(item.get("status") == "passed" for item in manual.values())
report = {
    "date": "2026-10-30", "timezone": "Australia/Sydney", "stage": "L3/P3",
    "status": "complete" if complete else "awaiting-manual-acceptance", "environment": "Windows / Gradle 8.9 / build JDK 17 / compile JDK 11 release 6 / game JDK 8",
    "sourceReadability": json.loads((out / "source-readability.json").read_text(encoding="utf-8")),
    "sourceColdGenerationAudit": json.loads((out / "cold-source-generation.json").read_text(encoding="utf-8")) if (out / "cold-source-generation.json").exists() else None,
    "tests": tests, "runtime": runtime, "artifacts": artifacts, "logs": logs,
    "releaseContentMatchesPublishedAndProduction": True,
    "clientLogChecks": {"worldEntries": client.count("logged in with entity id"), "savedAndExited": True},
    "manual": manual,
    "intellijSources": json.loads((out / "intellij-source-acceptance.json").read_text(encoding="utf-8")) if complete else None,
    "sourceFingerprint": fingerprint,
    "limitations": ["Fixed Windows environment only", "Local included-build plugin distribution; L5 packaging is out of scope", "Three unreferenced anonymous helper warnings remain in Fernflower; generated Java has no failed-method stubs"]
}
(out / "acceptance.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("L3 acceptance complete" if complete else "L3 automated evidence collected; manual acceptance remains pending")
