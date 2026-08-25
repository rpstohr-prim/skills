# skills

Private, portable skill library — my own skills plus vetted third-party collections,
installable into any Claude Code setup (personal or per-project).

## Layout

```
mine/<skill>/SKILL.md      my skills — the only place I edit
vendor/<source>/skills/    upstream snapshots, replaced wholesale on sync
bin/install-skills.sh      symlink skills into a .claude/skills dir
bin/sync-vendor.sh         re-pull an upstream collection
```

Skills install **flat** (`~/.claude/skills/<skill>/SKILL.md`) because that is the
only layout Claude Code discovers — the `mine/` vs `vendor/` split exists in the
repo, not in the install target.

## Install

```bash
bin/install-skills.sh                    # everything -> ~/.claude/skills
bin/install-skills.sh --only mine        # just mine
bin/install-skills.sh --target /path/to/project/.claude/skills
bin/install-skills.sh --dry-run
```

Symlinks by default, so `git pull` here updates every machine-wide skill at once.
`--copy` for machines where symlinks are awkward (Replit, containers). Existing
skills that did not come from this repo are never overwritten — they're reported
as `skip`.

## Adding my own skill

```
mine/<kebab-name>/SKILL.md
```

with frontmatter:

```yaml
---
name: my-skill
description: "When the user wants to ... Also use when the user says '...'."
metadata:
  version: 1.0.0
---
```

The `description` is the only thing the model sees when deciding whether to load
the skill, so write it as trigger phrases, not a summary. `/skill-creator` in
Claude Code scaffolds and evals one.

## Customising a vendored skill

Don't edit `vendor/` — `bin/sync-vendor.sh` blows it away. Copy the skill into
`mine/` under a distinct name and edit there. Same-named skills are a collision at
install time; the first source wins and the second is skipped, so rename rather
than shadow.

## Updating upstream

```bash
bin/sync-vendor.sh                            # all vendors
bin/sync-vendor.sh coreyhaines-marketingskills
```

Commit the diff — that's the audit trail of what changed upstream.

## Sources

| Vendor | Skills | License |
|---|---|---|
| [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | 50 | MIT |

See [NOTICE.md](NOTICE.md) for attribution.
