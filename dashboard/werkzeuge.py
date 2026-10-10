"""Was ein Arbeiter am Repository tun darf.

Bewusst lesend. Der einzige Weg, wie eine Änderung in den Code kommt, ist
ein Patch, den der Mensch im Dashboard freigibt — kein Werkzeug schreibt
in die Arbeitskopie.
"""
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

WERKZEUGE = [
    {
        "name": "datei_lesen",
        "description": "Liest eine Datei aus dem Repository. Pfad relativ zur Projektwurzel.",
        "input_schema": {
            "type": "object",
            "properties": {
                "pfad": {"type": "string"},
                "von": {"type": "integer", "description": "Erste Zeile (1-basiert), optional"},
                "bis": {"type": "integer", "description": "Letzte Zeile, optional"},
            },
            "required": ["pfad"],
        },
    },
    {
        "name": "suchen",
        "description": "Sucht einen regulären Ausdruck im Swift- und TypeScript-Code. Gibt Treffer mit Pfad und Zeilennummer zurück.",
        "input_schema": {
            "type": "object",
            "properties": {
                "muster": {"type": "string"},
                "pfad": {"type": "string", "description": "Unterordner, optional"},
            },
            "required": ["muster"],
        },
    },
    {
        "name": "dateien_auflisten",
        "description": "Listet Swift-Dateien unter einem Pfad.",
        "input_schema": {
            "type": "object",
            "properties": {"pfad": {"type": "string"}},
            "required": ["pfad"],
        },
    },
]

AUSGESCHLOSSEN = (".git", "node_modules", "daten", ".venv", "authkeys", "serviceAccount.json")


def _sicher(pfad: str) -> Path:
    ziel = (REPO / pfad).resolve()
    if not str(ziel).startswith(str(REPO)):
        raise ValueError("Pfad liegt ausserhalb des Projekts")
    if any(teil in str(ziel) for teil in AUSGESCHLOSSEN):
        raise ValueError("Dieser Pfad ist für Arbeiter gesperrt")
    return ziel


def ausfuehren(name: str, eingabe: dict) -> str:
    try:
        if name == "datei_lesen":
            ziel = _sicher(eingabe["pfad"])
            if not ziel.exists():
                return f"Nicht gefunden: {eingabe['pfad']}"
            zeilen = ziel.read_text(errors="replace").splitlines()
            von = max(1, eingabe.get("von", 1))
            bis = min(len(zeilen), eingabe.get("bis", len(zeilen)))
            if bis - von > 600:
                bis = von + 600
            return "\n".join(f"{i}\t{zeilen[i-1]}" for i in range(von, bis + 1))

        if name == "suchen":
            unter = _sicher(eingabe.get("pfad", "."))
            r = subprocess.run(
                ["grep", "-rnE", "--include=*.swift", "--include=*.ts",
                 eingabe["muster"], str(unter)],
                capture_output=True, text=True, timeout=30,
            )
            treffer = [z.replace(str(REPO) + "/", "") for z in r.stdout.splitlines()
                       if not any(a in z for a in AUSGESCHLOSSEN)]
            if not treffer:
                return "Keine Treffer."
            return "\n".join(treffer[:120])

        if name == "dateien_auflisten":
            unter = _sicher(eingabe["pfad"])
            dateien = sorted(p.relative_to(REPO) for p in unter.rglob("*.swift")
                             if not any(a in str(p) for a in AUSGESCHLOSSEN))
            return "\n".join(str(d) for d in dateien[:200]) or "Keine Swift-Dateien."

        return f"Unbekanntes Werkzeug: {name}"
    except Exception as e:
        return f"Fehler: {e}"


def tests_laufen() -> tuple[bool, str]:
    """Führt ./test.sh aus. Der eine Weg, auf dem das Dashboard eine
    Behauptung über den Zustand des Codes prüfen kann."""
    try:
        r = subprocess.run(["./test.sh", "-q"], cwd=REPO, capture_output=True,
                           text=True, timeout=900)
        return r.returncode == 0, (r.stdout + r.stderr).strip()[-2000:]
    except subprocess.TimeoutExpired:
        return False, "Zeitüberschreitung nach 15 Minuten."
    except Exception as e:
        return False, f"Konnte die Tests nicht starten: {e}"
