"""Was ein Arbeiter am Repository tun darf.

Lesen, suchen — und Änderungen *vorschlagen*. Kein Werkzeug schreibt in die
Arbeitskopie; Vorschläge sammeln sich in einer Sitzung und werden erst
angewendet, wenn ein Mensch im Dashboard zustimmt.

Die Vorschläge kommen als Textersetzung, nicht als Diff. Ein Modell, das
Hunk-Köpfe selbst ausrechnet, verzählt sich — der erste Arbeiter lieferte
einen Patch, dessen Kopf neun Zeilen auswies für einen Rumpf von zehn.
`difflib` kann das fehlerfrei, das Modell muss es gar nicht erst versuchen.
"""
import difflib
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
        "name": "aenderung_vorschlagen",
        "description": (
            "Schlägt eine Textersetzung vor. `alt` muss im aktuellen Stand der Datei "
            "GENAU EINMAL vorkommen — nimm genug Kontextzeilen dazu, damit das stimmt. "
            "Mehrere Aufrufe sind erlaubt und bauen aufeinander auf. Zeilennummern "
            "gehören nicht in `alt` oder `neu`: die Einrückung dagegen schon, wörtlich."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pfad": {"type": "string"},
                "alt": {"type": "string", "description": "Der zu ersetzende Text, wörtlich."},
                "neu": {"type": "string", "description": "Der neue Text. Leer lassen, um zu löschen."},
            },
            "required": ["pfad", "alt", "neu"],
            "additionalProperties": False,
        },
        "strict": True,
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


class Sitzung:
    """Die vorgeschlagenen Dateistände eines Arbeiterlaufs."""

    def __init__(self) -> None:
        self.stand: dict[str, str] = {}      # Pfad -> vorgeschlagener Inhalt
        self.original: dict[str, str] = {}   # Pfad -> Inhalt beim ersten Anfassen

    def inhalt(self, pfad: str) -> str:
        if pfad not in self.stand:
            text = _sicher(pfad).read_text(errors="replace")
            self.original[pfad] = text
            self.stand[pfad] = text
        return self.stand[pfad]

    def ersetzen(self, pfad: str, alt: str, neu: str) -> str:
        text = self.inhalt(pfad)
        treffer = text.count(alt)
        if treffer == 0:
            return ("`alt` kommt in dieser Datei nicht vor. Lies die Stelle erneut und "
                    "übernimm sie wörtlich, mitsamt Einrückung.")
        if treffer > 1:
            return (f"`alt` kommt {treffer}-mal vor und ist damit nicht eindeutig. "
                    "Nimm mehr Kontext dazu.")
        self.stand[pfad] = text.replace(alt, neu, 1)
        return f"Übernommen in den Vorschlag für {pfad}."

    def patch(self) -> str:
        """Ein unified diff, von difflib erzeugt — nicht vom Modell gezählt."""
        teile = []
        for pfad, neu in self.stand.items():
            alt = self.original[pfad]
            if alt == neu:
                continue
            teile.extend(difflib.unified_diff(
                alt.splitlines(keepends=True), neu.splitlines(keepends=True),
                fromfile=f"a/{pfad}", tofile=f"b/{pfad}", n=3,
            ))
        return "".join(teile)


def ausfuehren(name: str, eingabe: dict, sitzung: "Sitzung | None" = None) -> str:
    try:
        if name == "aenderung_vorschlagen":
            if sitzung is None:
                return "In diesem Lauf sind keine Änderungen möglich."
            _sicher(eingabe["pfad"])
            return sitzung.ersetzen(eingabe["pfad"], eingabe["alt"], eingabe["neu"])

        if name == "datei_lesen":
            ziel = _sicher(eingabe["pfad"])
            if not ziel.exists():
                return f"Nicht gefunden: {eingabe['pfad']}"
            # Den vorgeschlagenen Stand zeigen, nicht den alten — sonst liest
            # der Arbeiter seine eigene vorherige Änderung nicht.
            if sitzung and eingabe["pfad"] in sitzung.stand:
                zeilen = sitzung.stand[eingabe["pfad"]].splitlines()
            else:
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
