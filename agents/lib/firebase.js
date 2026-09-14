// Firebase Admin bootstrap shared by every script (modular API, admin v14).
// Credentials: agents/serviceAccount.json (gitignored) or GOOGLE_APPLICATION_CREDENTIALS.

const fs = require("fs");
const path = require("path");
const { initializeApp, cert, applicationDefault, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const config = require("../config");

let app;

function init() {
  if (app) return app;
  if (getApps().length) { app = getApps()[0]; return app; }
  const local = path.join(__dirname, "..", "serviceAccount.json");
  const options = { projectId: config.projectId, storageBucket: config.storageBucket };
  if (fs.existsSync(local)) {
    options.credential = cert(JSON.parse(fs.readFileSync(local, "utf8")));
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    options.credential = applicationDefault();
  } else {
    console.error(
      "No credentials. Put the service account key at agents/serviceAccount.json\n" +
      "(Firebase console → Project settings → Service accounts → Generate new private key)\n" +
      "or set GOOGLE_APPLICATION_CREDENTIALS."
    );
    process.exit(1);
  }
  app = initializeApp(options);
  return app;
}

function db() { init(); return getFirestore(app); }
function auth() { init(); return getAuth(app); }
function bucket() { init(); return getStorage(app).bucket(); }

/** Reads config/agents; a missing document counts as disabled. */
async function agentsEnabled() {
  const snap = await db().doc(config.killSwitchPath).get();
  return snap.exists && snap.data().enabled === true;
}

/** Every agent write goes through here so nothing is ever untagged. */
function tagged(agentId, data) {
  if (!agentId) throw new Error("tagged(): agentId missing");
  return { ...data, agentId };
}

/** Sleeps `ms`, waking early (checked every second) once `shouldStop()` is true. */
function sleep(ms, shouldStop = () => false) {
  return new Promise((resolve) => {
    const end = Date.now() + ms;
    const tick = () => {
      if (shouldStop() || Date.now() >= end) return resolve();
      setTimeout(tick, Math.min(1000, end - Date.now()));
    };
    tick();
  });
}

module.exports = { init, db, auth, bucket, FieldValue, Timestamp, agentsEnabled, tagged, sleep };
