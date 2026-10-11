# Authoritative mobile-session contract

`GET /api/mobile/session` is the only source that may authorize a fresh CISS
Mobile session after Firebase authentication.

The backend must verify the Firebase bearer token, locate the user in the
currently selected region, and require an active linked profile before
responding successfully:

- Guard: an active Guard/employee profile linked to the Firebase UID.
- Field Officer: an active Field Officer profile linked to the Firebase UID.

For a missing, inactive, or mismatched profile, return a neutral `401` and
never infer the role from Firebase custom claims. The response must not reveal
whether a linked Guard or Field Officer record exists. A successful response
must include the authenticated Firebase `uid`, a supported `role`, and the
linked-profile context used by the mobile client.

The mobile client fails closed on all unsuccessful, malformed, or unavailable
session responses. Firebase custom claims may optimize backend lookup but must
not independently create a mobile session.
