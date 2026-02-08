# Auth Implementation Context - Forge App

**Date:** February 2025  
**Purpose:** Handoff document for continuing auth work on the Forge fitness app. Use this to bring a new AI agent (or developer) up to speed on what we're building and where we left off.

---

## What We're Building

A full authentication flow for the Forge app:

1. **Login screen** – Email/password login
2. **Logout** – Sign out (likely on Profile page)
3. **Registration** – Sign up as either a **regular user** or a **gym** (account type selection)
4. **Edit account info** – Update name, contact info, profile photo (Profile page already has UI for this but no Firestore persistence yet)

---

## Where We Are Right Now

We are **building the login screen**. The user is intentionally writing the code themselves to learn.

### Completed

1. **Login page file created** – `lib/features/auth/presentation/view/login_page.dart`
2. **Login route added** – `/login` route added to `lib/app/router.dart` (outside the ShellRoute so no bottom nav)
3. **Initial location set** – App starts at `/login` instead of `/feed`
4. **Login page structure** – Placeholder page exists; user was converting it from StatelessWidget to StatefulWidget and adding the login form UI:
   - Email TextField
   - Password TextField (obscureText: true)
   - Login/Sign in button
   - Optional: "Don't have an account? Register" link
   - TextEditingControllers for email and password (with dispose)

### Not Yet Done (Next Steps)

1. **Finish login form UI** – Ensure all form elements are in place and wired up
2. **Connect to Firebase Auth** – Call `FirebaseAuth.instance.signInWithEmailAndPassword()` when the login button is pressed
3. **Handle auth state** – Redirect to `/feed` on successful login; show error on failure
4. **Remove anonymous sign-in** – Currently `main.dart` signs in anonymously on startup; that will need to change once real auth is in place
5. **Auth guard / redirect logic** – Unauthenticated users should see login; authenticated users should see the main app

---

## Current App Setup

- **Framework:** Flutter
- **Auth:** Firebase Auth (firebase_auth package)
- **Routing:** GoRouter
- **Main entry:** `lib/main.dart` – currently calls `FirebaseAuth.instance.signInAnonymously()` on startup
- **Auth service:** `lib/services/auth_service.dart` – exists but is empty (placeholder)
- **Firestore rules:** `FIRESTORE_RULES_SETUP.md` documents rules for `users` and `user_preferences` collections

---

## Key File Paths

| File | Purpose |
|------|---------|
| `lib/features/auth/presentation/view/login_page.dart` | Login screen |
| `lib/app/router.dart` | Routes including `/login` (outside ShellRoute) |
| `lib/main.dart` | App entry; currently anonymous sign-in |
| `lib/services/auth_service.dart` | Auth logic (empty for now) |
| `lib/features/profile/presentation/view/profile_page.dart` | Profile with edit UI (no Firestore yet) |

---

## User's Preference

The user wants to **write the code themselves** to learn. Prefer giving instructions, syntax examples, and step-by-step guidance rather than writing the code for them.
