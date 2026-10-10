"""Die Befundliste. Eine JSON-Datei, kein Dienst: sie muss einen Neustart
überstehen und von Hand lesbar bleiben."""
import json
import hashlib
from pathlib import Path

PFAD = Path(__file__).parent / "daten" / "befunde.json"

STATUS = ["offen", "in Arbeit", "Vorschlag da", "übernommen", "verworfen"]
SCHWERE_RANG = {"high": 0, "medium": 1, "low": 2}


def laden() -> list:
    if not PFAD.exists():
        return []
    return json.loads(PFAD.read_text())


def speichern(liste: list) -> None:
    PFAD.parent.mkdir(exist_ok=True)
    PFAD.write_text(json.dumps(liste, ensure_ascii=False, indent=2))


def holen(befund_id: str) -> dict | None:
    return next((b for b in laden() if b["id"] == befund_id), None)


def aendern(befund_id: str, **felder) -> None:
    liste = laden()
    for b in liste:
        if b["id"] == befund_id:
            b.update(felder)
    speichern(liste)


def anlegen(titel: str, bereich: str, schwere: str, beleg: str = "", quelle: str = "von Hand") -> str:
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
