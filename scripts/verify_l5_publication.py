"""Resolve the released Gradle plugin marker from its local Maven repository."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main(a):
    out = a.output.resolve(); assert not out.exists()
    shutil.copytree(a.template, out)
    shutil.copyfile(a.properties, out / "gradle.properties")
    (out / "settings.gradle").write_text("pluginManagement { repositories { maven { url = uri('" + a.repository.resolve().as_posix() + "') }; maven { url = 'https://maven.fabricmc.net/' }; gradlePluginPortal(); mavenCentral() } }\nrootProject.name = 'example-mod'\n")
    p = out / "build.gradle"
    p.write_text(p.read_text().replace("id 'dev.desiderium.loom'", "id 'dev.desiderium.loom' version '0.1.0-rc2'"))
    command = (["cmd", "/c", str(a.gradle.resolve())] if os.name == "nt" else ["bash", str(a.gradle.resolve())])
    command += ["-p", str(out), "--gradle-user-home", str(a.cache.resolve()), "--no-daemon", "--offline", "build", "publish"]
    log = out / "verification.log"
    with log.open("w") as f:
        p = subprocess.run(command, env=dict(os.environ, JAVA_HOME=str(a.java_home.resolve())), stdout=f, stderr=subprocess.STDOUT, timeout=600)
    assert p.returncode == 0, log.read_text(errors="replace")[-4000:]
    release = out / "build/libs/example-mod-1.0.0.jar"
    published = out / "build/test-repository/example/example-mod/1.0.0/example-mod-1.0.0.jar"
    assert sha(release) == sha(published)
    artifact = a.repository / "dev/desiderium/voldeloom/0.1.0-rc2/voldeloom-0.1.0-rc2.jar"
    with zipfile.ZipFile(artifact) as z:
        assert "LICENSE" in z.namelist() and "UPSTREAM.md" in z.namelist()
        assert "META-INF/gradle-plugins/dev.desiderium.loom.properties" in z.namelist()
    report = dict(status="passed", pluginSha256=sha(artifact), releaseSha256=sha(release), logSha256=sha(log),
                  resolution="dev.desiderium.loom:0.1.0-rc2 from local Maven; no includeBuild")
    (out / "acceptance.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for name in ["repository", "template", "properties", "gradle", "java-home", "cache", "output"]: p.add_argument("--" + name, type=Path, required=True)
    main(p.parse_args())
