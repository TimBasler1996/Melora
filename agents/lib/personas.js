const fs = require("fs");
const path = require("path");

const PERSONAS_PATH = path.join(__dirname, "..", "personas.json");

function load() {
  if (!fs.existsSync(PERSONAS_PATH)) {
    throw new Error("agents/personas.json missing. Run `node genPersonas.js`.");
  }
  const list = JSON.parse(fs.readFileSync(PERSONAS_PATH, "utf8"));
  return list.map((p) => ({ ...p, uid: uidFor(p.handle) }));
}

function uidFor(handle) { return `agent_${handle}`; }

module.exports = { load, uidFor, PERSONAS_PATH };
