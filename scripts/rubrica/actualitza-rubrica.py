#!/usr/bin/env python3
"""actualitza-rubrica.py — Genera la rúbrica d'autoavaluació individual amb l'estat actual.

Entrades:
  - rubrica/original/Rubrica-autoavaluacio-Individual.html  (la rúbrica del professorat, sense tocar)
  - rubrica/estat.json  (marques per acció i observacions per tasca)
Eixides:
  - rubrica/Rubrica-autoavaluacio-Individual-Ivan.html  (la mateixa rúbrica amb les marques ja posades)
  - rubrica/seguiment-individual-Ivan.txt  (fitxer de seguiment: s'obri amb «Obri fitxer» i carrega
    també les observacions de cada tasca)

No es modifica el codi de la rúbrica: només les dades inicials («seed») de la configuració.
Marques: 0 = Pendent · 1 = Feta correctament · 2 = No feta correctament.
Ús: python3 scripts/rubrica/actualitza-rubrica.py
"""
import html
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "rubrica/original/Rubrica-autoavaluacio-Individual.html"
ESTAT = ROOT / "rubrica/estat.json"
OUT_HTML = ROOT / "rubrica/Rubrica-autoavaluacio-Individual-Ivan.html"
OUT_TXT = ROOT / "rubrica/seguiment-individual-Ivan.txt"

page = SRC.read_text(encoding="utf-8")
estat = json.loads(ESTAT.read_text(encoding="utf-8"))

m = re.search(r'(<iframe id="codex-visualization"[^>]*?data-srcdoc=")(.*?)(")', page, re.S)
if not m:
    sys.exit("No trobe l'iframe de la rúbrica")
inner = html.unescape(m.group(2))
cm = re.search(r'(<script type="application/json" id="thinklab-config">)(.*?)(</script>)', inner, re.S)
config = json.loads(cm.group(2))

ids = {a["id"] for a in config["actions"]}
marks = estat["marks"]
for k, v in marks.items():
    if k not in ids:
        sys.exit(f"Acció desconeguda a estat.json: {k}")
    if v not in (0, 1, 2):
        sys.exit(f"Marca invàlida per a {k}: {v}")

seed = config["seed"]
seed["marks"].update(marks)
seed["names"]["Individual"] = estat["nom"]
config["identity"]["name"] = estat["nom"]

new_cfg = json.dumps(config, ensure_ascii=False).replace("<", "\\u003c")
inner2 = inner[:cm.start(2)] + new_cfg + inner[cm.end(2):]
page2 = page[:m.start(2)] + html.escape(inner2, quote=True) + page[m.end(2):]
page2 = page2.replace("<title>Guia Individual Font</title>",
                      f"<title>Rúbrica individual · {estat['nom']}</title>", 1)
OUT_HTML.write_text(page2, encoding="utf-8")

state = {
    "task": 0, "mode": "Individual",
    "names": {"Grupal": "", "Individual": estat["nom"]},
    "marks": seed["marks"], "reviewed": {}, "reviewResult": {},
    "notes": {f"Individual:{t}": txt[:5000] for t, txt in estat["notes"].items()},
    "descriptions": {}, "removed": {}, "custom": [], "enabled": {},
    "delivery": {}, "groupGrades": seed.get("groupGrades", {}),
}
doc = {"format": "thinklab-editor-guide", "version": 1, "role": config["role"],
       "templateId": config["templateId"],
       "savedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
       "state": state}
OUT_TXT.write_text(json.dumps(doc, ensure_ascii=False, indent=1), encoding="utf-8")

# Resum per consola
act = [a for a in config["actions"] if a["enabled"]]
for lvl in ("Apte", "Apte+"):
    tot = [a for a in act if a["level"] == lvl]
    fet = [a for a in tot if seed["marks"].get(a["id"]) == 1]
    print(f"{lvl:6}: {len(fet):3} fetes de {len(tot)}")
print("Per mòdul-RA (Apte fetes / total):")
for k in ("FDM-RA1", "FDM-RA4", "ISO-RA1", "ISO-RA3", "ISO-RA6"):
    tot = [a for a in act if a["level"] == "Apte" and k in a["links"]]
    fet = [a for a in tot if seed["marks"].get(a["id"]) == 1]
    print(f"  {k}: {len(fet)}/{len(tot)}")
print(f"Generats:\n  {OUT_HTML}\n  {OUT_TXT}")
