# Architecture Study Track — Owning the Integration Events Framework

> Purpose: not to hand you a finished design, but to make you the person who can
> defend every seam in this framework — to a client, an architect panel, or yourself.
> Every concept here is anchored to real code in this repo so you can verify,
> break, and rebuild it.

## Why this exists

IEF already made a bet most frameworks make too late: **the host stays minimal,
plugins carry the product**. That bet aged extremely well — the industry moved
toward exactly this shape (DeepSeek Harness, VS Code, Terraform plugins). Before
we redesign anything, you need fluency in the underlying concepts, because the
next iteration's decisions are concept decisions, not code decisions.

## Reading order

Read in sequence. Each part ends with self-test questions — if you can't answer
them against the actual code, re-read with the file open.

| Part                                                      | What you learn                                                                  | Prerequisite |
| --------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------ |
| [01 — Foundations](01-plugin-architecture-foundations.md) | The 10 concepts every plugin system is built from                               | None         |
| [02 — Industry benchmark](02-industry-benchmark.md)       | How dsh/Cordis, VS Code, Figma, go-plugin, esbuild, Obsidian solve them         | 01           |
| [03 — IEF today](03-ieftoday.md)                          | Our implementation mapped against those concepts: strengths, debt, divergences  | 01, 02       |
| [04 — Decision backlog](04-decision-backlog.md)           | Candidate decisions for the next iteration, each with tradeoffs — none pre-made | 03           |

## Primary sources worth reading in full

Shortlist, highest value first:

1. **Cordis paper** — _A Programming Paradigm for Spatiotemporal Composability_
   <https://github.com/cordiverse/paper> — the theory underneath DeepSeek Harness:
   services keyed by name, dependency injection, revertible effects. Dense but short.
2. **go-plugin internals** — <https://github.com/hashicorp/go-plugin/blob/main/docs/internals.md>
   — handshake + dual protocol versioning, the cleanest treatment of contract
   versioning anywhere.
3. **VS Code Activation Events** — <https://code.visualstudio.com/api/references/activation-events>
   — the canonical "declare statically, execute lazily" model.
4. **Figma plugin security** — <https://www.figma.com/blog/an-update-on-plugin-security/>
   — why narrow message-passing contracts let them swap their entire sandbox
   without touching the plugin API.
5. **DeepSeek Harness architecture doc** — <https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md>
   — "everything is a plugin" done at industrial scale, including its failures
   (read Discussion #1496 after: one bad plugin bricking boot is the cautionary tale).
6. **esbuild plugins** — <https://esbuild.github.io/plugins/> — two hooks,
   fall-through semantics, minimalism as a feature.

## How to study with the repo

- Open the referenced files side by side (`file:line` references throughout).
- Break things on purpose: disable a CMDT plugin row, rename a channel field,
  throw from a plugin class — observe containment (or lack of it).
- The `park/agentforce-plugin` branch holds unfinished work; ignore it during
  study, it will be migrated slice-by-slice later under the new rules.
