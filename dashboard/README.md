# Melora-Dashboard

    dashboard melora

Befunde, Arbeiter, Tests und TestFlight-Stand an einem Ort. Streamlit, im
selben Zuschnitt wie `dashboard spi`.

## Die Regel, auf der alles aufbaut

**Arbeiter schreiben nicht ins Repository.** Sie lesen den Code, prüfen den
Befund und schlagen einen Patch vor. Angewendet wird er erst, wenn ein
Mensch im Dashboard auf „Übernehmen" drückt — und auch dann nur in die
Arbeitskopie, nie in einen Commit. `werkzeuge.py` hat bewusst kein
Schreibwerkzeug; `authkeys/` und `serviceAccount.json` sind gesperrt.

Ein Arbeiter darf den Befund auch widerlegen. Prüfberichte irren, und ein
Arbeiter, der jeden Befund „repariert", ist schlimmer als keiner.

## Teile

| Datei | Wofür |
|---|---|
| `dashboard.py` | Oberfläche |
| `befunde.py` | Die Liste, als JSON in `daten/befunde.json` |
| `arbeiter.py` | Der Arbeiter: liest, urteilt, schlägt einen Diff vor |
| `werkzeuge.py` | Was er darf — lesen, suchen, auflisten, Tests starten |
| `jobs.py` | Ein Hintergrundthread pro Befund |
| `guthaben.py` | Kostenbremse: $0.60 pro Lauf, $8 pro Tag |
| `protokoll.py` | Logbuch in `daten/protokoll.jsonl` |
| `testflight.py` | Build- und Testerstand aus App Store Connect |

## Einrichtung

`.venv` und `daten/api_key` liegen nicht im Repository.

    cd dashboard
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    echo "sk-ant-…" > daten/api_key && chmod 600 daten/api_key

Der Schlüssel kommt von console.anthropic.com und wird separat abgerechnet —
nicht über dein Claude-Abo. Ein Arbeiterlauf kostet erfahrungsgemäß 15 bis
30 Cent.

## Wortwahl

„Agenten" heißt in diesem Projekt schon etwas: die virtuellen Testnutzer in
`agents/`. Die KI-Arbeiter hier heißen deshalb **Arbeiter**.
