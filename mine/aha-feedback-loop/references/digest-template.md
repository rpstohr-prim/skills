# Owner digest template

One digest per triage run that has anything new. Batch; don't drip. It goes to the owner in chat
(directly, or relayed by the lead), **never into Aha!**. Client text appears only quoted.

```
Feedback digest — <date> — <n> new, <n> awaiting you, <n> closed since last

1. [P1] ABC-I-7 (ABC-5, #123) + ABC-I-9 → one fix: "<short title of the fix>"
   Fix → promote · Type content · Thread <team> · Size S · Owner action: <e.g. re-run the draft after the fix>
   Proposed: <what changes, at the source and in the instance (systemic check)>
   On yes, the agent will: promote to a feature (opens the GitHub issue).
   Approve? ▢ yes ▢ change ▢ no

2. [Answer] ABC-I-8 → "<question in a few words>"
   Proposed: answer from <doc, page>.
   On yes, the agent will: post the reply, status Explanation Given.
   Draft reply (posted as <key user> on Aha!, client-visible):
   > <exact text>
   Approve? ▢ yes ▢ change ▢ no

3. [Ready for client review] ABC-I-4 (ABC-3, #110) → "<fix>" is live (deploy run <id>) and verified
   Draft note (client-visible):
   > Fixed and live since <date>. <What changed, in plain words.> To see it, <how>.
   Approve? ▢ yes ▢ change ▢ no

Changes since last run:
- ABC-I-2 (ABC-1, #101): Planned → Ready for Client Review
- ABC-I-6: new CLIENT comment in the portal (<time>Z)
- Feature ABC-14 has no client idea (GitHub #130): "<title>"   ← leaked internal issue

In client review (N US business days, then auto-close with the fixed note):
- ABC-I-2 (ABC-1, #101): since <date>, 3 business days, closes <date>

Open: <n> (new 1 · in-progress 4 · in-review 1) · awaiting you: 3
Measures: time to triage <x> · approval → live <y> · reopen rate <z>
```

A plain **"yes to all"** approves every item. Record each approval with its exact text before
applying it.

## Client-tone rules (any text that reaches Aha!, including GitHub comments on linked issues)

- Plain English in the client's terms: the screen or item name, what changed, when it went live,
  how to see it.
- No PR or issue numbers, thread or team names, file names, commit hashes, ADRs or internal
  component names. Refer to another record by its title or Aha! reference.
- Use the same summary for the GitHub closing comment and the Aha! resolution.
