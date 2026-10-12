#!/usr/bin/env python3
"""Pipeline reproducible: descarga y verifica modelos de dinosaurio (CC0).

Uso:
    python tools/fetch_models.py            # descarga (si falta) y regenera el manifiesto
    python tools/fetch_models.py --check    # solo verifica el manifiesto y los archivos (no descarga)

Fuentes: Poly Pizza (autor Quaternius), licencia Public Domain (CC0).
No se descarga nada sin que la licencia este declarada aqui como CC0.
"""
import argparse
import hashlib
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(ROOT, "tools", "models")
MANIFEST = os.path.join(ROOT, "tools", "models_manifest.json")

# Fuentes verificadas manualmente (Poly Pizza, autor Quaternius, CC0).
MODELS = [
    {
        "species": "trex",
        "url": "https://static.poly.pizza/34eed102-48f0-43dd-bc6f-ef7a6dfddfbb.glb",
        "source_page": "https://poly.pizza/m/UYtneO5FpF",
        "license": "CC0",
        "author": "Quaternius",
    },
    {
        "species": "velociraptor",
        "url": "https://static.poly.pizza/c1f0c4cb-c84f-415c-8323-d8cb871a2126.glb",
        "source_page": "https://poly.pizza/m/cnlGH2UcDd",
        "license": "CC0",
        "author": "Quaternius",
    },
    {
        "species": "triceratops",
        "url": "https://static.poly.pizza/6aa1f3ff-b9b3-4bb5-9d85-b2ffa514f0cc.glb",
        "source_page": "https://poly.pizza/m/IGvrUqGrRM",
        "license": "CC0",
        "author": "Quaternius",
    },
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": "DinoRacer-Pipeline/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
        f.write(r.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="solo verificar, no descargar")
    args = ap.parse_args()

    os.makedirs(MODELS_DIR, exist_ok=True)
    entries = []
    ok = True

    for m in MODELS:
        if m["license"] != "CC0":
            print("[SKIP] %s: licencia '%s' no permitida por la politica." % (m["species"], m["license"]))
            ok = False
            continue
        dest = os.path.join(MODELS_DIR, m["species"] + ".glb")
        status = "existe"
        if not os.path.exists(dest):
            if args.check:
                status = "FALTA (check)"
                ok = False
            else:
                try:
                    print("[GET ] %s <- %s" % (m["species"], m["url"]))
                    download(m["url"], dest)
                    status = "descargado"
                except Exception as e:
                    print("[FAIL] %s: %s" % (m["species"], e))
                    status = "error: %s" % e
                    ok = False
        size = os.path.getsize(dest) if os.path.exists(dest) else 0
        digest = sha256(dest) if os.path.exists(dest) else ""
        print("[OK  ] %-14s %-12s %8d bytes  sha256=%s" % (m["species"], status, size, digest[:12]))
        entries.append({
            "species": m["species"],
            "file": os.path.relpath(dest, ROOT).replace("\\", "/"),
            "url": m["url"],
            "source_page": m["source_page"],
            "author": m["author"],
            "license": m["license"],
            "bytes": size,
            "sha256": digest,
            "status": status,
        })

    manifest = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "policy": "Solo modelos con licencia CC0 declarada.",
        "models": entries,
    }
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print("Manifiesto: %s" % MANIFEST)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
