import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {defineString} from "firebase-functions/params";

admin.initializeApp();

const spotifyClientId = defineString("SPOTIFY_CLIENT_ID");
const spotifyClientSecret = defineString("SPOTIFY_CLIENT_SECRET");

export const getSpotifyAccessToken = functions.https.onCall(async () => {
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": "Basic " +
        Buffer.from(
          spotifyClientId.value() + ":" + spotifyClientSecret.value()
        ).toString("base64"),
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    throw new functions.https.HttpsError(
      "internal",
      "Failed to get Spotify token"
    );
  }

  const data = await response.json();
  return {accessToken: data.access_token};
});

