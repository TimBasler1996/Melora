// Creates (or updates) the auth account, user document and photos for every
// persona, and the kill-switch document. Idempotent: re-run after editing
// personas.json.
//
//   node seedAgents.js            seeds everything
//   node seedAgents.js --no-photos   skip portrait download/upload

const crypto = require("crypto");
const config = require("./config");
const personas = require("./lib/personas");
const pool = require("./lib/pool");
const { db, auth, bucket, FieldValue, Timestamp, tagged } = require("./lib/firebase");
const { make } = require("./lib/random");

const NO_PHOTOS = process.argv.includes("--no-photos");

function birthdayFor(age, rng) {
  const now = new Date();
  const d = new Date(now.getFullYear() - age, rng.int(0, 11), rng.int(1, 28));
  if (d > new Date(now.getFullYear() - age, now.getMonth(), now.getDate())) d.setFullYear(d.getFullYear() - 1);
  return d;
}

async function ensureAuthUser(p) {
  try {
    await auth().getUser(p.uid);
    await auth().updateUser(p.uid, { displayName: p.displayName, disabled: true });
    return "kept";
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    await auth().createUser({ uid: p.uid, displayName: p.displayName, disabled: true });
    await auth().setCustomUserClaims(p.uid, { agent: true });
    return "created";
  }
}

async function uploadPortrait(p) {
  const src = `https://randomuser.me/api/portraits/${p.portrait}.jpg`;
  const res = await fetch(src);
  if (!res.ok) throw new Error(`portrait ${src}: ${res.status}`);
  const buffer = Buffer.from(await res.arrayBuffer());
  const urls = [];
  for (const name of ["photo_0.jpg", "hero_photo.jpg"]) {
    const path = `userPhotos/${p.uid}/${name}`;
    const token = crypto.randomUUID();
    await bucket().file(path).save(buffer, {
      contentType: "image/jpeg",
      metadata: {
        contentType: "image/jpeg",
        metadata: { agentId: p.uid, firebaseStorageDownloadTokens: token },
      },
    });
    urls.push(
      `https://firebasestorage.googleapis.com/v0/b/${config.storageBucket}/o/${encodeURIComponent(path)}?alt=media&token=${token}`
    );
  }
  return { photoURL: urls[0], heroPhotoURL: urls[1] };
}

/** Top artists / tracks from the pool so the profile shows a music taste. */
function tasteFor(p, rng) {
  if (!pool.exists()) return null;
  const { byCluster } = pool.load();
  const artists = new Map();
  const tracks = [];
  for (const [cluster, weight] of Object.entries(p.genreWeights)) {
    const list = rng.shuffle(byCluster[cluster] || []).slice(0, Math.max(2, Math.round(weight * 10)));
    for (const t of list) {
      if (tracks.length < 5) tracks.push({ id: t.trackId, name: t.name, subtitle: t.artist, imageURL: t.albumArtUrl, url: `https://open.spotify.com/track/${t.trackId}` });
      if (t.artistId && !artists.has(t.artistId) && artists.size < 6) {
        artists.set(t.artistId, { id: t.artistId, name: t.artist.split(", ")[0], imageURL: t.albumArtUrl, url: `https://open.spotify.com/artist/${t.artistId}` });
      }
    }
  }
  return { topArtists: [...artists.values()], topTracks: tracks, playlists: [], updatedAt: FieldValue.serverTimestamp() };
}

async function seedUser(p, photos) {
  const rng = make(`seed:${p.handle}`);
  const ref = db().collection("users").doc(p.uid);
  const existing = await ref.get();
  const data = {
    firstName: p.firstName,
    lastName: p.lastName,
    displayName: p.displayName,
    firstNameLower: p.firstName.toLowerCase(),
    lastNameLower: p.lastName.toLowerCase(),
    displayNameLower: p.displayName.toLowerCase(),
    birthday: Timestamp.fromDate(birthdayFor(p.age, rng)),
    gender: p.gender,
    city: p.cityLabel,
    countryCode: "CH",
    lookingFor: p.lookingFor,
    musicTaste: Object.keys(p.genreWeights).join(", "),
    profileCompleted: true,
    completedAt: existing.exists ? existing.data().completedAt ?? Timestamp.now() : Timestamp.now(),
    createdAt: existing.exists ? existing.data().createdAt ?? Timestamp.now() : Timestamp.now(),
    updatedAt: FieldValue.serverTimestamp(),
    lastActiveAt: FieldValue.serverTimestamp(),
    isBroadcasting: false,
    notifyLikes: false,
    notifyMessages: false,
    notifyFollowers: false,
    isAgent: true,
    agentHandle: p.handle,
    agentLanguage: p.language,
  };
  if (photos) {
    data.photoURLs = [photos.photoURL];
    data.heroPhotoURL = photos.heroPhotoURL;
  }
  const taste = tasteFor(p, rng);
  if (taste) data.spotifyTaste = taste;
  await ref.set(tagged(p.uid, data), { merge: true });
}

async function main() {
  const list = personas.load();
  console.log(`Seeding ${list.length} agents into ${config.projectId}`);
  if (!pool.exists()) console.log("(trackPool.json missing: profiles get no music taste yet; re-run after buildTrackPool.js)");

  for (const p of list) {
    const authResult = await ensureAuthUser(p);
    let photos = null;
    if (!NO_PHOTOS) {
      try {
        photos = await uploadPortrait(p);
      } catch (err) {
        console.warn(`  ${p.handle}: photo failed (${err.message}); continuing without`);
      }
    }
    await seedUser(p, photos);
    console.log(`  ${p.uid}: auth ${authResult}, user doc written${photos ? ", photos uploaded" : ""}`);
  }

  await db().doc(config.killSwitchPath).set(tagged("system", { enabled: true, updatedAt: FieldValue.serverTimestamp() }), { merge: true });
  console.log(`Kill switch ${config.killSwitchPath} = enabled. Set enabled:false in the console to stop every loop.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
