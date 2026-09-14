// Removes everything the agents created. Dry run by default; --confirm deletes.
//
//   node agentPurge.js             counts per collection
//   node agentPurge.js --confirm   deletes documents, storage files and auth users
//   node agentPurge.js --confirm --keep-config   keeps config/agents
//
// Two passes per agent uid:
//  1. everything tagged agentId == uid (top-level collections and the
//     collection groups likesReceived / likesGiven / messages; the latter
//     need the agentId collection-group index from firestore.indexes.json),
//  2. references to the uid that live in real users' documents, exactly the
//     set the account-deletion function removes (likes given to the agent,
//     likes the agent gave, follows, blocks, conversations).

const config = require("./config");
const personas = require("./lib/personas");
const { db, auth, bucket } = require("./lib/firebase");

const CONFIRM = process.argv.includes("--confirm");
const KEEP_CONFIG = process.argv.includes("--keep-config");

const TOP_LEVEL = ["users", "broadcasts", "conversations", "follows", "blocks", "reports", "agentState"];
const GROUPS = ["likesReceived", "likesGiven", "messages"];

const counts = {};
function count(key, n) { counts[key] = (counts[key] ?? 0) + n; }

async function deleteDocs(refs) {
  if (!CONFIRM || !refs.length) return;
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db().batch();
    refs.slice(i, i + 400).forEach((r) => batch.delete(r));
    await batch.commit();
  }
}

async function taggedIn(query, label) {
  try {
    const snap = await query.get();
    count(label, snap.size);
    return snap.docs.map((d) => d.ref);
  } catch (err) {
    if (String(err.message).includes("index")) {
      console.warn(`  ${label}: collection-group index for agentId missing (deploy firestore.indexes.json); relying on the reference pass`);
      return [];
    }
    throw err;
  }
}

async function purgeAgent(uid) {
  // Pass 1: tagged documents.
  for (const col of TOP_LEVEL) {
    const refs = await taggedIn(db().collection(col).where("agentId", "==", uid), `${col} (agentId)`);
    if (col === "conversations") {
      for (const r of refs) { count("messages (in agent conversations)", (await r.collection("messages").get()).size); if (CONFIRM) await db().recursiveDelete(r); }
    } else {
      await deleteDocs(refs);
    }
  }
  for (const group of GROUPS) {
    await deleteDocs(await taggedIn(db().collectionGroup(group).where("agentId", "==", uid), `${group} (agentId)`));
  }

  // Pass 2: references in other people's documents.
  const q = async (query, label) => { const s = await query.get(); count(label, s.size); return s.docs.map((d) => d.ref); };
  await deleteDocs(await q(db().collectionGroup("likesReceived").where("fromUserId", "==", uid), "likesReceived (from agent)"));
  await deleteDocs(await q(db().collectionGroup("likesGiven").where("toUserId", "==", uid), "likesGiven (to agent)"));
  await deleteDocs(await q(db().collection("follows").where("followerId", "==", uid), "follows (by agent)"));
  await deleteDocs(await q(db().collection("follows").where("followingId", "==", uid), "follows (of agent)"));
  await deleteDocs(await q(db().collection("blocks").where("blockerId", "==", uid), "blocks (by agent)"));
  await deleteDocs(await q(db().collection("blocks").where("blockedUserId", "==", uid), "blocks (of agent)"));
  const convos = await db().collection("conversations").where("participantIds", "array-contains", uid).get();
  count("conversations (participant)", convos.size);
  if (CONFIRM) for (const d of convos.docs) await db().recursiveDelete(d.ref);

  const broadcast = await db().collection("broadcasts").doc(uid).get();
  if (broadcast.exists) { count("broadcasts (by uid)", 1); if (CONFIRM) await broadcast.ref.delete(); }
  const user = await db().collection("users").doc(uid).get();
  if (user.exists) {
    count("users (by uid)", 1);
    count("users/*/likes* (own subcollections)", (await user.ref.collection("likesReceived").get()).size + (await user.ref.collection("likesGiven").get()).size);
    if (CONFIRM) await db().recursiveDelete(user.ref);
  }
  const state = await db().collection("agentState").doc(uid).get();
  if (state.exists) { count("agentState (by uid)", 1); if (CONFIRM) await state.ref.delete(); }

  // Storage: the agent's folder, checked by metadata as well.
  const [files] = await bucket().getFiles({ prefix: `userPhotos/${uid}/` });
  count("storage files", files.length);
  if (CONFIRM) for (const f of files) await f.delete().catch(() => undefined);

  // Auth.
  try {
    await auth().getUser(uid);
    count("auth users", 1);
    if (CONFIRM) await auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
  }
}

async function discoverUids() {
  const uids = new Set(personas.load().map((p) => p.uid));
  const flagged = await db().collection("users").where("isAgent", "==", true).get();
  flagged.docs.forEach((d) => uids.add(d.id));
  const states = await db().collection("agentState").get();
  states.docs.forEach((d) => uids.add(d.id));
  return [...uids];
}

async function main() {
  const uids = await discoverUids();
  console.log(`${CONFIRM ? "PURGING" : "Dry run:"} ${uids.length} agent uid(s) in ${config.projectId}`);
  for (const uid of uids) {
    console.log(`- ${uid}`);
    await purgeAgent(uid);
  }
  if (!KEEP_CONFIG) {
    const cfg = await db().doc(config.killSwitchPath).get();
    if (cfg.exists) { count("config/agents", 1); if (CONFIRM) await cfg.ref.delete(); }
  }
  // Anything tagged with an agentId that is not in the uid list (e.g. "system").
  for (const col of TOP_LEVEL) {
    // orderBy on a field returns only documents that have it.
    const stray = await db().collection(col).orderBy("agentId").get().catch(() => ({ docs: [] }));
    const refs = stray.docs.filter((d) => !uids.includes(d.data().agentId) && d.data().agentId !== "system").map((d) => d.ref);
    if (refs.length) { count(`${col} (stray agentId)`, refs.length); await deleteDocs(refs); }
  }

  console.log("\nCounts:");
  for (const [k, v] of Object.entries(counts).sort()) console.log(`  ${k.padEnd(44)} ${v}`);
  if (!CONFIRM) console.log("\nNothing deleted. Re-run with --confirm to delete.");
  else console.log("\nDone.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
