const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ─────────────────────────────────────────────
// 1. New Like Received → Push to receiver
// ─────────────────────────────────────────────
exports.onNewLikeReceived = onDocumentCreated(
  "users/{userId}/likesReceived/{likeId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const receiverUid = event.params.userId;
    const senderName = data.fromUserDisplayName || "Someone";
    const trackTitle = data.trackTitle || "a track";

    const token = await getFCMToken(receiverUid);
    if (!token) return;

    const message = {
      token,
      notification: {
        title: `${senderName} liked your track!`,
        body: `"${trackTitle}" got a new like.`,
      },
      data: {
        type: "likeReceived",
        likeId: event.params.likeId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await sendPush(message, receiverUid);
  }
);

// ─────────────────────────────────────────────
// 2. Like Accepted → Push to original liker
// ─────────────────────────────────────────────
exports.onLikeAccepted = onDocumentUpdated(
  "users/{userId}/likesReceived/{likeId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only trigger when status changes to "accepted"
    if (before.status === "accepted" || after.status !== "accepted") return;

    const likerUid = after.fromUserId;
    const receiverUid = event.params.userId;

    if (!likerUid) return;

    // Fetch receiver display name
    const receiverDoc = await db.collection("users").doc(receiverUid).get();
    const receiverName = receiverDoc.exists
      ? receiverDoc.data().displayName || "Someone"
      : "Someone";

    const trackTitle = after.trackTitle || "a track";

    const token = await getFCMToken(likerUid);
    if (!token) return;

    const message = {
      token,
      notification: {
        title: `${receiverName} accepted your interaction!`,
        body: `Your like on "${trackTitle}" was accepted. Start chatting!`,
      },
      data: {
        type: "likeAccepted",
        likeId: event.params.likeId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await sendPush(message, likerUid);
  }
);

// ─────────────────────────────────────────────
// 3. New Chat Message → Push to other participant
// ─────────────────────────────────────────────
exports.onNewChatMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const conversationId = event.params.conversationId;
    const senderUid = data.senderId;
    const text = data.text || "";

    // Get conversation to find the other participant
    const convoDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    if (!convoDoc.exists) return;

    const convoData = convoDoc.data();
    const participants = convoData.participantIds || [];

    // Find recipient (the participant who is NOT the sender)
    const recipientUid = participants.find((uid) => uid !== senderUid);
    if (!recipientUid) return;

    // Fetch sender display name
    const senderDoc = await db.collection("users").doc(senderUid).get();
    const senderName = senderDoc.exists
      ? senderDoc.data().displayName || "Someone"
      : "Someone";

    const token = await getFCMToken(recipientUid);
    if (!token) return;

    const message = {
      token,
      notification: {
        title: senderName,
        body: text.length > 100 ? text.substring(0, 100) + "…" : text,
      },
      data: {
        type: "chatMessage",
        conversationId,
        messageId: event.params.messageId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await sendPush(message, recipientUid);
  }
);

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

async function getFCMToken(uid) {
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return null;
    return userDoc.data().fcmToken || null;
  } catch (err) {
    console.error(`Failed to get FCM token for ${uid}:`, err);
    return null;
  }
}

async function sendPush(message, recipientUid) {
  try {
    await getMessaging().send(message);
    console.log(`✅ Push sent to ${recipientUid}`);
  } catch (err) {
    console.error(`❌ Push failed for ${recipientUid}:`, err.message);

    // If token is invalid, remove it from Firestore
    if (
      err.code === "messaging/invalid-registration-token" ||
      err.code === "messaging/registration-token-not-registered"
    ) {
      console.log(`🗑️ Removing stale FCM token for ${recipientUid}`);
      await db.collection("users").doc(recipientUid).update({
        fcmToken: null,
      });
    }
  }
}
