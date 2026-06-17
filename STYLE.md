# howtogit — Writing Standards & Chapter Template

These rules are mandatory for every chapter. Drafting agents must follow them
exactly.

## Hard rules

- **Exactly one H1 (`# `) per file.** It is the chapter title. Everything else
  is `##`/`###`. (The PDF page-break and table of contents depend on this.)
- **No invented flags or behavior.** Before mentioning any option, confirm it
  exists in the command's real `--help`. When unsure, omit it.
- Imperative voice. Short paragraphs. Concrete over abstract.
- Fenced code blocks with a language hint (` ```sh `, ` ```text `, ` ```console `).
- Show realistic, copy-pasteable commands. Where output matters, show it.
- Use GFM tables for option lists.
- Cross-reference other chapters by the command name in prose, e.g.
  "see the *rebase* chapter", not by filename.
- Mixed audience: a beginner can follow the Mental model and Everyday usage;
  a practitioner gets depth in Best practices, Pitfalls, and Worked examples.

## Command chapter template

A chapter documenting a single command (git) or command group (gh) MUST contain
these sections, in this order, as `##` headings:

```markdown
# <command>

One-sentence statement of what this command is for.

## Mental model

What is really happening underneath — the concept a reader needs before the
mechanics. Beginner-friendly.

## Synopsis

The syntax forms, in a code block.

## Everyday usage

The 80% recipes — the handful of invocations people actually use daily.

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--flag` | ... | ... |

## Best practices

The correct way to use this command, each with the *why*.

## Pitfalls & gotchas

What bites people, and how to recognize it.

## Worked examples

Two or more realistic, end-to-end scenarios with commands (and output where
instructive).

## Recovery

How to undo or back out. Link to the relevant entry in *Getting out of jams*.

## See also

Bulleted cross-references to related chapters.
```

## Troubleshooting chapter template

The `90-troubleshooting.md` chapter ("Getting out of jams") is organized by
**symptom**, not command. One H1 for the chapter; each jam is a `##` entry:

```markdown
## <symptom or error message>

**What it means.** ...

**Why it happens.** ...

**How to get out.** Numbered, copy-pasteable steps.

**How to avoid it.** ...
```

## Intro chapter template

Intro/foundation chapters are narrative and beginner-first. One H1; `##`
sections as the topic needs. No fixed section list, but keep the same voice.
