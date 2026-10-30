#!/usr/bin/env python3
"""Regenerates Packages, Packages.gz and Packages.bz2 from every .deb in ./debs.

Usage: put a new .deb into debs/, run  python3 update-repo.py  and commit the result.
Only the Python 3 standard library is needed (no dpkg required).
"""
import bz2, gzip, hashlib, io, os, tarfile

ROOT = os.path.dirname(os.path.abspath(__file__))
DEBS = os.path.join(ROOT, "debs")


def read_control(path):
    """Returns the control file of a .deb (an 'ar' archive holding control.tar.*)."""
    with open(path, "rb") as f:
        if f.read(8) != b"!<arch>\n":
            raise SystemExit("not a .deb file: " + path)
        while True:
            hdr = f.read(60)
            if len(hdr) < 60:
                break
            name = hdr[:16].decode().strip().rstrip("/")
            size = int(hdr[48:58].decode().strip())
            data = f.read(size)
            if size % 2:
                f.read(1)
            if name.startswith("control.tar"):
                with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tar:
                    for member in tar.getmembers():
                        if os.path.basename(member.name) == "control":
                            return tar.extractfile(member).read().decode("utf-8").strip("\n")
    raise SystemExit("no control file in " + path)


def stanza(path):
    with open(path, "rb") as f:
        blob = f.read()
    rel = "debs/" + os.path.basename(path)
    return "\n".join([
        read_control(path),
        "Filename: " + rel,
        "Size: " + str(len(blob)),
        "MD5sum: " + hashlib.md5(blob).hexdigest(),
        "SHA1: " + hashlib.sha1(blob).hexdigest(),
        "SHA256: " + hashlib.sha256(blob).hexdigest(),
    ])


def main():
    debs = sorted(n for n in os.listdir(DEBS) if n.endswith(".deb"))
    if not debs:
        raise SystemExit("no .deb files in " + DEBS)
    text = "\n\n".join(stanza(os.path.join(DEBS, n)) for n in debs) + "\n\n"
    raw = text.encode("utf-8")
    with open(os.path.join(ROOT, "Packages"), "wb") as f:
        f.write(raw)
    with open(os.path.join(ROOT, "Packages.gz"), "wb") as f:
        f.write(gzip.compress(raw, 9, mtime=0))
    with open(os.path.join(ROOT, "Packages.bz2"), "wb") as f:
        f.write(bz2.compress(raw, 9))
    print("Packages, Packages.gz, Packages.bz2 updated for %d package file(s):" % len(debs))
    for n in debs:
        print("  " + n)


if __name__ == "__main__":
    main()
