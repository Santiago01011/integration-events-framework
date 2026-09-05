# Part 4 — Decision Backlog (for the next iteration)

> No decisions pre-made. Each candidate: the question, the options, the tradeoffs.
> We pick together, one at a time, once Parts 01–03 are read.

## D1. What is the core, minimally?

The defining decision. Today core = contracts + registry + dashboard + emission
pipeline + **three plugins' worth of aggregate queries** (C1).

- **Option A — Pure host:** core keeps only interfaces, registry, emission,
  CallableIHD, and a _generic_ data endpoint. Severity/TopErrors/Trend logic moves
  into their plugin packages as real `IHD_CardPlugin` providers (fixes C1+C2
  simultaneously; completes the dead seam).
- **Option B — Host + reference implementation:** same move, but core also ships
  ONE reference card plugin proving the seam end-to-end (the three-role rule),
  while severity/toperrors become fully independent packages.
- **Tradeoff:** A is purer but leaves the seam unproven again; B costs one extra
  package to maintain. dsh's lesson: definition+provider+consumer or it's not a seam.

## D2. Contract versioning mechanism

- **Option A — CMDT field** `Contract_Version__c` + loud skip-on-mismatch with a
  logged reason visible in an admin panel.
- **Option B — Dependency pins only** (status quo), accepting silent lag.
- **Option C — Separate contract-only package** (interfaces + LMS payload
  constants) versioned independently; both core and plugins depend on it, never on
  each other's internals. go-plugin SDK pattern.
- Tradeoff: C is the cleanest long-term but changes packaging topology for all
  existing plugins. A is cheap and immediate. Not mutually exclusive: A now, C when
  plugin count grows.

## D3. LWC loading strategy

- **Option A — Status quo:** eager module-scope registration via shells on the page.
- **Option B — Dynamic `import()`** for card implementations (true lazy activation).
- **Tradeoff:** B matches VS Code semantics and cuts initial page cost, but dynamic
  imports inside Locker/Lightning have constraints and complicate the shell story.
  Measure first: how heavy are our cards actually? esbuild lesson — budget at the
  seam before optimizing it.

## D4. LMS action semantics

- **Option A — Document-only:** classify actions (observe / mutate / navigate-intent)
  in docs; handlers must ignore unknowns.
- **Option B — Registry-enforced:** allowed actions declared per plugin in CMDT;
  dashboard validates on receipt.
- Tradeoff: B prevents the C4 class of bug structurally but adds config burden;
  dsh's #903 warns privileged allowlists erode openness. Start with A + tests.

## D5. Capability model

Do we need Figma-style negative space (what plugins cannot do)? Candidates:
write logs directly vs through publisher; publish actions; filter other cards'
data. Options: doc-only normative list (Obsidian style) → later CMDT capability
fields enforced centrally. Recommend sequencing: list first, enforcement when
third-party authors exist.

## D6. Composition introspection

An "effective composition" view (dsh `--dump-config` analog): resolved rows,
order, instantiation failures surfaced instead of debug-logged. Cheap, high value
for admins, and it makes every other decision here _verifiable_ in the field.
Strong candidate for early in the iteration regardless of other choices.

## D7. Hygiene batch (non-negotiable, low controversy)

Dead code removal (`ihdTrendIndicator`, phantom fetches, gridSpan read, console.log),
placeholder label fix, filter-parameter alignment (C3), evaluation rules out of the
calendar package (C8), layout unification (C9), test gaps for boundary behavior
(missing/throwing/duplicate plugin), boilerplate dedup via shared core module (C7).

## Suggested sequencing (proposal, not verdict)

1. D7 hygiene + D6 introspection → trustworthy baseline.
2. D1 (the big move) → completes the Apex card seam.
3. D2A contract version + mismatch handling → protects everything built after.
4. D4/D5 documentation-tier → norms before enforcement.
5. Re-evaluate D3 with real performance data.
