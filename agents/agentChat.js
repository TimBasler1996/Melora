// Replies for agents in accepted chats. Listens to conversations that
// involve an agent; when a non-agent sends a message, the agent answers
// after a human-ish delay using the Claude API with its persona prompt.
//
//   ANTHROPIC_API_KEY=… node agentChat.js
//
// Stops immediately when config/agents.enabled becomes false.

const Anthropic = require("@anthropic-ai/sdk");
const config = require("./config");
const personas = require("./lib/personas");
const time = require("./lib/time");
const { make } = require("./lib/random");
const { db, FieldValue, agentsEnabled, tagged } = require("./lib/firebase");

const rng = make();
const MIN = 60 * 1000;
const anthropic = new Anthropic();

const byUid = new Map(personas.load().map((p) => [p.uid, p]));
const agentUids = [...byUid.keys()];

// conversationId → { timer, dueAt }
const scheduled = new Map();
// Rate limiting.
const repliesPerConversation = new Map(); // `${convoId}|${dateKey}` → n
let repliesThisHour = { hour: -1, n: 0 };

function log(msg) { console.log(`${new Date().toISOString().slice(11, 19)} ${msg}`); }

// ─── Scheduling ───────────────────────────────────────────────────────

function replyDelayMs() {
  const clock = time.local();
  if (time.inWindow(clock.hour, config.chat.nightHours)) {
    // Sleep until a random moment in the morning window.
    const [from, to] = config.chat.morningWindow;
    const hour = rng.between(from, to);
    const localNowMinutes = clock.hour * 60 + clock.minute;
    let deltaMinutes = hour * 60 - localNowMinutes;
    if (deltaMinutes <= 0) deltaMinutes += 24 * 60;
    return deltaMinutes * MIN;
  }
  return rng.between(...config.chat.replyDelayMinutes) * MIN;
}

function schedule(convoId, agentUid, lastAt) {
  const existing = scheduled.get(convoId);
  // Only a newer message moves the reply; read markers and heartbeats don't.
  if (existing && existing.lastAt >= lastAt) return;
  const delay = replyDelayMs();
  if (existing) clearTimeout(existing.timer);
  const timer = setTimeout(() => {
    scheduled.delete(convoId);
    reply(convoId, agentUid).catch((err) => log(`reply ${convoId} failed: ${err.message}`));
  }, delay);
  scheduled.set(convoId, { timer, dueAt: Date.now() + delay, lastAt });
  log(`${byUid.get(agentUid).handle}: reply to ${convoId} in ${Math.round(delay / MIN)} min`);
}

function rateLimited(convoId) {
  const clock = time.local();
  if (repliesThisHour.hour !== clock.hour) repliesThisHour = { hour: clock.hour, n: 0 };
  if (repliesThisHour.n >= config.chat.maxRepliesPerHourTotal) return true;
  const key = `${convoId}|${clock.dateKey}`;
  return (repliesPerConversation.get(key) ?? 0) >= config.chat.maxRepliesPerConversationPerDay;
}

function countReply(convoId) {
  repliesThisHour.n += 1;
  const today = time.local().dateKey;
  const key = `${convoId}|${today}`;
  repliesPerConversation.set(key, (repliesPerConversation.get(key) ?? 0) + 1);
  for (const k of repliesPerConversation.keys()) if (!k.endsWith(`|${today}`)) repliesPerConversation.delete(k);
}

// ─── Prompt ───────────────────────────────────────────────────────────

const RULES = {
  "de-CH": `Regeln:
- Du schreibst in einer Musik-App mit jemandem, der in deiner Nähe Musik gehört hat. Kurze, beiläufige Nachrichten wie im Chat, ein bis zwei Sätze, keine Listen, kein Assistenten-Ton.
- Bleib bei Musik und Alltag. Frag ab und zu zurück.
- Keine Verabredungen zu echten Treffen, keine Adressen, keine Telefonnummern, keine Links, keine anderen Apps.
- Bei unangemessenen oder sexuellen Nachrichten: knapp abbrechen ("Sorry, das ist nichts für mich.") und nicht darauf eingehen.
- Du bist eine Person, kein Assistent. Erkläre nie, dass du eine KI bist, und biete keine Hilfe an.
- Antworte nur mit dem Nachrichtentext.`,
  "fr-CH": `Règles :
- Tu écris dans une appli de musique avec quelqu'un qui écoutait de la musique près de toi. Messages courts et décontractés comme dans un chat, une ou deux phrases, pas de listes, pas de ton d'assistant.
- Reste sur la musique et le quotidien. Pose parfois une question en retour.
- Pas de rendez-vous réels, pas d'adresses, pas de numéros de téléphone, pas de liens, pas d'autres applis.
- Si le message est déplacé ou sexuel : coupe court ("Désolé, c'est pas pour moi.") sans entrer dans le sujet.
- Tu es une personne, pas un assistant. Ne dis jamais que tu es une IA et ne propose pas d'aide.
- Réponds uniquement avec le texte du message.`,
};

function systemPrompt(p, currentTrack) {
  const rules = RULES[p.language] ?? RULES["de-CH"];
  const listening = currentTrack
    ? (p.language === "fr-CH"
      ? `En ce moment tu écoutes « ${currentTrack.title} » de ${currentTrack.artist}.`
      : `Gerade hörst du „${currentTrack.title}“ von ${currentTrack.artist}.`)
    : "";
  return `${p.personaPrompt}\n${listening}\n\n${rules}`;
}

// ─── Reply ────────────────────────────────────────────────────────────

async function reply(convoId, agentUid) {
  if (!(await agentsEnabled())) { log("kill switch off, not replying"); return; }
  if (rateLimited(convoId)) { log(`rate limited: ${convoId}`); return; }

  const p = byUid.get(agentUid);
  const convoRef = db().collection("conversations").doc(convoId);
  const convo = await convoRef.get();
  if (!convo.exists) return;
  const c = convo.data();
  if ((c.status ?? "accepted") !== "accepted") return;
  if (c.lastMessageSenderId === agentUid) return; // already answered

  const snap = await convoRef.collection("messages").orderBy("createdAt", "desc").limit(config.chat.contextMessages).get();
  const history = snap.docs.map((d) => d.data()).reverse();

  // Alternate roles; merge consecutive turns; the first turn must be the user.
  const messages = [];
  for (const m of history) {
    const role = m.senderId === agentUid ? "assistant" : "user";
    const text = String(m.text ?? "").trim();
    if (!text) continue;
    if (!messages.length && role === "assistant") continue;
    const last = messages[messages.length - 1];
    if (last && last.role === role) last.content += "\n" + text;
    else messages.push({ role, content: text });
  }
  if (!messages.length || messages[messages.length - 1].role !== "user") return;

  const me = await db().collection("users").doc(agentUid).get();
  const currentTrack = me.exists ? me.data().currentTrack : null;

  let response;
  try {
    response = await anthropic.messages.create({
      model: config.chat.model,
      max_tokens: config.chat.maxTokens,
      system: systemPrompt(p, currentTrack),
      messages,
    });
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) {
      log("Anthropic rate limit; retry in 5 min");
      setTimeout(() => schedule(convoId, agentUid, Date.now()), 5 * MIN);
      return;
    }
    if (err instanceof Anthropic.AuthenticationError) { console.error("ANTHROPIC_API_KEY invalid"); process.exit(1); }
    throw err;
  }
  if (response.stop_reason === "refusal") { log(`${p.handle}: model refused, no reply`); return; }
  const text = response.content
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("")
    .trim()
    .replace(/^["„«]|["“»]$/g, "");
  if (!text) return;

  const batch = db().batch();
  batch.set(
    convoRef.collection("messages").doc(),
    tagged(agentUid, { senderId: agentUid, text, type: "text", createdAt: FieldValue.serverTimestamp() })
  );
  batch.set(
    convoRef,
    tagged(agentUid, {
      lastMessageText: text,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageSenderId: agentUid,
      updatedAt: FieldValue.serverTimestamp(),
      lastReadAt: { [agentUid]: FieldValue.serverTimestamp() },
    }),
    { merge: true }
  );
  await batch.commit();
  countReply(convoId);
  log(`${p.handle} → ${convoId}: ${text}`);
}

// ─── Listener ─────────────────────────────────────────────────────────

function agentIn(participantIds) {
  const agents = participantIds.filter((id) => byUid.has(id));
  // Two agents talking to each other would loop forever: never reply there.
  return agents.length === 1 ? agents[0] : null;
}

function handle(doc, startedAt) {
  const c = doc.data();
  const agentUid = agentIn(c.participantIds ?? []);
  if (!agentUid) return;
  if ((c.status ?? "accepted") !== "accepted") return;
  if (!c.lastMessageSenderId || c.lastMessageSenderId === agentUid) return;
  const at = c.lastMessageAt?.toMillis?.() ?? 0;
  // Backlog from before this process started: only the last day counts.
  if (at < startedAt - 24 * 60 * MIN) return;
  const readAt = c.lastReadAt?.[agentUid]?.toMillis?.() ?? 0;
  if (at <= readAt) return;
  schedule(doc.id, agentUid, at);
}

function main() {
  const startedAt = Date.now();
  log(`agentChat: ${agentUids.length} agents, model ${config.chat.model}`);

  // array-contains-any takes at most 30 values per query.
  for (let i = 0; i < agentUids.length; i += 30) {
    const chunk = agentUids.slice(i, i + 30);
    db().collection("conversations")
      .where("participantIds", "array-contains-any", chunk)
      .onSnapshot(
        (snap) => snap.docChanges().forEach((ch) => { if (ch.type !== "removed") handle(ch.doc, startedAt); }),
        (err) => { console.error("listener failed", err); process.exit(1); }
      );
  }

  db().doc(config.killSwitchPath).onSnapshot((snap) => {
    if (!snap.exists || snap.data().enabled !== true) {
      log(`${config.killSwitchPath}.enabled is false: exiting.`);
      process.exit(0);
    }
  });
}

main();
