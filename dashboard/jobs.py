"""Ein Arbeiter pro Befund, im Hintergrundthread. Bewusst klein gehalten:
Streamlit-Reruns dürfen keinen laufenden Job abbrechen."""
import threading
import traceback
from datetime import datetime

import protokoll

_laufend: dict = {}
_sperre = threading.Lock()


def starten(befund_id: str, titel: str, funktion) -> bool:
    """Startet einen Arbeiter, wenn für diesen Befund keiner läuft."""
    with _sperre:
        if befund_id in _laufend and _laufend[befund_id]["aktiv"]:
            return False
        _laufend[befund_id] = {"aktiv": True, "titel": titel,
                               "start": datetime.now().isoformat(timespec="seconds"),
                               "fehler": None}

    def huelle():
        try:
            funktion()
        except Exception as e:
            protokoll.log("fehler", f"Arbeiter für {titel}: {e}",
                          befund=befund_id, spur=traceback.format_exc()[-1500:])
            with _sperre:
                _laufend[befund_id]["fehler"] = str(e)
        finally:
            with _sperre:
                _laufend[befund_id]["aktiv"] = False

    threading.Thread(target=huelle, daemon=True).start()
    return True


def aktiv(befund_id: str = None) -> bool:
    with _sperre:
        if befund_id:
            return _laufend.get(befund_id, {}).get("aktiv", False)
        return any(j["aktiv"] for j in _laufend.values())


def liste() -> dict:
    with _sperre:
        return dict(_laufend)
