"""Die Befundliste. Eine JSON-Datei, kein Dienst: sie muss einen Neustart
überstehen und von Hand lesbar bleiben."""
import hashlib
import json
import os
import tempfile
import threading
from pathlib import Path

PFAD = Path(__file__).parent / "daten" / "befunde.json"

# Streamlit liest bei jedem Klick neu, während Arbeiter im Hintergrundthread
# schreiben. Ohne diese beiden Vorkehrungen liest die Oberfläche irgendwann
# eine halb geschriebene Datei — und stürzt mit JSONDecodeError ab.
_sperre = threading.RLock()

STATUS = ["offen", "in Arbeit", "Vorschlag da", "übernommen", "verworfen"]
SCHWERE_RANG = {"high": 0, "medium": 1, "low": 2}


def laden() -> list:
    """Nie ohne Netz: eine unlesbare Datei darf die Oberfläche nicht fällen."""
    if not PFAD.exists():
        return []
    try:
        return json.loads(PFAD.read_text())
    except (json.JSONDecodeError, OSError):
        sicherung = PFAD.with_suffix(".json.kaputt")
        try:
            PFAD.replace(sicherung)
        except OSError:
            pass
        return []


def speichern(liste: list) -> None:
    """Erst daneben schreiben, dann umbenennen. os.replace ist atomar, also
    sieht ein gleichzeitiger Leser entweder den alten oder den neuen Stand —
    nie etwas dazwischen."""
    PFAD.parent.mkdir(exist_ok=True)
    with _sperre:
        fd, vorlaeufig = tempfile.mkstemp(dir=PFAD.parent, prefix=".befunde-", suffix=".json")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(liste, f, ensure_ascii=False, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(vorlaeufig, PFAD)
        except BaseException:
            Path(vorlaeufig).unlink(missing_ok=True)
            raise


def holen(befund_id: str) -> dict | None:
    return next((b for b in laden() if b["id"] == befund_id), None)


def aendern(befund_id: str, **felder) -> None:
    with _sperre:
        liste = laden()
        for b in liste:
            if b["id"] == befund_id:
                b.update(felder)
        speichern(liste)


def anlegen(titel: str, bereich: str, schwere: str, beleg: str = "", quelle: str = "von Hand") -> str:
    with _sperre:
        return _anlegen(titel, bereich, schwere, beleg, quelle)


def _anlegen(titel: str, bereich: str, schwere: str, beleg: str, quelle: str) -> str:
    liste = laden()
    neu = {
        "id": hashlib.sha1(titel.encode()).hexdigest()[:8],
        "titel": titel, "bereich": bereich, "schwere": schwere,
        "quelle": quelle, "status": "offen", "beleg": beleg,
        "vorschlag": None, "notiz": "",
    }
    if any(b["id"] == neu["id"] for b in liste):
        return neu["id"]
    liste.append(neu)
    speichern(liste)
    return neu["id"]


def sortiert(status: str = None) -> list:
    liste = laden()
    if status:
        liste = [b for b in liste if b["status"] == status]
    return sorted(liste, key=lambda b: (SCHWERE_RANG.get(b["schwere"], 3), b["titel"]))


def zaehlung() -> dict:
    liste = laden()
    return {s: sum(1 for b in liste if b["status"] == s) for s in STATUS}
