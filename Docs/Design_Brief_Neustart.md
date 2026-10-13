# Design-Briefing: Melora – Neugestaltung von Grund auf

> Dieses Briefing beschreibt, **was** die App kann und für wen sie ist – nicht, wie sie heute aussieht.
> Navigation, Screen-Aufteilung, Farben, Schrift und Look sind bewusst offen. Erfinde sie neu.
> Stand: Code auf Branch `Dev3`, Oktober 2026.

---

## 1. Auftrag

Gestalte eine iOS-App (iPhone) komplett neu: Informationsarchitektur, Navigation, Screens, visuelle Identität.
Halte dich an die Funktionen, Regeln und Grenzen unten – das ist, was das Backend heute liefert.
Wenn du eine Funktion für überflüssig hältst oder eine fehlt, sag es explizit und begründe es, statt sie still wegzulassen oder zu erfinden.

Die Oberflächensprache der App ist **Englisch**.

---

## 2. Die Idee in einem Satz

Du hörst Musik auf Spotify, tippst „Go live“, und Leute in deiner Nähe sehen, welchen Song du gerade hörst – sie können reinhören, ihn liken, dir dazu schreiben oder dir folgen. **Ein Song ist der Türöffner zu einer Person.**

---

## 3. Für wen (Arbeitshypothese, nicht getestet)

Primäre Zielgruppe laut den internen Testplänen: **Teenager und junge Erwachsene, ab 13 Jahren**.

Typische Person: 16, iPhone SE oder ein altes iPhone 11/12, Dark Mode an, oft Stromsparmodus, wackliges mobiles Netz (Bus, Schulkeller), **Spotify Free** (kein Premium). Nutzt TikTok und Instagram, erwartet, dass alles sofort lädt und gut aussieht. Liest keine Erklärtexte, tippt sich durch. Hat ca. 20 Sekunden Geduld.

Sie löscht die App, wenn etwas:
- langsam oder hängend wirkt,
- hinter einer Paywall steckt („geht nur mit Premium“ als Sackgasse),
- **creepy** wirkt – z. B. genauer Standort sichtbar, oder eine Nachricht an Fremde rutscht aus Versehen raus,
- nach Erwachsenen, Firma oder Einstellungsseite klingt („broadcast“, „radius“, „enable“, „permission“).

Barrierefreiheit muss mitgedacht werden: kleines Display (iPhone SE), größere Schrift, „Bewegung reduzieren“.

> Achtung: Diese Persona stammt aus Testplänen. Echte Testergebnisse gibt es noch keine.

---

## 4. Was Nutzer erledigen wollen (Jobs)

1. **Sehen, was Leute um mich herum gerade hören** – und ob überhaupt jemand da ist.
2. **Einen Song, der mir gefällt, sofort anhören** – ohne die App zu verlassen.
3. **Auf einen Song reagieren** – leise (Like) oder direkt (Nachricht).
4. **Selbst sichtbar werden**, indem ich teile, was ich höre („live gehen“) – und jederzeit wieder unsichtbar werden.
5. **Mitbekommen, wer auf mich reagiert hat** (Likes, neue Follower, Nachrichten).
6. **Mit Leuten chatten**, die über Musik auf mich zugekommen sind.
7. **Menschen folgen**, deren Musik ich mag, und erfahren, wann sie live sind – egal wo.
8. **Mich zeigen**: Fotos, Basisinfos, mein Musikgeschmack.
9. **Mich schützen**: verstecken, blockieren, melden, Daten löschen.

---

## 5. Funktionsumfang (muss abgedeckt sein)

### 5.1 Konto
- Kein Registrierungsformular: Jede Installation bekommt automatisch ein anonymes Konto.
- Optional **„Sign in with Apple“**, damit das Profil eine Neuinstallation oder ein neues Handy überlebt. Angeboten am Ende des Onboardings, in den Einstellungen und auf dem Startbildschirm („Profil schon vorhanden?“).
- **Abmelden** gibt es nur für Apple-verknüpfte Konten.
- **Profil und alle Daten löschen** für alle, mit doppelter Bestätigung. Löscht wirklich alles (Profil, Fotos, Follows, Likes, Chats).

### 5.2 Erster Start
Pflicht für ein fertiges Profil:
- Vorname, Nachname, Stadt (je mind. 2 Zeichen)
- Geburtstag – **später nicht änderbar**, öffentlich wird nur das Alter gezeigt
- Geschlecht: Female / Male / Non-binary / Other
- 2–5 Fotos, das erste ist das Profilbild

Optional:
- „Looking for“: New Music / Friends / Open to all
- Spotify verbinden (ohne Spotify kann man stöbern und chatten, aber **nicht live gehen**)
- Sign in with Apple

Danach braucht es eine kurze Erklärung, was die App ist (heute ein 3-seitiges Intro, in den Einstellungen wiederholbar). Systemabfragen für **Standort** und **Mitteilungen** dürfen nicht direkt hintereinander kommen und nicht, bevor der Nutzer verstanden hat, wofür.

### 5.3 Live gehen (eigene Musik teilen)
- Voraussetzung: Spotify verbunden **und** es läuft gerade wirklich ein Song. Pausiert zählt als „nichts läuft“.
- Beim ersten Mal: Standortfreigabe (nur „beim Benutzen“).
- Geteilt werden: aktueller Song (Titel, Artist, Album, Cover, Spotify-Link) und ein **ungenauer Standort** (auf ca. 275 m gerundet).
- Live gehen muss **mit einem Tipp** aus dem Hauptbereich möglich sein. Beenden muss **immer** möglich sein.
- Läuft ca. 10 Minuten nichts, endet die Live-Session automatisch, mit Mitteilung.
- Läuft die App im Hintergrund länger als 5 Minuten, gilt man nicht mehr als live – außer bei der Option unten.
- **Option „Live bleiben, wenn die App zu ist“** (Opt-in, einmalige Einwilligung, in den Einstellungen änderbar): Der Server prüft weiter, was läuft. Maximal 2 Stunden. Der Standort bleibt dabei auf dem Startpunkt stehen.
- Nach dem Beenden wird der Standort gelöscht. Man taucht noch 24 h als „Recently live“ auf, ohne Distanz.
- Gesammelte **Live-Zeit** (in Minuten) wird als Statistik am Profil gezeigt.
- Fehlerfälle, die erklärt werden müssen: Spotify nicht verbunden, Spotify-Login abgelaufen, nichts läuft, kein aktives Gerät, Standort aus (man ist live, aber niemand in der Nähe findet einen).

### 5.4 Eigener Player
Kontrolle über das eigene Spotify: Play/Pause, vor, zurück, spulen, Shuffle, Repeat (aus / Playlist / Song). Zeigt den aktuellen Song mit Cover und Fortschritt.
Ob es dafür einen eigenen Bereich braucht oder das woanders hingehört, ist deine Entscheidung.

### 5.5 Entdecken: Wer ist gerade live?
- **Zwei Blickwinkel:** „In der Nähe“ und „Leute, denen ich folge“ (Letzteres ohne Distanzfilter, weltweit).
- **Live jetzt:** innerhalb eines Radius, nächste zuerst. Radius 1–500 km, Standard 25 km, wird gemerkt.
- **Recently live:** wer in den letzten 24 h live war, ohne Distanz, max. 20 Einträge – damit es nie komplett leer ist.
- **Distanz nur in Bändern**, nie genau: „under 500 m“, „under 1 km“, „about 3.5 km“, „about 12 km“.
- **Pro Person/Song sichtbar:** Profilfoto, Vorname (+ Nachname, siehe Fallstricke), Alter, Stadt, Songtitel, Artist, Cover, Live-Status oder „Live vor 3 h“, Distanzband.
- **Aktionen pro Eintrag:** 30-Sekunden-Vorschau anhören, Like, Nachricht, Folgen, „Nicht interessiert“.
- **Leere Zustände** (alle nötig):
  - Niemand im Radius, aber weiter weg → sagen, wie weit, und mit einem Tipp den Radius passend vergrößern.
  - Niemand live → zum eigenen Live-Gehen einladen.
  - Folgt noch niemandem → Personensuche anbieten.
  - Standort aus → erklären, Link zu den iOS-Einstellungen, trotzdem alle Live-Personen zeigen.
  - Standort wird noch gesucht.
- Personensuche (nach Vor- oder Nachname, ab 2 Zeichen) ist von hier erreichbar.

### 5.6 Song-Detail
Öffnet sich aus einem Entdecken-Eintrag. Zeigt Song und Person (Live/zuletzt aktiv, Distanzband, Stadt; Tippen öffnet das Profil).
Aktionen:
- **30-Sekunden-Vorschau** in der App (kommt aus iTunes/Deezer, nicht von Spotify; kann bis 8 s laden, kann fehlen → „Kein Preview, in Spotify öffnen“).
- **Auf Spotify abspielen** – nur mit Premium direkt; mit Free öffnet sich die Spotify-App (oder der Browser). Das darf sich **nicht** wie eine Sackgasse anfühlen.
- **In Spotify-Warteschlange** (Premium) und **in Spotify speichern** (Liked Songs).
- **Like**.
- **Nachricht zum Song** direkt hier schreiben.
- **Teilen** über das iOS-Teilen-Menü (iMessage, WhatsApp, Instagram …).
- **Diesen Song verstecken**.

### 5.7 Die drei sozialen Verben – jedes hat genau eine Bedeutung
| Verb | Bedeutung | Was der Empfänger sieht |
|---|---|---|
| **Like** | Reaktion auf einen Song, den jemand gerade live spielt. Nur ein Signal, nichts zu bestätigen. Pro Person und Song einmal, kein Unlike. | Eintrag „X liked [Song]“ mit Möglichkeit, direkt „Hi“ zu sagen (öffnet einen Chat). |
| **Follow** | Einseitig, ohne Bestätigung. Ich sehe, wann die Person live geht, egal wo, und bekomme eine Mitteilung. | Eintrag „X folgt dir“ mit „Zurückfolgen“. |
| **Message** | Erste Nachricht an jemanden ist eine **Nachrichtenanfrage**. Der Absender kann genau **eine** Nachricht schicken, bis die andere Seite annimmt. | Anfrage annehmen oder ablehnen. Eine Ablehnung wird dem Absender **nie** angezeigt. |

Ein Like mit Text (max. 160 Zeichen) wird zur Nachrichtenanfrage.
Wurde man einmal abgelehnt, kann man der Person nicht erneut schreiben oder sie liken; man sieht neutral „You've already reached out to X“.

### 5.8 Chat
- Ein Chat pro Personenpaar.
- Textnachrichten, **Antworten auf eine Nachricht** (Zitat), **Reaktionen** mit 6 festen Emojis (❤️ 😂 😮 😢 🙏 🔥, eine pro Person und Nachricht).
- **„Song senden, den ich gerade höre“** als Karte (Tippen öffnet Spotify). Geht nur, wenn gerade etwas läuft.
- **„Gesehen“** unter der eigenen letzten Nachricht.
- Kopfzeile zeigt, ob die Person gerade live ist oder wann sie zuletzt aktiv war; Tippen öffnet ihr Profil.
- Nachrichten können nicht bearbeitet oder einzeln gelöscht werden.
- Chat löschen (für beide), Person blockieren.

### 5.9 Benachrichtigungen / Aktivität
In der App braucht es einen Ort für:
- Chats (mit Ungelesen-Status),
- Nachrichtenanfragen (eingehend, mit Anzahl) und eigene, noch unbeantwortete Anfragen,
- Aktivität: Likes und neue Follower in einer Zeitleiste, neu vs. früher.

Push-Mitteilungen gibt es für: neuer Like, neue Nachricht/Anfrage, Anfrage angenommen, neuer Follower. Jede einzeln abschaltbar. Ein Tipp auf eine Mitteilung führt an die passende Stelle (Chat, Aktivität, Profil, Entdecken).
Zusätzlich, nur solange die App läuft: „X ist live“ für Leute in einem einstellbaren Umkreis (100 m – 50 km, Standard 5 km) und für Leute, denen man folgt.

### 5.10 Profil
**Fremdes Profil** zeigt:
- 2–5 Fotos, Name, Alter, Stadt, Geschlecht, „Looking for“
- live ja/nein und welcher Song gerade läuft
- Statistiken: Live-Zeit, Likes erhalten, Follower (Follower-Liste antippbar)
- Link zum Spotify-Profil
- **Musikgeschmack:** Top 6 Artists, Top 5 Tracks, bis zu 8 öffentliche Playlists (jeweils in Spotify öffnen). Kann vom Besitzer abgeschaltet werden.
- Aktionen: Folgen, Nachricht, Melden, Blockieren

Jedes Profilbild und jeder Name in der ganzen App soll zum Profil der Person führen.

**Eigenes Profil:**
- Vorschau „So sehen dich andere“ – muss wirklich identisch mit der Fremdansicht sein.
- Bearbeiten: Vorname, Nachname, Stadt, Geschlecht, „Looking for“, Fotos (2–5, Reihenfolge, ersetzen, entfernen). Geburtstag nur lesbar, mit Hinweis, dass er fix ist.
- Änderungen verwerfen muss möglich sein; ein fehlgeschlagenes Speichern darf nichts verlieren.

### 5.11 Sicherheit
- **Nicht interessiert** (aus Entdecken): Song verstecken, Person verstecken, Person blockieren. Verstecken hat 5 s „Rückgängig“ und gilt nur auf dem eigenen Gerät.
- **Blockieren** (aus Entdecken, Profil, Chat): Person verschwindet überall, der gemeinsame Chat wird für beide gelöscht.
- **Liste „Blockiert & versteckt“** in den Einstellungen mit „Wieder anzeigen“ / „Entsperren“.
- **Melden** (aus dem Profil): Gründe Spam/Scam, unangemessene Fotos, Belästigung/Hass, Fake-Profil, wirkt minderjährig, Sonstiges; optional Details (max. 500 Zeichen).

### 5.12 Einstellungen
Mitteilungen (pro Typ, plus Umkreis für „X ist live“), Hinweis falls iOS-Mitteilungen aus sind; Spotify verbinden/trennen/neu verbinden; Musikgeschmack am Profil an/aus und jetzt aktualisieren; „Live bleiben, wenn die App zu ist“; Blockiert & versteckt; Konto (Apple verknüpfen, abmelden, alles löschen); „Wie Melora funktioniert“; Datenschutz, AGB, Version.

---

## 6. Datenschutz – nicht verhandelbar

- **Nie einen genauen Standort zeigen** oder andeuten. Keine Karte mit Personen. Nur Distanzbänder.
- Standort wird nur geteilt, solange man live ist, und danach gelöscht.
- Nie aus Versehen eine Nachricht an Fremde senden (kein Senden durch einen einzelnen Fehltipp).
- Ablehnungen sind für den Absender unsichtbar.
- Geburtstag ist nie sichtbar, nur das Alter.
- Nutzer ab 13 Jahren – das Design darf nicht wie eine Dating-App für Erwachsene wirken.

---

## 7. Technische Rahmen

- iPhone, iOS 18+, SwiftUI. Dark Mode muss funktionieren; ob es auch einen Light Mode gibt, entscheidest du.
- **Einziger Musikdienst ist Spotify.** Kein Apple Music.
- Viele Nutzer haben **Spotify Free**: Abspielen, Warteschlange und Fernsteuerung in der App gehen nur mit Premium. Free-Nutzer müssen trotzdem einen guten Weg haben (Vorschau in der App, Öffnen in Spotify).
- Die Live-Erkennung prüft Spotify alle 15 s – „live“ kann also bis zu ~15 s hinterherhinken.
- Netzwerk ist oft schlecht: Jede Aktion braucht einen klaren Lade- und Fehlerzustand, und wenn man eine Ansicht wegwischt, während etwas lädt, darf nichts hängen bleiben.

---

## 8. Bekannte Fallstricke (aus einer Experten-Review, nicht aus Nutzertests)

Diese Probleme gab es in früheren Versionen. Dein Design sollte sie von vornherein vermeiden:

1. **Leere Startseite.** Ein neuer Nutzer in einer neuen Stadt sieht niemanden und geht. → Es muss immer etwas zu sehen oder zu tun geben.
2. **Unklar, warum man nicht live gehen kann.** Ein ausgegrauter Schalter ohne Grund frustriert.
3. **Live endet still.** Nutzer merken nicht, dass ihre Session automatisch beendet wurde.
4. **Wo landet was?** Likes, Follower, Anfragen und Chats lagen an verschiedenen Orten; niemand wusste, wo eine Reaktion auftaucht.
5. **Uneinheitliche Begriffe** (z. B. „broadcast“ vs. „go live“, „ignore“ vs. „decline“). → Ein Vokabular für alles.
6. **Profile nur von einem Ort aus erreichbar.** → Jede Person überall antippbar.
7. **Musik kam am Profil kaum vor**, obwohl Musik der Kern der App ist.
8. **Technische Fehlermeldungen** im UI. → Alle Fehler in menschlicher Sprache, mit nächstem Schritt.
9. **Verstecken und Blockieren waren Einbahnstraßen** ohne Übersicht.
10. **Nachname öffentlich.** Für Teenager evtl. unpassend; offen, ob es den braucht. Ein Vorschlag von dir ist willkommen.
11. **Systemabfragen zu früh**, bevor man die App überhaupt gesehen hat.
12. **Zu viel Bewegung**: ein pulsierender Live-Indikator wirkte wie ein Alarm statt wie ein Herzschlag.

---

## 9. Bewusst offen – das entscheidest du

- Navigation und Anzahl/Aufteilung der Hauptbereiche
- Ob Player, Live-Schalter und Entdecken getrennt oder zusammen sind
- Wie Entdecken dargestellt wird (Liste, Karten, Stapel, etwas anderes)
- Visuelle Identität: Farben, Schrift, Logo, Icons, Bewegung
- Ton der Texte (nur: nicht belehrend, nicht nach Firma klingend)

---

## 10. Was ich von dir zurück möchte

1. **Kurzes Konzept** (max. eine Seite): Navigation, Hauptbereiche, und warum.
2. **Diese Abläufe als Screens:**
   - Erster Start bis zum ersten Blick auf Entdecken
   - Entdecken → Song anhören → Like oder Nachricht
   - Live gehen und wieder beenden (inkl. „geht gerade nicht, weil …“)
   - Eingang: Like, neuer Follower, Nachrichtenanfrage annehmen, Chat
   - Fremdes Profil, eigenes Profil bearbeiten
   - Blockieren/Melden
3. **Leere und Fehlerzustände** für Entdecken und Live gehen.
4. **Ein kleines Design-System**: Farben, Schrift, Abstände, Kernkomponenten.
5. **Liste deiner Abweichungen** von diesem Briefing, mit Begründung.
