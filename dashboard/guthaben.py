"""Kostenbremse. Ein Arbeiter, der im Kreis liest, soll Geld kosten dürfen —
aber nicht unbemerkt und nicht unbegrenzt."""
import json
import os
import tempfile
import threading
from pathlib import Path

_sperre = threading.RLock()

PFAD = Path(__file__).parent / "daten" / "guthaben.json"

# Haiku 4.5, USD pro Million Token (Stand Oktober 2026).
PREIS_EIN = 1.00
PREIS_AUS = 5.00
# Sonnet-Klasse für die Arbeiter.
PREIS_EIN_GROSS = 3.00
PREIS_AUS_GROSS = 15.00

GRENZE_PRO_LAUF = 0.60   # USD, ein Arbeiter
GRENZE_PRO_TAG = 8.00    # USD, alle zusammen


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


def kosten(ein: int, aus: int, gross: bool = True) -> float:
    pe, pa = (PREIS_EIN_GROSS, PREIS_AUS_GROSS) if gross else (PREIS_EIN, PREIS_AUS)
    return (ein / 1_000_000) * pe + (aus / 1_000_000) * pa


def erlaubt(tag: str) -> tuple[bool, str]:
    verbraucht = heute(tag)
    if verbraucht >= GRENZE_PRO_TAG:
        return False, f"Tagesgrenze erreicht: ${verbraucht:.2f} von ${GRENZE_PRO_TAG:.2f}"
    return True, f"${verbraucht:.2f} von ${GRENZE_PRO_TAG:.2f} heute"
