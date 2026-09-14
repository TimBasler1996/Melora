// Canned first messages for a like-with-message to a real user. No LLM in
// the tick loop; the chat listener takes over once the person answers.

const OPENERS = {
  "de-CH": [
    "Hey, {title} läuft bei mir gerade auch auf Repeat 🙂",
    "{artist} in {place}, gute Wahl!",
    "Oh, {title}! Hab ich ewig nicht mehr gehört. Was hörst du sonst so?",
    "Hallo! Dein Song hat mich grad gecatcht. Kennst du mehr von {artist}?",
    "{title} passt mega zum Wetter heute. Hast du eine Playlist dazu?",
  ],
  "fr-CH": [
    "Salut, {title} tourne en boucle chez moi aussi 🙂",
    "{artist} à {place}, bon choix !",
    "Oh, {title} ! Ça faisait longtemps. Tu écoutes quoi d'autre ?",
    "Hello ! Ton morceau m'a accroché. Tu connais d'autres trucs de {artist} ?",
    "{title} colle parfaitement à la journée. T'as une playlist avec ?",
  ],
};

function opener(language, { title, artist, place }, rng) {
  const list = OPENERS[language] || OPENERS["de-CH"];
  const text = rng.pick(list)
    .replace("{title}", title)
    .replace("{artist}", artist)
    .replace("{place}", place);
  return text.slice(0, 160);
}

module.exports = { opener };
