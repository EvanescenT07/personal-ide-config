# Agent Skills & Plugins Registry

Skill lockfiles, unified plugin/skill metadata, and the repository-shipped `ide-config-adapter` skill.

## Files

- [`.skill-lock.json`](.skill-lock.json): Lockfile tracking 15 skills installed via `npx skills` (Vercel, Anthropic, MiniMax, Firebase, Flutter, Auth0, Figma).
- [`manifest.json`](manifest.json): Unified catalog covering the 15 lockfile skills, 5 Antigravity plugins (`android-cli-plugin`, `antislop`, `coderabbit`, `firebase`, `google-antigravity-sdk`), 5 global standalone skills (`caveman`, `flutter-animating-apps`, `graphify`, `reels-storyboard-architect`, `reverse-engineer-anything`), and `ide-config-adapter`.
- [`ide-config-adapter/SKILL.md`](ide-config-adapter/SKILL.md): Actionable skill instructing any AI agent how to inspect a developer workstation and safely merge `ide/` and `agent/` templates.

## Restoring Skills on a New Machine

Install individual skills from [`manifest.json`](manifest.json) using `npx skills add`:

```bash
# Example: install Flutter and Figma skills globally
npx skills add flutter/skills --skill flutter-apply-architecture-best-practices -g -y
npx skills add figma/mcp-server-guide --skill figma-design-to-code -g -y
```

Or install all skills from a source repository at once:

```bash
npx skills add flutter/skills -g -y
npx skills add anthropics/skills -g -y
```

## Antigravity Plugins

Antigravity Marketplace plugins (`android-cli-plugin`, `antislop`, `coderabbit`, `firebase`, `google-antigravity-sdk`) are managed through the Antigravity Plugins Manager UI rather than `npx skills`. See [`../antigravity/config.template.json`](../antigravity/config.template.json).
