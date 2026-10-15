"""Check source resources, optional built app, and blobs waiting to be pushed.

Run before syncing: python3 tools/CFVCheckProjectSize.py
Also check an archive: add --app /path/to/Crealfanvar.app
Uses only Python's standard library and Git; does not change the repository.
"""

import argparse
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
MIB = 1024 * 1024


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def directory_size(directory):
    return sum(path.stat().st_size for path in directory.rglob("*") if path.is_file())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=pathlib.Path)
    parser.add_argument("--base", default="origin/main", help="Already published Git reference")
    arguments = parser.parse_args()
    failures = []

    def check(label, size, limit):
        print(f"{label}: {size / MIB:.2f} MiB / {limit / MIB:.0f} MiB budget")
        if size > limit:
            failures.append(f"{label} exceeds its size budget")

    resources = ROOT / "Crealfanvar/Resources"
    check("Runtime resources", directory_size(resources), 8 * MIB)
    check("Creature artwork", directory_size(resources / "Creatures"), 7 * MIB)

    # Check the working tree, including newly staged files. Deleted files are skipped.
    for name in git("ls-files", "-z").decode().split("\0"):
        path = ROOT / name
        if name and path.is_file() and path.stat().st_size > 20 * MIB:
            failures.append(f"Tracked file exceeds 20 MiB: {name}")

    # Deleting a large file in a later commit does not remove its earlier blob.
    # Inspect every unpublished object, not just the current file list.
    if subprocess.run(["git", "rev-parse", "--verify", arguments.base], cwd=ROOT,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        failures.append(f"Cannot verify published base {arguments.base}; pass --base explicitly")
    else:
        objects = git("rev-list", "--objects", "HEAD", "--not", arguments.base)
        details = subprocess.check_output(
            ["git", "cat-file", "--batch-check=%(objecttype) %(objectsize) %(rest)"],
            input=objects, cwd=ROOT
        )
        largest = 0
        for line in details.decode().splitlines():
            kind, size, *name = line.split(" ", 2)
            if kind == "blob":
                largest = max(largest, int(size))
                if int(size) > 20 * MIB:
                    failures.append(f"Unpublished Git blob exceeds 20 MiB: {''.join(name)}")
        check("Largest unpublished Git blob", largest, 20 * MIB)

    if arguments.app:
        if not (arguments.app / "Info.plist").is_file():
            failures.append(f"Not a built app: {arguments.app}")
        else:
            check("Built app (uncompressed)", directory_size(arguments.app), 12 * MIB)

    for failure in failures:
        print("FAIL:", failure, file=sys.stderr)
    if failures:
        return 1
    print("PASS: project size budgets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
