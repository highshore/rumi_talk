/**
 * Firebase Cloud Functions for RumiTalk Stream Chat Integration
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

// Stream Chat configuration
const STREAM_API_KEY = 'qrsw4u3qg89f';
const STREAM_API_SECRET = 'w4xm7cwxtpmk79wycfsy83kbxp7bgwjqkg9edsx9nvr8gk3khsat48vdf9yzgkqz';

/**
 * Create a Stream Chat JWT token for the given user ID
 * @param {string} userId - The Stream user ID (should match Firebase UID)
 * @param {number} issuedAt - Optional timestamp for when token was issued (defaults to now)
 * @returns {string} JWT token string
 */
function createStreamToken(userId, issuedAt = null) {
  if (!issuedAt) {
    issuedAt = Math.floor(Date.now() / 1000);
  }

  const payload = {
    user_id: userId,
    iat: issuedAt,
    exp: issuedAt + (24 * 60 * 60) // Token expires in 24 hours
  };

  return jwt.sign(payload, STREAM_API_SECRET, { algorithm: 'HS256' });
}

/**
 * Firebase Cloud Function to generate Stream Chat tokens
 */
exports.generateStreamToken = onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    // Get user ID from request
    const { userId } = request.data;
    if (!userId) {
      throw new HttpsError('invalid-argument', 'userId is required');
    }

    // Verify the requesting user matches the user ID
    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Can only generate tokens for authenticated user');
    }

    // Verify user exists in Firebase Auth
    try {
      await admin.auth().getUser(userId);
    } catch (error) {
      throw new HttpsError('not-found', 'User not found');
    }

    // Generate the token
    const token = createStreamToken(userId);
    
    console.log(`Generated Stream token for user: ${userId}`);
    
    return {
      token: token,
      userId: userId,
      success: true
    };
    
  } catch (error) {
    console.error('Error generating Stream token:', error);
    
    // Re-throw HttpsError as-is
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Internal server error');
  }
});

/**
 * Create Firebase custom tokens for authentication
 * This function was referenced in your existing auth code
 */
exports.createCustomToken = onCall(async (request) => {
  try {
    const data = request.data;
    
    // Validate required fields
    const requiredFields = ['uid', 'displayName', 'email'];
    for (const field of requiredFields) {
      if (!data[field]) {
        throw new HttpsError('invalid-argument', `Missing required field: ${field}`);
      }
    }
    
    const { uid, displayName, email, photoURL = '' } = data;
    
    // Additional claims for the token
    const additionalClaims = {
      displayName,
      email,
    };
    
    if (photoURL) {
      additionalClaims.photoURL = photoURL;
    }
    
    // Create the custom token
    const customToken = await admin.auth().createCustomToken(uid, additionalClaims);
    
    // Store/update user data in Firestore
    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    
    const userData = {
      uid,
      displayName,
      email,
      photoURL,
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Check if user exists
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      // New user - set creation timestamp
      userData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      await userRef.set(userData);
      console.log(`Created new user document for: ${uid}`);
    } else {
      // Existing user - merge data
      await userRef.update({
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        displayName,
        photoURL
      });
      console.log(`Updated existing user document for: ${uid}`);
    }
    
    return {
      token: customToken,
      uid,
      success: true
    };
    
  } catch (error) {
    console.error('Error creating custom token:', error);
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', 'Failed to create custom token');
  }
});

/**
 * getReplySuggestions - Generate short reply suggestions via OpenAI based on recent chat history.
 * Uses a secret OPENAI_API_KEY set via: firebase functions:secrets:set OPENAI_API_KEY
 */
exports.getReplySuggestions = onCall({ secrets: ['OPENAI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const data = request.data || {};
    /** @type {string[]} */
    const recentMessages = Array.isArray(data.recentMessages) ? data.recentMessages : [];
    const language = typeof data.language === 'string' && data.language.trim() ? data.language.trim() : 'English';

    if (recentMessages.length === 0) {
      throw new HttpsError('invalid-argument', 'recentMessages (array of strings) is required');
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY is not configured');
    }

    const convo = recentMessages.slice(-20).join('\n');
    const system = `You are an assistant that writes concise, friendly, natural ${language} chat replies. Return ONLY a JSON array of 3 short suggestions (max 20 words each), no extra text.`;
    const user = `Recent chat transcript (most recent last):\n${convo}\n\nPlease suggest three possible replies.`;

    // Call OpenAI Chat Completions API using native fetch (Node 18+)
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user }
        ],
        temperature: 0.7,
        max_completion_tokens: 200,
      })
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error('OpenAI error response:', text);
      throw new HttpsError('internal', 'OpenAI request failed');
    }
    const json = await resp.json();
    const content = json?.choices?.[0]?.message?.content || '';

    let suggestions = [];
    try {
      suggestions = JSON.parse(content);
    } catch (_) {
      // Fallback: split lines and take non-empty ones
      suggestions = content
        .split('\n')
        .map((s) => s.replace(/^[-*\d\.\)\s]+/, '').trim())
        .filter(Boolean)
        .slice(0, 3);
    }

    if (!Array.isArray(suggestions) || suggestions.length === 0) {
      throw new HttpsError('internal', 'Failed to parse suggestions');
    }

    // Ensure string-only and trim length
    suggestions = suggestions
      .map((s) => String(s).trim())
      .filter(Boolean)
      .map((s) => (s.length > 120 ? s.slice(0, 117) + '...' : s))
      .slice(0, 3);

    return { suggestions };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('getReplySuggestions error:', error);
    throw new HttpsError('internal', 'Failed to generate suggestions');
  }
});

/**
 * translateText - Translate user text into a target language via OpenAI
 */
exports.translateText = onCall({ secrets: ['OPENAI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const data = request.data || {};
    const text = typeof data.text === 'string' ? data.text.trim() : '';
    const targetLang = (typeof data.targetLang === 'string' && data.targetLang.trim()) ? data.targetLang.trim() : 'English';
    /** @type {string[]} */
    const history = Array.isArray(data.history) ? data.history.slice(-10) : [];
    const meta = (typeof data.meta === 'object' && data.meta) ? data.meta : {};

    if (!text) {
      throw new HttpsError('invalid-argument', 'text is required');
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY is not configured');
    }

    const metaStr = Object.keys(meta).length ? `Context: ${JSON.stringify(meta)}` : '';
    const histStr = history.length ? `Recent messages (latest last):\n${history.join('\n')}` : '';

    const system = `You are a professional translator and editor. If the input text is already written in ${targetLang}, improve/refine it (fix grammar, clarity, tone) and return the refined version in ${targetLang}. Otherwise, translate it into ${targetLang}. Preserve meaning and style, keep it concise and natural. Return ONLY the final text.`;
    const user = [metaStr, histStr, `Text to translate:\n${text}`].filter(Boolean).join('\n\n');

    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
        temperature: 0.2,
        max_completion_tokens: 200,
      })
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error('OpenAI translate error:', text);
      throw new HttpsError('internal', 'Translation request failed');
    }

    const json = await resp.json();
    const translatedText = json?.choices?.[0]?.message?.content?.trim() || '';
    if (!translatedText) {
      throw new HttpsError('internal', 'Empty translation');
    }

    return { translatedText };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('translateText error:', error);
    throw new HttpsError('internal', 'Failed to translate');
  }
});

/**
 * Friend Requests - Send/Accept/Decline/Cancel
 */

/**
 * Helper to resolve a target user by uid or email
 */
async function resolveTargetUid(db, { targetUid, targetEmail }) {
  if (targetUid && typeof targetUid === 'string' && targetUid.trim().length > 0) {
    return targetUid.trim();
  }
  if (targetEmail && typeof targetEmail === 'string' && targetEmail.trim().length > 0) {
    const snap = await db
      .collection('users')
      .where('email', '==', targetEmail.trim())
      .limit(1)
      .get();
    if (snap.empty) {
      throw new HttpsError('not-found', 'User with that email not found');
    }
    return snap.docs[0].id;
  }
  throw new HttpsError('invalid-argument', 'targetUid or targetEmail is required');
}

exports.sendFriendRequest = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const db = admin.firestore();
    const senderUid = request.auth.uid;
    const targetUid = await resolveTargetUid(db, request.data || {});

    if (senderUid === targetUid) {
      throw new HttpsError('failed-precondition', 'Cannot send a request to yourself');
    }

    const senderRef = db.collection('users').doc(senderUid);
    const targetRef = db.collection('users').doc(targetUid);

    const result = await db.runTransaction(async (tx) => {
      const [senderDoc, targetDoc] = await tx.getAll(senderRef, targetRef);
      if (!targetDoc.exists) {
        throw new HttpsError('not-found', 'Target user not found');
      }

      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const targetData = targetDoc.data() || {};

      const senderFriends = new Set(senderData.friends || []);
      const senderSent = new Set(senderData.friend_requests_sent || []);
      const senderReceived = new Set(senderData.friend_requests_received || []);
      const targetFriends = new Set(targetData.friends || []);
      const targetSent = new Set(targetData.friend_requests_sent || []);
      const targetReceived = new Set(targetData.friend_requests_received || []);

      if (senderFriends.has(targetUid) || targetFriends.has(senderUid)) {
        return { status: 'already_friends' };
      }
      if (senderSent.has(targetUid)) {
        return { status: 'already_sent' };
      }
      // If target has already sent a request to sender, auto-accept
      if (senderReceived.has(targetUid) || targetSent.has(senderUid)) {
        tx.set(senderRef, {
          friend_requests_received: admin.firestore.FieldValue.arrayRemove(targetUid),
          friends: admin.firestore.FieldValue.arrayUnion(targetUid),
        }, { merge: true });
        tx.set(targetRef, {
          friend_requests_sent: admin.firestore.FieldValue.arrayRemove(senderUid),
          friends: admin.firestore.FieldValue.arrayUnion(senderUid),
        }, { merge: true });
        return { status: 'accepted' };
      }

      // Otherwise, create a new pending request
      tx.set(senderRef, {
        friend_requests_sent: admin.firestore.FieldValue.arrayUnion(targetUid),
      }, { merge: true });
      tx.set(targetRef, {
        friend_requests_received: admin.firestore.FieldValue.arrayUnion(senderUid),
      }, { merge: true });

      return { status: 'sent' };
    });

    return { success: true, ...result };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('sendFriendRequest error:', error);
    throw new HttpsError('internal', 'Failed to send friend request');
  }
});

exports.acceptFriendRequest = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const db = admin.firestore();
    const recipientUid = request.auth.uid; // the user accepting the request
    const { fromUid } = request.data || {};
    if (!fromUid) throw new HttpsError('invalid-argument', 'fromUid is required');
    if (fromUid === recipientUid) throw new HttpsError('failed-precondition', 'Cannot accept your own request');

    const recipientRef = db.collection('users').doc(recipientUid);
    const senderRef = db.collection('users').doc(fromUid);

    await db.runTransaction(async (tx) => {
      const [recipientDoc, senderDoc] = await tx.getAll(recipientRef, senderRef);
      if (!senderDoc.exists) throw new HttpsError('not-found', 'Requesting user not found');
      const recData = recipientDoc.exists ? recipientDoc.data() : {};
      const recReceived = new Set(recData.friend_requests_received || []);
      if (!recReceived.has(fromUid)) {
        // idempotent: nothing to accept
        return;
      }
      tx.set(recipientRef, {
        friend_requests_received: admin.firestore.FieldValue.arrayRemove(fromUid),
        friends: admin.firestore.FieldValue.arrayUnion(fromUid),
      }, { merge: true });
      tx.set(senderRef, {
        friend_requests_sent: admin.firestore.FieldValue.arrayRemove(recipientUid),
        friends: admin.firestore.FieldValue.arrayUnion(recipientUid),
      }, { merge: true });
    });

    return { success: true };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('acceptFriendRequest error:', error);
    throw new HttpsError('internal', 'Failed to accept friend request');
  }
});

exports.declineFriendRequest = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const db = admin.firestore();
    const recipientUid = request.auth.uid; // the user declining the request
    const { fromUid } = request.data || {};
    if (!fromUid) throw new HttpsError('invalid-argument', 'fromUid is required');

    const recipientRef = db.collection('users').doc(recipientUid);
    const senderRef = db.collection('users').doc(fromUid);

    await db.runTransaction(async (tx) => {
      await tx.getAll(recipientRef, senderRef); // ensure both exist or fail silently
      tx.set(recipientRef, {
        friend_requests_received: admin.firestore.FieldValue.arrayRemove(fromUid),
      }, { merge: true });
      tx.set(senderRef, {
        friend_requests_sent: admin.firestore.FieldValue.arrayRemove(recipientUid),
      }, { merge: true });
    });

    return { success: true };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('declineFriendRequest error:', error);
    throw new HttpsError('internal', 'Failed to decline friend request');
  }
});

exports.cancelFriendRequest = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const db = admin.firestore();
    const senderUid = request.auth.uid; // the user canceling the request they sent
    const { toUid } = request.data || {};
    if (!toUid) throw new HttpsError('invalid-argument', 'toUid is required');

    const senderRef = db.collection('users').doc(senderUid);
    const recipientRef = db.collection('users').doc(toUid);

    await db.runTransaction(async (tx) => {
      await tx.getAll(senderRef, recipientRef);
      tx.set(senderRef, {
        friend_requests_sent: admin.firestore.FieldValue.arrayRemove(toUid),
      }, { merge: true });
      tx.set(recipientRef, {
        friend_requests_received: admin.firestore.FieldValue.arrayRemove(senderUid),
      }, { merge: true });
    });

    return { success: true };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('cancelFriendRequest error:', error);
    throw new HttpsError('internal', 'Failed to cancel friend request');
  }
});
