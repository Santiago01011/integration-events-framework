# Part 2 — Industry Benchmark

> How the systems that got this right solve each foundation concept, and what
> their failures teach us. Distilled from primary sources; URLs inline for depth.

---

## DeepSeek Harness (`dsh`) + Cordis — "everything is a plugin"

Verified facts: open-sourced 2026-08-13 (MIT), built on **Cordis**, an independent
TypeScript plugin meta-framework battle-tested since ~2019 in the Koishi ecosystem
— dsh vendors it to own its framework layer. Developer preview, explicitly
breaking-changes-will-happen.

**Decisions worth stealing:**

| Decision                         | Mechanism                                                                          | IEF translation                                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Service registry by stable key   | Plugins claim `ctx.<key>` slots; discovery by key, never by import                 | Our CMDT registry is the analog; keep keys stable and documented as contract                     |
| Declared dependencies (`inject`) | Plugin names required services; runtime mounts only when satisfiable; fails loudly | Registry rows should declare required contract version; CI validates resolvability               |
| Revertible effects               | Every registration returns a disposer; unload unwinds in reverse order             | Apex can't hot-unload → transferable residue: defined upgrade/removal semantics per registry row |
| Three-role seams                 | Definition + providers + consumers, or it isn't a seam                             | Ship every interface with a reference provider AND real consumer                                 |
| Typed events with dispatch modes | `emit` / `waterfall` / `parallel` / `serial`, mode is contract                     | Classify LMS actions with explicit semantics instead of one implicit mode                        |
| Effective-config introspection   | `--dump-config` prints resolved composition tree                                   | Debug view of resolved registry rows + resolution order + instantiation failures                 |

**Their verified failure modes (worth more than their features):**

1. **Shared-process fragility** — duplicate loader IDs bricked boot (#1404); pnpm
   creating two module instances made symbol-keyed registries mismatch → total tool
   failure after a _routine plugin install_ (#1486); non-idempotent singletons threw
   on double mount (#1415). Root cause: no validation, no degradation, no diagnostics.
   → _Our invariant: one broken plugin degrades to one logged error. Always._
2. **Hidden privileged surfaces leak back** — a hardcoded namespace allowlist in the
   web API proxy made third-party plugins second-class (#903). "No privileged core"
   erodes quietly at wire boundaries.
   → _Audit our own privileged paths: hardcoded type strings in `IHD_PluginRegistry.getActivePluginNames`, sentinel `'N/A'` parsing._
3. **"Everything is a plugin" has a user cost** — end users wanted zero-config
   defaults; layered profiles/bundles/patches pushed assembly onto them (#326).
   → _Ship curated defaults. Admin configures exceptions, not basics._

Sources: [architecture.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md) · [cordis-primer](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/cordis-primer.md) · [Cordis paper](https://github.com/cordiverse/paper) · [Discussion #1496](https://github.com/deepseek-ai/deepseek-harness/discussions/1496)

---

## VS Code — declarative contribution points + lazy activation

- **Static-first**: commands/menus/views declared in manifest JSON; host renders
  them without loading extension code. Activation fires on use (`onView:`,
  `onCommand:`), `*` (boot activation) officially discouraged.
- **Contract floor**: `engines.vscode` semver checked at install. Unstable ideas go
  through **proposed API** — opt-in, unpublished, allowed to break, graduated only
  after third-party exercise.
- **Implicit activation generation**: infers activation from contributions,
  eliminating a class of declaration bugs.

→ IEF mapping: `IHD_Plugin__mdt` rows = contributes; card rendering = activation.
What we lack: any proposed-API-style tier for experimenting with contracts without
committing all downstream packages to them.

Source: [Activation Events](https://code.visualstudio.com/api/references/activation-events)

---

## Figma — sandbox swap proved the value of narrow contracts

- Dual-context: logic in QuickJS-WASM sandbox with no browser APIs; UI in iframe;
  **message passing is the entire contract**.
- Swapped Realms → QuickJS in weeks **without changing the plugin API**, because
  the seam was narrow messages, not shared objects.
- Explicit allow-list permissions (`networkAccess.allowedDomains`) with required
  justification for wildcards.

→ IEF mapping: our LMS payload schema is exactly this kind of narrow contract —
treat its stability like Figma treats theirs. The platform provides the sandbox;
our job is honest documentation of what isolation plugins actually get.

Source: [Figma blog](https://www.figma.com/blog/an-update-on-plugin-security/)

---

## HashiCorp go-plugin — handshake & dual version numbers

- Subprocess + gRPC over local socket; "plugins can't crash your host process".
- Handshake carries **two versions**: framework protocol and application protocol;
  mismatched core protocol ⇒ loud refusal, not weird behavior.
- `VersionedPlugins map[int]PluginSet`: host and plugin negotiate highest mutually
  supported contract at connect time.
- Contract ships as separate SDK package — plugin authors never depend on host
  implementation.
- Health checking mandatory; wedged plugins are detected, restarted, or dropped.

→ IEF mapping: Salesforce's dependency pinning ≈ install-time check, but nothing
negotiates at _runtime_. A `Contract_Version__c` on registry rows + loud skip-on-
mismatch is the faithful adaptation. The "contract-only package" idea maps to a
tiny interfaces+constants package both sides depend on — worth serious consideration
for v2 of the packaging model.

Source: [internals.md](https://github.com/hashicorp/go-plugin/blob/main/docs/internals.md)

---

## esbuild — minimalism as a feature

- Exactly two hooks (`onResolve`, `onLoad`) served years of growth. Every extra
  extension point is permanent contract debt.
- Chain-of-responsibility with fall-through: return `undefined` = "not mine",
  pass to next; first non-undefined wins. Ordering documented ("specific first,
  catch-alls last").
- Host pre-filters invocations cheaply before crossing into plugin code —
  performance budget enforced architecturally.

→ IEF mapping: resist contract growth. `IHD_ServicePlugin.beforeProcess/
afterProcess` and `IHD_FieldPlugin` exist today with **zero production
implementations** — speculative surface that violates the two-hook discipline.

Source: [esbuild plugins](https://esbuild.github.io/plugins/)

---

## Obsidian — thin manifests and graceful degradation

- Manifest nearly trivial: id/version/minAppVersion/isDesktopOnly.
- `versions.json` matrix: old app installs newest _compatible_ plugin build rather
  than failing — degradation across an app×plugin version grid.
- Normative anti-pattern list shipped as part of the contract (no default hotkeys,
  no held view references, CSS vars not hardcoded styles).

→ IEF mapping: we need the written anti-pattern list equivalent for plugin authors
(don't query other plugins' data directly, don't publish unregistered LMS actions,
don't hardcode core object names...). Docs-as-contract.

Source: [Plugin guidelines](https://docs.obsidian.md/Plugins/Releasing/Plugin+guidelines)

---

## The synthesis table

| Concept                   | dsh/Cordis             | VS Code                      | go-plugin              | esbuild            | IEF today          |
| ------------------------- | ---------------------- | ---------------------------- | ---------------------- | ------------------ | ------------------ |
| Discovery                 | service table          | manifest                     | handshake              | registration order | CMDT ✅            |
| Lazy execution            | mount on demand        | activation events            | subprocess launch      | hook invocation    | Apex ✅ / LWC ❌   |
| Contract versioning       | pinned vendor + inject | engines floor + proposed API | dual protocol versions | none (one product) | ❌ none            |
| Failure containment       | weak (their #1 pain)   | extension host process       | subprocess isolation   | n/a                | partial ✅/❌      |
| Capability model          | sandbox seams          | proposed API gating          | n/a                    | namespaces         | ❌ none            |
| Composition introspection | --dump-config          | n/a                          | logs                   | --analyze          | ❌ debug logs only |
