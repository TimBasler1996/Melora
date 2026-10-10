"""Melora-Dashboard: Befunde, Arbeiter, Tests, TestFlight.

Aufruf:  dashboard melora
"""
import html
import json
import subprocess
from datetime import date
from pathlib import Path

import streamlit as st

import arbeiter
import befunde
import guthaben
import jobs
import protokoll
import werkzeuge

REPO = Path(__file__).resolve().parent.parent

st.set_page_config(page_title="Melora", layout="wide", page_icon="🔥")

# Meloras eigene Farben. Das Dashboard soll aussehen wie die App, über die
# es berichtet — nicht wie ein fremdes Werkzeug.
st.markdown("""
<style>
  .stApp { background: #0E0C0B; }
  section.main > div { padding-top: 1.2rem; }
  h1, h2, h3, p, span, label, li, div { color: #F4EFE6; }
  .marke { display:inline-block; font-size:11px; letter-spacing:.08em;
           text-transform:uppercase; padding:3px 8px; border:1px solid currentColor;
           border-radius:2px; margin-right:6px; }
  .m-high { color:#E5484D; } .m-medium { color:#E3A008; } .m-low { color:#6E6A78; }
  .m-offen { color:#FF5A3C; } .m-arbeit { color:#E3A008; }
  .m-vorschlag { color:#4FA97E; } .m-übernommen { color:#4FA97E; }
  .m-verworfen { color:#6E6A78; }
  .kachel { background:#171412; border:1px solid rgba(244,239,230,.10);
            padding:14px 16px; }
  .kachel b { font-size:26px; font-family:ui-monospace,monospace; display:block; }
  .kachel span { font-size:12px; color:rgba(244,239,230,.40); }
  .titel { font-size:15px; font-weight:600; line-height:1.4; }
  .beleg { font-family:ui-monospace,monospace; font-size:11px;
           color:rgba(244,239,230,.40); }
  div[data-testid="stExpander"] { border-color: rgba(244,239,230,.10); }
  .stButton button { border-radius:2px; }
</style>
""", unsafe_allow_html=True)


def marke(text: str, klasse: str) -> str:
    return f'<span class="marke m-{klasse}">{html.escape(str(text))}</span>'


def kachel(wert, label, spalte):
    spalte.markdown(f'<div class="kachel"><b>{wert}</b><span>{label}</span></div>',
                    unsafe_allow_html=True)


# ── Kopf ────────────────────────────────────────────────────────────
st.markdown("## Melora")
z = befunde.zaehlung()
tag = date.today().isoformat()
_, guthaben_text = guthaben.erlaubt(tag)

s = st.columns(5)
kachel(z.get("offen", 0), "offene Befunde", s[0])
kachel(z.get("in Arbeit", 0) or "—", "Arbeiter laufen", s[1])
kachel(z.get("Vorschlag da", 0) or "—", "Vorschläge warten", s[2])
kachel(z.get("übernommen", 0), "übernommen", s[3])
kachel(guthaben_text.split(" von ")[0], "Kosten heute", s[4])

reiter = st.tabs(["Befunde", "Tests", "TestFlight", "Protokoll"])

# ── Befunde ─────────────────────────────────────────────────────────
with reiter[0]:
    links, rechts = st.columns([3, 1])
    with rechts:
        filter_status = st.selectbox("Status", ["alle"] + befunde.STATUS, index=1)
        if st.button("Neu laden", use_container_width=True):
            st.rerun()
        with st.expander("Befund von Hand erfassen"):
            t = st.text_area("Titel", height=80, key="neu_titel")
            b1, b2 = st.columns(2)
            bereich = b1.text_input("Bereich", value="discover", key="neu_bereich")
            schwere = b2.selectbox("Schwere", ["high", "medium", "low"], index=1, key="neu_schwere")
            beleg = st.text_input("Beleg (Datei:Zeile)", key="neu_beleg")
            if st.button("Anlegen", use_container_width=True) and t.strip():
                befunde.anlegen(t.strip(), bereich, schwere, beleg)
                st.rerun()

    with links:
        liste = befunde.sortiert(None if filter_status == "alle" else filter_status)
        if not liste:
            st.info("Hier ist nichts offen. Ungewohnt, aber möglich.")

        for b in liste:
            laeuft = jobs.aktiv(b["id"])
            status = "in Arbeit" if laeuft else b["status"]
            kopf = (marke(b["schwere"], b["schwere"])
                    + marke(status, status.replace(" ", "").lower()
                            .replace("inarbeit", "arbeit").replace("vorschlagda", "vorschlag"))
                    + marke(b["bereich"], "low"))
            st.markdown(kopf, unsafe_allow_html=True)
            st.markdown(f'<div class="titel">{html.escape(b["titel"])}</div>',
                        unsafe_allow_html=True)
            if b.get("beleg"):
                st.markdown(f'<div class="beleg">{html.escape(b["beleg"][:240])}</div>',
                            unsafe_allow_html=True)
            if b.get("notiz"):
                st.caption(b["notiz"])

            knoepfe = st.columns([1, 1, 1, 3])
            if b["status"] in ("offen", "verworfen") and not laeuft:
                if knoepfe[0].button("Arbeiter ansetzen", key=f"go{b['id']}"):
                    jobs.starten(b["id"], b["titel"], lambda i=b["id"]: arbeiter.ansetzen(i))
                    st.rerun()
            if laeuft:
                knoepfe[0].markdown("⏳ liest den Code …")
            if b["status"] != "verworfen" and knoepfe[1].button("Verwerfen", key=f"nix{b['id']}"):
                befunde.aendern(b["id"], status="verworfen")
                st.rerun()
            if b["status"] == "verworfen" and knoepfe[1].button("Zurückholen", key=f"back{b['id']}"):
                befunde.aendern(b["id"], status="offen")
                st.rerun()

            v = b.get("vorschlag")
            if v:
                with st.expander(f"Vorschlag · {v.get('urteil','—')} · "
                                 f"${v.get('kosten',0):.3f} · {v.get('runden','?')} Runden"):
                    st.markdown(v["text"].split("PATCH:")[0])
                    if v.get("patch"):
                        sauber, meldung = arbeiter.patch_pruefen(v["patch"])
                        st.code(v["patch"], language="diff")
                        st.caption(("✓ " if sauber else "✗ ") + meldung)
                        if sauber:
                            if st.button("Übernehmen", key=f"ok{b['id']}", type="primary"):
                                erfolg, meldung = arbeiter.patch_anwenden(v["patch"])
                                if erfolg:
                                    befunde.aendern(b["id"], status="übernommen", notiz=meldung)
                                    protokoll.log("übernommen", b["titel"][:90], befund=b["id"])
                                else:
                                    st.error(meldung)
                                st.rerun()
                    else:
                        st.caption("Kein Patch — der Arbeiter hat nichts zu ändern gefunden.")
            st.divider()

# ── Tests ───────────────────────────────────────────────────────────
with reiter[1]:
    st.markdown("#### Unit-Tests")
    st.caption("`./test.sh` — reine Logik, kein Firebase, kein App-Start.")
    if st.button("Tests laufen lassen", type="primary"):
        with st.spinner("läuft …"):
            ok, ausgabe = werkzeuge.tests_laufen()
        protokoll.log("tests", "grün" if ok else "rot")
        (st.success if ok else st.error)(ausgabe or ("Alles grün." if ok else "Fehlgeschlagen."))
    letzte = [p for p in protokoll.letzte(12, "tests")]
    if letzte:
        st.caption("Zuletzt: " + ", ".join(f"{p['zeit'][5:16]} {p['text']}" for p in reversed(letzte)))

# ── TestFlight ──────────────────────────────────────────────────────
with reiter[2]:
    st.markdown("#### Builds")
    if st.button("Status abfragen"):
        with st.spinner("App Store Connect …"):
            try:
                r = subprocess.run(["python3", str(Path(__file__).parent / "testflight.py")],
                                   capture_output=True, text=True, timeout=120)
                st.code(r.stdout or r.stderr)
            except Exception as e:
                st.error(f"Ging nicht: {e}")
    st.caption("Braucht authkeys/AuthKey_63WW8ZZB26.p8 und pyjwt im venv.")

# ── Protokoll ───────────────────────────────────────────────────────
with reiter[3]:
    for p in reversed(protokoll.letzte(80)):
        st.markdown(
            f'<span class="beleg">{p["zeit"][5:16]}</span> '
            + marke(p["art"], "low") + html.escape(p["text"])[:160],
            unsafe_allow_html=True)
