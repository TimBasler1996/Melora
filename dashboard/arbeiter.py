"""Der Arbeiter: liest den Code zu einem Befund und schlägt einen Patch vor.

Er schreibt nichts. Das Ergebnis ist ein Diff im Dashboard, das der Mensch
übernimmt oder verwirft. Ein Arbeiter, der unbeaufsichtigt ins Repository
schreibt, ist die Sorte Automatik, die man nachts um drei bereut.
"""
import os
import subprocess
from datetime import date
from pathlib import Path

import anthropic

import befunde
import guthaben
import protokoll
import werkzeuge

MODELL = "claude-sonnet-5"
REPO = Path(__file__).resolve().parent.parent

AUFTRAG = """Du arbeitest am iOS-Projekt Melora (SwiftUI, Firebase, Spotify) in {repo}.

Ein Prüfbericht hat diesen Befund festgehalten:

  Bereich:  {bereich}
  Schwere:  {schwere}
  Titel:    {titel}
  Beleg:    {beleg}
  Notiz:    {notiz}

Deine Aufgabe, in dieser Reihenfolge:

1. Lies den betroffenen Code mit den Werkzeugen. Prüfe den Befund, statt ihn
   zu glauben — Prüfberichte irren. Wenn er nicht zutrifft, sag das und
   begründe es; das ist ein vollwertiges Ergebnis.
2. Wenn er zutrifft: schlage genau eine Änderung vor, so klein wie möglich.
3. Antworte am Ende in genau diesem Format, ohne weitere Überschriften:

URTEIL: zutreffend | nicht zutreffend | unklar
BEGRÜNDUNG: zwei bis vier Sätze, mit Datei:Zeile belegt.
PATCH:
```diff
(unified diff gegen die Projektwurzel, oder das Wort KEINER)
```
RISIKO: ein Satz dazu, was die Änderung kaputtmachen könnte.

Regeln für den Patch:
- Schreibe echten, anwendbaren `diff -u`-Text mit `--- a/pfad` und `+++ b/pfad`.
- Kontextzeilen müssen wörtlich dem entsprechen, was du gelesen hast.
- Fasse dich. Keine Umbenennungen, keine Umbauten, keine neuen Abhängigkeiten.
- Die Sprache des Codes ist Englisch, auch in Kommentaren und UI-Text.
- Kommentare erklären das Warum, nie das Was.
"""


def _client() -> anthropic.Anthropic:
    schluessel = os.environ.get("ANTHROPIC_API_KEY")
    if not schluessel:
        datei = Path(__file__).parent / "daten" / "api_key"
        if datei.exists():
            schluessel = datei.read_text().strip()
    if not schluessel:
        raise RuntimeError("Kein ANTHROPIC_API_KEY. In die Umgebung legen oder nach dashboard/daten/api_key schreiben.")
    return anthropic.Anthropic(api_key=schluessel)


def ansetzen(befund_id: str) -> None:
    """Läuft im Hintergrundthread. Schreibt das Ergebnis in die Befundliste."""
    b = befunde.holen(befund_id)
    if not b:
        return

    tag = date.today().isoformat()
    ok, hinweis = guthaben.erlaubt(tag)
    if not ok:
        befunde.aendern(befund_id, status="offen", notiz=f"Nicht gestartet — {hinweis}")
        protokoll.log("grenze", hinweis, befund=befund_id)
        return

    befunde.aendern(befund_id, status="in Arbeit", notiz="")
    protokoll.log("start", b["titel"][:90], befund=befund_id)

    client = _client()
    nachrichten = [{"role": "user", "content": AUFTRAG.format(
        repo=REPO, bereich=b["bereich"], schwere=b["schwere"],
        titel=b["titel"], beleg=b.get("beleg") or "—", notiz=b.get("notiz") or "—",
    )}]

    ein_gesamt = aus_gesamt = 0
    antwort_text = ""

    for runde in range(24):
        antwort = client.messages.create(
            model=MODELL, max_tokens=4000,
            tools=werkzeuge.WERKZEUGE, messages=nachrichten,
        )
        ein_gesamt += antwort.usage.input_tokens
        aus_gesamt += antwort.usage.output_tokens

        lauf_kosten = guthaben.kosten(ein_gesamt, aus_gesamt)
        if lauf_kosten > guthaben.GRENZE_PRO_LAUF:
            antwort_text = (f"URTEIL: unklar\nBEGRÜNDUNG: Abgebrochen bei "
                            f"${lauf_kosten:.2f} — die Grenze pro Lauf liegt bei "
                            f"${guthaben.GRENZE_PRO_LAUF:.2f}.\nPATCH:\n```diff\nKEINER\n```\n"
                            f"RISIKO: —")
            break

        nachrichten.append({"role": "assistant", "content": antwort.content})

        if antwort.stop_reason != "tool_use":
            antwort_text = "".join(t.text for t in antwort.content if t.type == "text")
            break

        ergebnisse = []
        for block in antwort.content:
            if block.type == "tool_use":
                ausgabe = werkzeuge.ausfuehren(block.name, block.input)
                ergebnisse.append({"type": "tool_result", "tool_use_id": block.id,
                                   "content": ausgabe[:20000]})
        nachrichten.append({"role": "user", "content": ergebnisse})

    usd = guthaben.kosten(ein_gesamt, aus_gesamt)
    guthaben.buchen(tag, usd)

    urteil, patch = _zerlegen(antwort_text)
    befunde.aendern(
        befund_id,
        status="Vorschlag da" if antwort_text else "offen",
        vorschlag={"text": antwort_text, "patch": patch, "urteil": urteil,
                   "kosten": round(usd, 4), "runden": runde + 1},
    )
    protokoll.log("fertig", f"{urteil} · ${usd:.3f}", befund=befund_id)


def _zerlegen(text: str) -> tuple[str, str]:
    urteil = "unklar"
    for zeile in text.splitlines():
        if zeile.upper().startswith("URTEIL:"):
            urteil = zeile.split(":", 1)[1].strip()
            break
    patch = ""
    if "```diff" in text:
        patch = text.split("```diff", 1)[1].split("```", 1)[0].strip()
    if patch.strip() == "KEINER":
        patch = ""
    return urteil, patch


def patch_pruefen(patch: str) -> tuple[bool, str]:
    """Lässt git den Patch trocken anwenden — ohne etwas zu verändern."""
    if not patch.strip():
        return False, "Kein Patch vorhanden."
    r = subprocess.run(["git", "apply", "--check", "-"], cwd=REPO, input=patch + "\n",
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stderr or "Lässt sich sauber anwenden.").strip()


def patch_anwenden(patch: str) -> tuple[bool, str]:
    """Wendet den Patch an. Wird nur aufgerufen, wenn ein Mensch zustimmt."""
    r = subprocess.run(["git", "apply", "-"], cwd=REPO, input=patch + "\n",
                       capture_output=True, text=True)
    if r.returncode != 0:
        return False, (r.stderr or "git apply ist fehlgeschlagen.").strip()
    return True, "Angewendet. Die Änderung liegt jetzt unverbucht in der Arbeitskopie."
