// Main loop: every tick each agent decides whether to start, continue or end
// a listening session, moves between its anchors, refreshes its broadcast,
// likes what it sees and reacts to likes and message requests it received.
//
//   node agentTick.js              runs forever (Ctrl-C to stop)
//   node agentTick.js --once       one tick, then exit
//   node agentTick.js --debug      session/like probabilities × config.debugBoost
//   node agentTick.js --agent lena_k   only this persona
//
// Runtime state lives in agentState/{uid} (tagged with agentId) so a restart
// continues where it stopped and the purge removes it.

const config = require("./config");
const personas = require("./lib/personas");
const pool = require("./lib/pool");
const geo = require("./lib/geo");
const time = require("./lib/time");
const { make } = require("./lib/random");
const { opener } = require("./lib/openers");
const { db, FieldValue, Timestamp, agentsEnabled, tagged, sleep } = require("./lib/firebase");

const args = process.argv.slice(2);
const ONCE = args.includes("--once");
const DEBUG = args.includes("--debug");
const ONLY = args.includes("--agent") ? args[args.indexOf("--agent") + 1] : null;
if (args.includes("--agent") && (!ONLY || ONLY.startsWith("--"))) {
  console.error("--agent needs a persona handle, e.g. --agent lena_k");
  process.exit(1);
}
const BOOST = DEBUG ? config.debugBoost : 1;

const rng = make();
const MIN = 60 * 1000;

// Agent profiles (display name, photo) cached for like payloads.
const profiles = new Map();
let profilesLoadedAt = 0;

function log(handle, msg) {
  console.log(`${new Date().toISOString().slice(11, 19)} ${handle.padEnd(10)} ${msg}`);
}

// ─── State ────────────────────────────────────────────────────────────

function defaultState() {
  return {
    dateKey: null,
    restDay: false,
    sessionsTarget: 0,
    sessionsDone: 0,
    likesToday: 0,
    requestsToday: 0,
    lastSessionEndAt: 0,
    travel: null,
    session: null,
    likedKeys: {},
    decisions: {},
    ignored: {},
  };
}

async function loadState(p) {
  const snap = await db().collection("agentState").doc(p.uid).get();
  return snap.exists ? { ...defaultState(), ...snap.data() } : defaultState();
}

async function saveState(p, state) {
  await db().collection("agentState").doc(p.uid).set(
    tagged(p.uid, { ...state, updatedAt: FieldValue.serverTimestamp() })
  );
}

async function loadProfiles(list) {
  if (Date.now() - profilesLoadedAt < 30 * MIN) return;
  const refs = list.map((p) => db().collection("users").doc(p.uid));
  const snaps = await db().getAll(...refs);
  for (const snap of snaps) {
    if (!snap.exists) continue;
    const d = snap.data();
    profiles.set(snap.id, {
      displayName: d.displayName,
      avatarURL: d.photoURLs?.[0] ?? d.heroPhotoURL ?? null,
    });
  }
  profilesLoadedAt = Date.now();
}

// ─── Day plan ─────────────────────────────────────────────────────────

function planDay(p, state, today) {
  const type = config.userTypes[p.userType];
  state.dateKey = today;
  state.sessionsDone = 0;
  state.likesToday = 0;
  state.requestsToday = 0;
  state.restDay = rng.chance(type.restDayProbability);
  state.sessionsTarget = state.restDay ? 0 : rng.int(...type.sessionsPerDay);

  if (state.travel && state.travel.untilDateKey < today) state.travel = null;
  if (!state.travel && rng.chance(config.travel.dailyProbability)) {
    const other = rng.pick(Object.keys(config.cities).filter((c) => c !== p.city));
    const until = new Date();
    until.setDate(until.getDate() + rng.int(...config.travel.days) - 1);
    state.travel = {
      city: other,
      untilDateKey: time.local(until).dateKey,
      anchors: travelAnchors(p, other, today),
    };
  }
  log(p.handle, `new day: ${state.restDay ? "rest day" : `${state.sessionsTarget} session(s) planned`}${state.travel ? `, travelling to ${state.travel.city}` : ""}`);
}

/** Temporary anchors in another city, deterministic per agent and day. */
function travelAnchors(p, cityKey, dateKey) {
  const r = make(`travel:${p.handle}:${dateKey}`);
  const city = config.cities[cityKey];
  const centre = { lat: city.lat, lng: city.lng };
  const spot = () => geo.round(geo.jitter(centre, config.anchorRadiusM.min, config.anchorRadiusM.max, r));
  return [
    { type: "home", ...spot(), hours: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 22, 23] },
    { type: "cafe", ...spot(), hours: [10, 11, 12, 13, 14, 15, 16] },
    { type: "bar", ...spot(), hours: [17, 18, 19, 20, 21] },
  ];
}

function anchorsFor(p, state) {
  return state.travel?.anchors ?? p.anchors;
}

function currentAnchor(p, state, clock) {
  const anchors = anchorsFor(p, state);
  const eligible = anchors.filter(
    (a) => a.hours.includes(clock.hour) && !(a.weekdaysOnly && clock.isWeekend)
  );
  return eligible.length ? rng.pick(eligible) : anchors.find((a) => a.type === "home") ?? anchors[0];
}

function placeLabel(p, state) {
  return config.cities[state.travel?.city ?? p.city].label;
}

// ─── Sessions ─────────────────────────────────────────────────────────

function startSession(p, state, clock) {
  const cluster = pool.pickCluster(p.genreWeights, rng);
  const tracks = pool.sessionTracks(cluster, rng.int(...config.session.tracks), rng);
  if (tracks.length < 2) throw new Error(`cluster ${cluster} has too few tracks`);

  const now = Date.now();
  const durations = tracks.map(() => rng.between(...config.session.trackMinutes) * MIN);
  const total = durations.reduce((a, b) => a + b, 0);

  const anchor = currentAnchor(p, state, clock);
  const origin = geo.jitter(anchor, config.sessionOffsetM.min, config.sessionOffsetM.max, rng);
  let mode = "anchor";
  let dest = null;
  const others = anchorsFor(p, state).filter((a) => a !== anchor);
  if (others.length && rng.chance(config.session.transitProbability)) {
    mode = "transit";
    dest = geo.jitter(rng.pick(others), config.sessionOffsetM.min, config.sessionOffsetM.max, rng);
  }

  state.session = {
    startedAt: now,
    endsAt: now + total,
    cluster,
    tracks,
    durations,
    trackIndex: 0,
    trackEndsAt: now + durations[0],
    mode,
    origin: geo.round(origin),
    dest: dest ? geo.round(dest) : null,
    anchorType: anchor.type,
    midLikeChecked: false,
  };
  log(p.handle, `session start: ${tracks.length} ${cluster} tracks, ${Math.round(total / MIN)} min, ${mode} from ${anchor.type}`);
}

function sessionPosition(session) {
  if (session.mode !== "transit") return session.origin;
  const t = Math.min(1, Math.max(0, (Date.now() - session.startedAt) / (session.endsAt - session.startedAt)));
  return geo.round(geo.lerp(session.origin, session.dest, t));
}

function trackPayload(t) {
  return {
    id: t.trackId,
    title: t.name,
    artist: t.artist,
    album: t.album ?? null,
    artworkURL: t.albumArtUrl ?? null,
    durationMs: t.durationMs ?? null,
  };
}

async function writeLive(p, state, isNew) {
  const s = state.session;
  const track = s.tracks[s.trackIndex];
  const pos = sessionPosition(s);
  const now = FieldValue.serverTimestamp();

  const broadcast = {
    userId: p.uid,
    trackId: track.trackId,
    trackTitle: track.name,
    trackArtist: track.artist,
    trackAlbum: track.album ?? null,
    trackArtworkURL: track.albumArtUrl ?? null,
    spotifyTrackURL: `https://open.spotify.com/track/${track.trackId}`,
    latitude: pos.lat,
    longitude: pos.lng,
    isLive: true,
    endedAt: FieldValue.delete(),
    updatedAt: now,
  };
  if (isNew) broadcast.broadcastedAt = now;

  const batch = db().batch();
  batch.set(db().collection("broadcasts").doc(p.uid), tagged(p.uid, broadcast), { merge: true });
  batch.set(
    db().collection("users").doc(p.uid),
    tagged(p.uid, {
      isBroadcasting: true,
      currentTrack: trackPayload(track),
      lastLocation: { latitude: pos.lat, longitude: pos.lng },
      lastActiveAt: now,
      updatedAt: now,
    }),
    { merge: true }
  );
  await batch.commit();
}

async function endSession(p, state) {
  const s = state.session;
  const minutes = Math.max(1, Math.round((Math.min(Date.now(), s.endsAt) - s.startedAt) / MIN));
  const now = FieldValue.serverTimestamp();
  const batch = db().batch();
  batch.set(
    db().collection("broadcasts").doc(p.uid),
    tagged(p.uid, {
      userId: p.uid,
      isLive: false,
      latitude: FieldValue.delete(),
      longitude: FieldValue.delete(),
      endedAt: now,
      updatedAt: now,
    }),
    { merge: true }
  );
  batch.set(
    db().collection("users").doc(p.uid),
    tagged(p.uid, {
      isBroadcasting: false,
      currentTrack: FieldValue.delete(),
      lastLocation: FieldValue.delete(),
      broadcastMinutesTotal: FieldValue.increment(minutes),
      lastActiveAt: now,
      updatedAt: now,
    }),
    { merge: true }
  );
  await batch.commit();
  state.session = null;
  state.lastSessionEndAt = Date.now();
  state.sessionsDone += 1;
  log(p.handle, `session end after ${minutes} min (${state.sessionsDone}/${state.sessionsTarget} today)`);
}

function sessionStartProbability(state, clock) {
  const remaining = state.sessionsTarget - state.sessionsDone;
  if (remaining <= 0) return 0;
  const curve = time.curveFor(clock.isWeekend);
  const mass = time.remainingCurveMass(clock.isWeekend, clock.hour, clock.minute);
  if (mass <= 0) return 0;
  // Spread the remaining sessions over the remaining curve mass of the day.
  return Math.min(1, (remaining * curve[clock.hour]) / mass) * BOOST;
}

// ─── Likes, follows, requests ─────────────────────────────────────────

/** Live broadcasts refreshed within the client's 5-minute window. */
async function fetchLiveBroadcasts() {
  const cutoff = Timestamp.fromMillis(Date.now() - 5 * MIN);
  const snap = await db()
    .collection("broadcasts")
    .where("isLive", "==", true)
    .where("updatedAt", ">", cutoff)
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function likeKey(toUid, trackId) { return `${toUid}|${trackId}`; }

async function maybeLike(p, state, live, agentUids) {
  if (state.likesToday >= config.likes.maxPerAgentPerDay) return;
  if (!rng.chance(config.likes.probabilityPerSession * BOOST)) return;

  const me = sessionPosition(state.session);
  const myClusters = new Set(Object.keys(p.genreWeights));
  const candidates = [];
  for (const b of live) {
    if (b.userId === p.uid) continue;
    if (typeof b.latitude !== "number" || typeof b.longitude !== "number") continue;
    if (geo.distanceM(me, { lat: b.latitude, lng: b.longitude }) > config.likes.radiusKm * 1000) continue;
    if (state.likedKeys[likeKey(b.userId, b.trackId)]) continue;
    const cluster = pool.clusterOf(b.trackId);
    const weight = cluster && myClusters.has(cluster) ? config.likes.genreMatchWeight : 1;
    candidates.push([b, weight]);
  }
  if (!candidates.length) return;
  const target = rng.weighted(candidates);
  await like(p, state, target, agentUids);
}

async function like(p, state, b, agentUids) {
  const toUid = b.userId;
  const received = db().collection("users").doc(toUid).collection("likesReceived");

  // Same three checks the client makes.
  const dup = await received.where("fromUserId", "==", p.uid).where("trackId", "==", b.trackId).limit(1).get();
  if (!dup.empty) { state.likedKeys[likeKey(toUid, b.trackId)] = Date.now(); return; }
  const declined = await received.where("fromUserId", "==", p.uid).where("status", "==", "rejected").limit(1).get();
  if (!declined.empty) return;
  const accepted = await received.where("fromUserId", "==", p.uid).where("status", "==", "accepted").limit(1).get();
  const status = accepted.empty ? "pending" : "accepted";

  const isRealUser = !agentUids.has(toUid);
  const withMessage =
    isRealUser &&
    state.requestsToday < config.likes.maxRequestsPerAgentPerDay &&
    rng.chance(config.likes.messageRealUserProbability);
  const message = withMessage
    ? opener(p.language, { title: b.trackTitle, artist: b.trackArtist, place: placeLabel(p, state) }, rng)
    : null;

  const profile = profiles.get(p.uid) ?? {};
  const pos = sessionPosition(state.session);
  const likeRef = received.doc();
  const payload = tagged(p.uid, {
    fromUserId: p.uid,
    toUserId: toUid,
    trackId: b.trackId,
    trackTitle: b.trackTitle,
    trackArtist: b.trackArtist,
    trackAlbum: b.trackAlbum ?? null,
    trackArtworkURL: b.trackArtworkURL ?? null,
    createdAt: Timestamp.now(),
    placeLabel: placeLabel(p, state),
    latitude: pos.lat,
    longitude: pos.lng,
    fromUserDisplayName: profile.displayName ?? p.displayName,
    fromUserAvatarURL: profile.avatarURL ?? null,
    sessionId: null,
    message,
    status,
  });

  const batch = db().batch();
  batch.set(likeRef, payload);
  batch.set(db().collection("users").doc(p.uid).collection("likesGiven").doc(likeRef.id), payload);
  await batch.commit();
  state.likesToday += 1;
  state.likedKeys[likeKey(toUid, b.trackId)] = Date.now();
  pruneLikedKeys(state);
  log(p.handle, `liked "${b.trackTitle}" by ${toUid}${message ? " + message request" : ""}`);

  if (message) {
    await sendRequest(p, state, toUid, likeRef.id, b.trackId, message, status);
  }
  if (rng.chance(config.likes.followProbability)) {
    await follow(p, toUid);
  }
}

function pruneLikedKeys(state) { pruneMap(state, "likedKeys"); }

/** Keeps the 300 most recent entries of a `{key: timestamp}` map. */
function pruneMap(state, field) {
  const entries = Object.entries(state[field]).sort((a, b) => b[1] - a[1]).slice(0, 300);
  state[field] = Object.fromEntries(entries);
}

function conversationId(a, b) {
  const x = a.toLowerCase();
  const y = b.toLowerCase();
  return x < y ? `${x}_${y}` : `${y}_${x}`;
}

/** Mirrors ChatApiService.deliverLikeMessage: request conversation + first message. */
async function sendRequest(p, state, toUid, likeId, trackId, text, likeStatus) {
  const ref = db().collection("conversations").doc(conversationId(p.uid, toUid));
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set(
      tagged(p.uid, {
        participantIds: [toUid, p.uid],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdFromLikeId: likeId,
        createdFromTrackId: trackId,
        status: likeStatus === "accepted" ? "accepted" : "pending",
        initiatorId: p.uid,
      }),
      { merge: true }
    );
  } else if (snap.data().status === "rejected") {
    return;
  }
  await appendMessage(p.uid, ref, text);
  state.requestsToday += 1;
}

async function appendMessage(uid, convoRef, text) {
  const batch = db().batch();
  batch.set(
    convoRef.collection("messages").doc(),
    tagged(uid, { senderId: uid, text, type: "text", createdAt: FieldValue.serverTimestamp() })
  );
  batch.set(
    convoRef,
    tagged(uid, {
      lastMessageText: text,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageSenderId: uid,
      updatedAt: FieldValue.serverTimestamp(),
      lastReadAt: { [uid]: FieldValue.serverTimestamp() },
    }),
    { merge: true }
  );
  await batch.commit();
}

async function follow(p, toUid) {
  const ref = db().collection("follows").doc(`${p.uid}_${toUid}`);
  if ((await ref.get()).exists) return;
  await ref.set(tagged(p.uid, { followerId: p.uid, followingId: toUid, createdAt: Timestamp.now() }));
  log(p.handle, `followed ${toUid}`);
}

// ─── Reacting to what the agent received ──────────────────────────────

function decide() {
  return rng.weighted([
    ["accept", config.respond.acceptProbability],
    ["decline", config.respond.declineProbability],
    ["ignore", Math.max(0, 1 - config.respond.acceptProbability - config.respond.declineProbability)],
  ]);
}

function scheduleDecision(state, key, kind, meta) {
  if (state.decisions[key] || state.ignored[key]) return;
  state.decisions[key] = {
    kind,
    action: decide(),
    decideAt: Date.now() + rng.between(...config.respond.delayMinutes) * MIN,
    ...meta,
  };
}

async function react(p, state, clock) {
  if (time.inWindow(clock.hour, config.respond.quietHours)) return;

  // Pending likes received (plain likes and like-with-message).
  const likes = await db().collection("users").doc(p.uid).collection("likesReceived")
    .where("status", "==", "pending").limit(20).get();
  for (const doc of likes.docs) {
    const d = doc.data();
    if (!d.fromUserId) continue;
    scheduleDecision(state, `like:${doc.id}`, "like", { likeId: doc.id, fromUserId: d.fromUserId });
  }

  // Pending message requests where the agent is the recipient.
  const convos = await db().collection("conversations").where("participantIds", "array-contains", p.uid).get();
  for (const doc of convos.docs) {
    const d = doc.data();
    if ((d.status ?? "accepted") !== "pending" || !d.initiatorId || d.initiatorId === p.uid) continue;
    scheduleDecision(state, `convo:${doc.id}`, "request", { conversationId: doc.id, likeId: d.createdFromLikeId ?? null, fromUserId: d.initiatorId });
  }

  const now = Date.now();
  for (const [key, dec] of Object.entries(state.decisions)) {
    if (dec.decideAt > now) continue;
    // A paired like/request decision may already have been settled below.
    if (!state.decisions[key]) continue;
    delete state.decisions[key];
    if (dec.action === "ignore") {
      // Final: the like or request stays pending forever, as when a person
      // never reacts. Remembered so the next tick doesn't roll again.
      state.ignored[key] = now;
      if (dec.kind === "request" && dec.likeId) state.ignored[`like:${dec.likeId}`] = now;
      if (dec.kind === "like") state.ignored[`convo:${conversationId(p.uid, dec.fromUserId)}`] = now;
      pruneMap(state, "ignored");
      log(p.handle, `ignored ${dec.kind} from ${dec.fromUserId}`);
      continue;
    }
    const status = dec.action === "accept" ? "accepted" : "rejected";
    if (dec.kind === "request") {
      await db().collection("conversations").doc(dec.conversationId).set(
        tagged(p.uid, { status, updatedAt: FieldValue.serverTimestamp() }), { merge: true }
      );
      if (dec.likeId) {
        await setLikeStatus(p, dec.likeId, dec.fromUserId, status);
        delete state.decisions[`like:${dec.likeId}`];
      }
    } else {
      await setLikeStatus(p, dec.likeId, dec.fromUserId, status);
      // A like that carries a message also has a pending conversation.
      const convoRef = db().collection("conversations").doc(conversationId(p.uid, dec.fromUserId));
      const convo = await convoRef.get();
      if (convo.exists && convo.data().status === "pending" && convo.data().initiatorId !== p.uid) {
        await convoRef.set(tagged(p.uid, { status, updatedAt: FieldValue.serverTimestamp() }), { merge: true });
        delete state.decisions[`convo:${convoRef.id}`];
      }
    }
    log(p.handle, `${dec.action}ed ${dec.kind} from ${dec.fromUserId}`);
  }
}

/** Mirrors LikeApiService.setLikeStatus: both docs, status + respondedAt. */
async function setLikeStatus(p, likeId, fromUserId, status) {
  const update = { status, respondedAt: FieldValue.serverTimestamp() };
  const refs = [db().collection("users").doc(p.uid).collection("likesReceived").doc(likeId)];
  if (fromUserId) refs.push(db().collection("users").doc(fromUserId).collection("likesGiven").doc(likeId));
  for (const ref of refs) {
    try {
      await ref.update(update);
    } catch (err) {
      // 5 = NOT_FOUND: the like was deleted meanwhile; never recreate a stub.
      if (err.code !== 5) throw err;
    }
  }
}

// ─── Tick ─────────────────────────────────────────────────────────────

async function tickAgent(p, state, clock, live, agentUids) {
  if (state.dateKey !== clock.dateKey) planDay(p, state, clock.dateKey);

  if (state.session) {
    const s = state.session;
    if (Date.now() >= s.endsAt) {
      await endSession(p, state);
    } else {
      if (Date.now() >= s.trackEndsAt && s.trackIndex < s.tracks.length - 1) {
        s.trackIndex += 1;
        s.trackEndsAt = Date.now() + s.durations[s.trackIndex];
        log(p.handle, `track ${s.trackIndex + 1}/${s.tracks.length}: ${s.tracks[s.trackIndex].name}`);
      }
      await writeLive(p, state, false);
      const progress = (Date.now() - s.startedAt) / (s.endsAt - s.startedAt);
      if (!s.midLikeChecked && progress >= 0.5) {
        s.midLikeChecked = true;
        await maybeLike(p, state, live, agentUids);
      }
    }
  } else {
    const gapOk = Date.now() - state.lastSessionEndAt >= config.session.minGapMinutes * MIN;
    if (!state.restDay && gapOk && rng.chance(sessionStartProbability(state, clock))) {
      startSession(p, state, clock);
      await writeLive(p, state, true);
      await maybeLike(p, state, live, agentUids);
    }
  }

}

async function tickAgentSafely(p, live, agentUids) {
  const clock = time.local();
  const state = await loadState(p);
  try {
    await tickAgent(p, state, clock, live, agentUids);
  } catch (err) {
    log(p.handle, `ERROR ${err.message}`);
  }
  try {
    await react(p, state, clock);
  } catch (err) {
    log(p.handle, `ERROR reacting: ${err.message}`);
  }
  // Whatever failed above, what did happen is persisted.
  await saveState(p, state);
}

async function endAllLive(list) {
  for (const p of list) {
    const state = await loadState(p);
    if (state.session) {
      await endSession(p, state);
      await saveState(p, state);
    }
  }
}

async function main() {
  pool.load();
  let list = personas.load();
  if (ONLY) list = list.filter((p) => p.handle === ONLY);
  if (!list.length) throw new Error(`no persona ${ONLY}`);
  const agentUids = new Set(personas.load().map((p) => p.uid));
  console.log(`agentTick: ${list.length} agents, tick ${config.tickMs / 1000}s${DEBUG ? `, debug ×${BOOST}` : ""}`);

  let stopping = false;
  process.on("SIGINT", () => {
    if (stopping) process.exit(130);
    stopping = true;
    console.log("\nstopping after this tick… (Ctrl-C again to quit now)");
  });

  while (!stopping) {
    const started = Date.now();
    if (!(await agentsEnabled())) {
      console.log(`${config.killSwitchPath}.enabled is false: ending live sessions and exiting.`);
      await endAllLive(list);
      return;
    }
    await loadProfiles(list);
    const live = await fetchLiveBroadcasts();
    for (const p of list) {
      await tickAgentSafely(p, live, agentUids);
    }
    if (ONCE) return;
    const wait = Math.max(0, config.tickMs - (Date.now() - started));
    await sleep(wait, () => stopping);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
