"""Package the qualified local Maven repository; exclude mutable Maven metadata."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

sha = lambda b: hashlib.sha256(b).hexdigest()


def main(a):
    def entries(base):
        return {p.relative_to(base).as_posix(): (p.read_bytes().replace(b"\r", b"") if p.suffix == ".pom" else p.read_bytes()) for p in sorted(base.rglob("*"))
                if p.is_file() and "0.1.0-rc2" in p.parts and p.suffix in [".jar", ".pom", ".module"]}
    windows, linux = entries(a.windows), entries(a.linux)
    assert windows and windows == linux, "Published plugin differs between platforms"
    probes = [json.loads(p.read_text()) for p in [a.windows_probe / "acceptance.json", a.linux_probe / "acceptance.json"]]
    assert all(p["status"] == "passed" for p in probes)
    assert probes[0]["pluginSha256"] == probes[1]["pluginSha256"]
    assert probes[0]["releaseSha256"] == probes[1]["releaseSha256"]
    a.output.mkdir(parents=True, exist_ok=True)
    payload = {"maven/" + n: data for n, data in windows.items()}
    payload[a.source.name] = a.source.read_bytes()
    root = Path(__file__).resolve().parents[1]
    for name in ["LICENSE", "UPSTREAM.md"]: payload[name] = (root / "plugin" / name).read_bytes()
    payload["INSTALL.md"] = b"""# Desiderium Loom 0.1.0-rc2

Extract this archive and use the enclosed maven/ directory as a Gradle plugin
repository. In settings.gradle's pluginManagement.repositories add:
    maven { url = uri('/absolute/path/to/maven') }
Then in build.gradle use:
    plugins { id 'dev.desiderium.loom' version '0.1.0-rc2' }
Do not also includeBuild the development plugin. Use the supplied mod template,
Gradle 8.9, build JDK 17, compile JDK 11 and game Java 8. Plugin dependencies are
downloaded from the template repositories; offline builds need a prepared cache.
This release is derived from Voldeloom, not an upstream Voldeloom release.
Corresponding source and upstream notices accompany this package.
"""
    payload["SHA256SUMS"] = "".join(sha(data) + "  " + n + "\n" for n, data in sorted(payload.items())).encode()
    artifact = a.output / "desiderium-loom-0.1.0-rc2.zip"
    with zipfile.ZipFile(artifact, "w", zipfile.ZIP_DEFLATED) as z:
        for n, data in sorted(payload.items()):
            info = zipfile.ZipInfo(n, (2000, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    report = dict(status="passed", archiveSha256=sha(artifact.read_bytes()),
                  platformIdentical=True, pomLineEndings="normalized LF in distribution", artifacts={n: sha(b) for n, b in windows.items()}, publicationChecks=probes)
    (a.output / "loom-release.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(status="passed", archiveSha256=report["archiveSha256"]), indent=2))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for name in ["windows", "linux", "windows-probe", "linux-probe", "source", "output"]: p.add_argument("--" + name, type=Path, required=True)
    main(p.parse_args())
