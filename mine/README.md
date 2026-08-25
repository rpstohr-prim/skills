# mine/

My own skills. One directory per skill, each containing `SKILL.md`.

Optional supporting files a skill can carry (Corey's `cro` skill is a good
worked example):

```
mine/<skill>/
├── SKILL.md          required — frontmatter + instructions
├── references/       long reference docs the skill tells the model to read
├── scripts/          executable helpers the skill invokes
└── evals/            test cases for /skill-creator's eval runner
```

Keep `SKILL.md` short and push detail into `references/` — the body loads into
context every time the skill fires, references only when asked for.
