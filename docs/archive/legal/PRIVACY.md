# Privacy Policy — Expenso

*Last updated: 2025*

Expenso ("we") collects and uses the following data to provide group expense tracking and settlement features.

## Data we collect

- **Phone number** — Used for sign-in and to invite or match you in groups. Stored securely (Firebase Auth and, if configured, encrypted in Firestore).
- **Display name and profile photo** — You set these in the app. Used to show who is in a group and for natural-language expense parsing (e.g. "Dinner with Ash").
- **UPI ID** — Optional. You provide it for payment settings so others can pay you via UPI. Stored only if you enter it.
- **Group and expense data** — Group names, member lists, expense descriptions, amounts, and split information. Stored in Firebase Firestore; may be encrypted at rest if the project administrator has enabled encryption.

We do not sell your data to third parties.

## How we use it

- To let you create and join groups, add expenses, and see who owes whom.
- To enable in-app settlement (e.g. opening your chosen UPI app with pre-filled payment details).
- To improve the app (e.g. crash/analytics if you have not disabled it).

## Third parties

- **Firebase** (Google) — Authentication, database, storage, and optional push. See [Google Privacy Policy](https://policies.google.com/privacy).
- **Groq** — Natural-language expense parsing (Magic Bar). Only the text you type and group member names are sent; see your Groq agreement.
- **UPI apps** — When you pay via UPI, the payment is handled by your chosen app (e.g. GPay, PhonePe). We do not see or store your banking details.

## Your choices

- You can delete your account or leave groups. Deleting a group removes its data for all members.
- You can log out at any time from Profile.

## Contact

For privacy questions, contact the app owner or repository maintainer (see the repository or app store listing).
