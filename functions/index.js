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
