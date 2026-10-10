"""Kostenbremse. Ein Arbeiter, der im Kreis liest, soll Geld kosten dürfen —
aber nicht unbemerkt und nicht unbegrenzt."""
import json
import os
import tempfile
import threading
from pathlib import Path

_sperre = threading.RLock()

PFAD = Path(__file__).parent / "daten" / "guthaben.json"

# Opus 5, USD pro Million Token. Es gibt bewusst nur ein Modell: ein
# zweites, billigeres hätte stillschweigend schlechtere Urteile geliefert.
PREIS_EIN = 5.00
PREIS_AUS = 25.00

# Opus kostet rund das Doppelte von Sonnet pro Token und denkt länger nach,
# also steigen beide Grenzen mit. Ein Lauf kostete auf Sonnet 20–45 Cent.
GRENZE_PRO_LAUF = 1.50   # USD, ein Arbeiter
GRENZE_PRO_TAG = 15.00   # USD, alle zusammen


def _laden() -> dict:
    if not PFAD.exists():
        return {"tage": {}}
    try:
        return json.loads(PFAD.read_text())
    except (json.JSONDecodeError, OSError):
        return {"tage": {}}


def buchen(tag: str, usd: float) -> None:
    """Zwei Arbeiter dürfen nicht die Buchung des jeweils anderen verlieren."""
    PFAD.parent.mkdir(exist_ok=True)
    with _sperre:
        d = _laden()
        d["tage"][tag] = round(d["tage"].get(tag, 0.0) + usd, 4)
        fd, vorlaeufig = tempfile.mkstemp(dir=PFAD.parent, prefix=".guthaben-", suffix=".json")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(d, f, ensure_ascii=False, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(vorlaeufig, PFAD)
        except BaseException:
            Path(vorlaeufig).unlink(missing_ok=True)
            raise


def heute(tag: str) -> float:
    return _laden()["tage"].get(tag, 0.0)


def kosten(ein: int, aus: int) -> float:
    return (ein / 1_000_000) * PREIS_EIN + (aus / 1_000_000) * PREIS_AUS


def erlaubt(tag: str) -> tuple[bool, str]:
    verbraucht = heute(tag)
    if verbraucht >= GRENZE_PRO_TAG:
        return False, f"Tagesgrenze erreicht: ${verbraucht:.2f} von ${GRENZE_PRO_TAG:.2f}"
    return True, f"${verbraucht:.2f} von ${GRENZE_PRO_TAG:.2f} heute"
