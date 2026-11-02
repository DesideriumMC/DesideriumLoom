"""Loom release acceptance: isolated derived cache, offline rebuild and concurrent projects."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main(a):
    out = a.output.resolve()
    assert not out.exists(), "Choose a fresh output directory"
    out.mkdir(parents=True)
    cache = out / "shared gradle cache"
    (cache / "caches").mkdir(parents=True)
    shutil.copytree(a.seed_cache / "caches/modules-2", cache / "caches/modules-2")
    assert not (cache / "caches/voldeloom").exists()
    env = dict(os.environ, JAVA_HOME=str(a.java_home.resolve()))
    env.pop("GRADLE_USER_HOME", None)
    results = []

    def project(name):
        dest = out / name
        shutil.copytree(a.template, dest)
        shutil.copyfile(a.properties, dest / "gradle.properties")
        return dest

    def command(p, *tasks):
        prefix = [str(a.gradle.resolve())]
        if a.gradle.suffix == ".bat": prefix = ["cmd", "/c", str(a.gradle.resolve())]
        elif os.name != "nt": prefix = ["bash", str(a.gradle.resolve())]
        return prefix + ["-p", str(p), "--gradle-user-home", str(cache), "--no-daemon", "--console=plain", *tasks]

    def record(label, p, log):
        assert p == 0, (label, log.read_text(errors="replace")[-5000:])
        results.append(dict(check=label, passed=True, logSha256=sha(log)))
        print(label, "PASS", flush=True)

    def run(label, p, *tasks):
        log = out / (label + ".log")
        with log.open("w") as f:
            result = subprocess.run(command(p, *tasks), env=env, stdout=f, stderr=subprocess.STDOUT, timeout=1200)
        record(label, result.returncode, log)

    first = project("fresh mod with spaces")
    run("cold-derived-cache", first, "build", "publish", "genSources")
    release = first / "build/libs/example-mod-1.0.0.jar"
    published = first / "build/test-repository/example/example-mod/1.0.0/example-mod-1.0.0.jar"
    expected = sha(release)
    assert expected == sha(published)
    run("hot-offline", first, "build", "--offline")
    assert sha(release) == expected
    run("clean-offline-rebuild", first, "clean", "build", "publish", "--offline")
    assert sha(release) == expected == sha(published)
    workers = []
    for i in range(2):
        dest = project("concurrent mod " + str(i))
        log = out / ("concurrent-" + str(i) + ".log")
        f = log.open("w")
        workers.append((subprocess.Popen(command(dest, "build", "publish", "--offline"), env=env, stdout=f, stderr=subprocess.STDOUT), f, log, dest))
    for i, (p, f, log, dest) in enumerate(workers):
        p.wait(timeout=900); f.close()
        record("concurrent-" + str(i), p.returncode, log)
        assert sha(dest / "build/libs/example-mod-1.0.0.jar") == expected
    report = dict(status="passed", platform=os.name, dependencyCache="seeded locked Gradle module downloads; derived Loom cache empty at start",
                  releaseSha256=expected, results=results)
    (out / "acceptance.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for key in ["gradle", "java-home", "seed-cache", "properties", "template", "output"]:
        p.add_argument("--" + key, type=Path, required=True)
    main(p.parse_args())
