# Firestore Security Rules Setup Guide

## Quick Fix for Permission Denied Error

If you're getting a `permission-denied` error when signing up, you need to update your Firestore security rules.

## Steps to Fix:

### 1. Open Firebase Console
- Go to: https://console.firebase.google.com/
- Select your project: **forge-by-alpfit**

### 2. Navigate to Firestore Rules
- Click **Firestore Database** in the left sidebar
- Click the **Rules** tab at the top

### 3. Copy and Paste These Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection: Allow authenticated users to create and update their own account
    match /users/{userId} {
      // Anyone can read user accounts (needed for friend lists, gym lists, etc.)
      allow read: if true;
      
      // Users can create their own account document during signup
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // Users can update their own account
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Users cannot delete their account (handle this separately if needed)
      allow delete: if false;
    }
    
    // User's events subcollection
    // - Owners can read/write their own events
    // - Friends can read public events (owner is in requester's friendIds)
    // - Joined gyms' public events are readable (gym id is in requester's joinedGymIds)
    match /users/{userId}/events/{eventId} {
      allow read: if request.auth != null && (
        request.auth.uid == userId
        || (resource.data.isPublic == true
            && userId in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('friendIds', []))
        || (resource.data.isPublic == true
            && userId in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('joinedGymIds', []))
      );
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Gym channel posts live under the gym user's doc.
    // - Gym owner can read/write
    // - Joined members can read posts/comments, create posts/comments, and like posts
    match /users/{gymUid}/channelPosts/{postId} {
      allow read: if request.auth != null && (
        request.auth.uid == gymUid
        || gymUid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('joinedGymIds', [])
      );
      allow create: if request.auth != null && (
        request.auth.uid == gymUid
        || gymUid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('joinedGymIds', [])
      );
      allow update: if request.auth != null && (
        request.auth.uid == gymUid
        || gymUid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('joinedGymIds', [])
      );
      allow delete: if request.auth != null && (
        request.auth.uid == gymUid
        || request.auth.uid == resource.data.authorUid
      );

      match /comments/{commentId} {
        allow read: if request.auth != null && (
          request.auth.uid == gymUid
          || gymUid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('joinedGymIds', [])
        );
        allow create: if request.auth != null && (
          request.auth.uid == gymUid
          || gymUid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('joinedGymIds', [])
        );
        allow delete: if request.auth != null && (
          request.auth.uid == gymUid
          || request.auth.uid == resource.data.authorUid
        );
        allow update: if false;
      }
    }
    
    // User preferences collection: Users can only read/write their own preferences
    match /user_preferences/{userId} {
      // Users can read their own preferences
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Users can create their own preferences document during signup
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // Users can update their own preferences
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Users cannot delete their preferences (handle this separately if needed)
      allow delete: if false;
    }
  }
}
```

### 4. Publish the Rules
- Click the **Publish** button
- Wait for the confirmation message

### 5. Test
- Try signing up again in your app
- The permission error should be resolved!

## What These Rules Do:

✅ **Allow signup**: Users can create their own `users` and `userPreferences` documents  
✅ **Allow profile updates**: Users can update their own account and preferences  
✅ **Allow reading**: Anyone can read user accounts (needed for friend lists and gym lists)  
✅ **Security**: Users can only modify their own data, not others'  
✅ **Friends' public events**: Users can read public events from people in their friend list (calendar feature)  
✅ **Gyms' public events**: Users can read public events from gyms they have joined (calendar feature)  
✅ **Goals**: Users can read/write their own goals in `users/{userId}/goals/{goalId}`

## Deploying Rules from firestore.rules

If you have `firestore.rules` in the project root, deploy with:

```bash
firebase deploy --only firestore:rules
```  

## Troubleshooting:

- **Still getting errors?** Make sure you clicked "Publish" after pasting the rules
- **Rules not updating?** Wait a few seconds and try again - rules can take a moment to propagate
- **Need to allow reading other users' preferences?** Change the `userPreferences` read rule to `allow read: if true;` (currently only allows reading your own)

