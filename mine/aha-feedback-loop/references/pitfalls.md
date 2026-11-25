# Pitfalls (all hit in the first deployment)

| Symptom | Cause | Fix |
|---|---|---|
| Resolution comments on GitHub never reach the client's idea | The integration syncs GitHub comments to the **feature**, not the idea; portal users see only the idea | Post the client's resolution on the **idea** (owner-approved, via the API). Treat GitHub comments as client-visible anyway if the client has workspace seats |
| The idea shows "Complete" with no explanation | Closing the issue → Shipped → idea Complete happens automatically, without a comment on the idea | Post the approved note on the idea **before** closing, so the Complete email arrives with context |
| A comment posted via the API isn't visible in the portal | `POST /ideas/:ref/comments` creates a **workspace** comment; portal comments are `/idea_comments` | Choose the target explicitly per write; default client replies to `portal` |
| The poller missed a client's reply | It read only `/comments`; the client replied in the portal (`/idea_comments`) | Poll all three lists: idea portal, idea workspace, feature |
| Internal GitHub issues appear in Aha! with internal jargon | The integration imports **every new repo issue** as a feature | An admin sets import to "Approve new records before importing". Until then, create no internal issues; unlink, then delete the leaked feature |
| A merged PR marked the client's idea Complete before verification | The PR said "Closes #n" | "Refs #n" only, written into the repo's agent guide and PR template; the lead closes after verification |
| Every API call returns 401 | The value in the Keychain isn't the key (a sentence, part of a command, a label) | Check length and spaces without printing it; the owner re-stores it with `security add-generic-password -U … -w` |
| 403 "Your role is 'contributor'" on integrations or portal settings | Contributor keys can't read workspace or portal configuration | Ask the owner or an admin for a screenshot; don't escalate the bot's role for this |
| Client-visible text contains PR numbers, thread names or "replica"-style internal words | Progress notes were written for the team, not the client | Client-tone rules on every linked-issue comment and Aha! post; refer to records by title or Aha! ref |
| The owner pasted the key into chat | Asked for the key instead of a hidden prompt | Never ask for it in chat. If it happens: revoke, regenerate, re-store via the hidden prompt |
| Client personal data in an out-of-scope idea (e.g. a list of staff emails) | Clients use the portal for admin requests too | Mark it excluded in the state; never quote or copy it |
| Status changes emailed the client unexpectedly | Portal email settings weren't checked | Treat every idea status change as an email until the owner confirms the settings |
| Timer off by a day around travel or holidays | Counted in the wrong zone, or ignored observed holidays | Count in the owner's home zone; observed federal holidays (Saturday → Friday, Sunday → Monday) |
| Lockfile churn when adding the tool package | A non-frozen install rewrote unrelated entries | Add only the new importer; verify with `pnpm install --frozen-lockfile` |
