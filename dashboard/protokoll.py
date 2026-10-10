"""Ein Logbuch, das überlebt. Streamlit baut die Seite bei jedem Klick neu
auf, also darf nichts Wichtiges nur im Speicher stehen."""
import json
from datetime import datetime
from pathlib import Path

PFAD = Path(__file__).parent / "daten" / "protokoll.jsonl"


def log(art: str, text: str, **felder) -> None:
    PFAD.parent.mkdir(exist_ok=True)
    eintrag = {"zeit": datetime.now().isoformat(timespec="seconds"), "art": art, "text": text}
    eintrag.update(felder)
    with PFAD.open("a") as f:
        f.write(json.dumps(eintrag, ensure_ascii=False) + "\n")


def letzte(n: int = 60, art: str = None) -> list:
    if not PFAD.exists():
        return []
    zeilen = [json.loads(z) for z in PFAD.read_text().splitlines() if z.strip()]
    if art:
        zeilen = [z for z in zeilen if z.get("art") == art]
    return zeilen[-n:]
