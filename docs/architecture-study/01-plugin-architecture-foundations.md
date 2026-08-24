# Part 1 — Plugin Architecture Foundations

> The ten concepts below are the vocabulary. Every mature plugin system is a
> different remix of the same ten ideas. Learn them once here, then recognize
> them everywhere.

---

## 1. Inversion of Control (the host never calls you by name)

**Concept.** In a naive system, the core knows its extensions: `if (type == X) call TopErrors()`.
Inversion of control flips it: the core only knows an _abstraction_ (interface +
registry). Extensions announce themselves; the core discovers and invokes them
through the abstraction. Dependency arrows point inward, always.

**In IEF.** `IntegrationLogHandler` does not know the Calendar plugin exists. It asks
the registry for SERVICE-type configs and calls `execute()` on whatever implements
`IHD_ServicePlugin` (`force-app/integration-logs-framework/classes/IntegrationLogHandler.cls`).
The plugin knows the core contract; the core knows no plugin. This asymmetry is
the whole architecture.

**Why it matters.** You can delete any plugin without touching the core. You can
ship a new plugin without releasing the core. That is what makes the core
"stable" and the ecosystem "alive".

---

## 2. The registry: discovery without imports

**Concept.** Something must answer "which plugins exist?" _before_ any plugin code
runs. Mature systems use a static, declarative source: VS Code reads `package.json`
contribution points, esbuild reads hook registrations, dsh/Cordis keeps a service
table keyed by name. The registry must be readable with **zero plugin code loaded**.

**In IEF.** `IHD_Plugin__mdt` custom metadata is our contribution-point manifest:
`PluginType__c`, `ApexClassName__c`, `LwcComponentName__c`, `Enabled__c`,
`DisplayOrder__c`, `CardLocation__c`, `Grid_Span__c`. The Apex side resolves rows
via one SOQL + transaction-scoped cache (`IHD_PluginRegistry.getConfigs`),
instantiating lazily through `Type.forName(...).newInstance()`.

**Key insight.** Custom metadata is Salesforce's superpower here: it's the same
mechanism VS Code uses (static declaration), but admin-editable at runtime —
something none of the web-ecosystem frameworks can do.

---

## 3. A seam needs THREE roles

**Concept.** From the Cordis/dsh work: an extension seam is not an interface.
It's **definition + provider(s) + consumer(s)**. An interface with zero real
implementations is speculative surface; an interface whose only consumer is its
own test is a dead end. "One role alone is not a seam."

**In IEF.** This is our biggest live lesson:

- `IHD_CardPlugin.getData` has a definition and consumers in core — but every
  shipped card sets `ApexClassName__c='N/A'`, so there are **zero real providers**.
  Half-built seam.
- `IHD_TriggerPlugin` has definition (interface), providers, and real consumers
  (`IHD_SObjectHandler`). Complete seam. Notice how much more confidence you have
  in that code path.

**Rule to internalize.** Never ship a new contract without shipping a reference
provider and wiring a real consumer in the same change.

---

## 4. Declare statically, execute lazily

**Concept.** Registration data should be enough for the host to _display and route_
without executing plugin logic. Execution cost is paid on first relevant use
(VS Code activation events; `onView:` fires when the view opens, not at boot).

**In IEF.** Apex half is naturally lazy (`Type.forName` at first use).
The LWC half is **not**: cards render via eager module-scope registration — each
plugin shell component self-registers its constructor into a shared `Map`
(`iefDynamicLoader.registerCard`) when placed on the page. There is no dynamic
`import()` anywhere. Composition works, but nothing defers cost.

**Tradeoff to own.** On Lightning pages, components load as the page loads.
True lazy loading of LWC is possible via dynamic `import()` in LDS, with real
constraints. Whether we pay that price is a decision for Part 04.

---

## 5. Failure containment: a broken plugin must never break the host

**Concept.** go-plugin runs plugins in subprocesses ("plugins can't crash your
host"). Figma sandboxes them in QuickJS. The platform-independent residue:
the host wraps every plugin invocation, catches everything, degrades visibly,
and continues.

**In IEF.** Apex has no process isolation — the platform IS the sandbox (sharing,
permissions, governor limits). What we can do is invocation-level containment,
and we already do it right in places: `IHD_SObjectHandler.execute` try/catches per
plugin instance; `IntegrationLogHandler.callServicePlugins` isolates before/after
hooks. Where we don't: LWC card rendering and some controller paths.

**dsh cautionary tale.** DeepSeek Harness shipped "no privileged core" but a bad
plugin entry bricked entire boots (Discussion #1496) because validation was absent.
Our design instinct — fail soft, log a FRAMEWORK_INTERNAL event, keep rendering —
is the correct antidote. Make it universal, not incidental.

---

## 6. Contract versioning & negotiation

**Concept.** Three version numbers exist in any plugin system: framework release,
plugin release, and **contract version** (the shape of the interface/payload).
Mature systems version the contract explicitly and negotiate or fail loudly:
go-plugin's handshake carries CORE-PROTOCOL-VERSION and APP-PROTOCOL-VERSION;
Obsidian ships a `versions.json` compatibility matrix; VS Code has `engines.vscode`.

**In IEF.** No contract version anywhere. Plugin packages pin a core dependency
(`04tak000000PWkfAAG` = core 1.4.2-1) while core develops toward 1.5.0 — pins lag
silently. An LMS payload field renamed today breaks plugins at runtime with no
diagnostic.

**Rule.** Version the contract separately from releases; make mismatch produce a
loud, human-readable failure (a skipped plugin + logged reason), never silent
misbehavior.

---

## 7. Extend backward-compatibly, or don't extend

**Concept.** go-plugin added gRPC support by _suffixing_ the handshake instead of
bumping the protocol version — explicitly to avoid breaking existing consumers.
New optional request/response fields < new optional methods < new protocols, in
order of breaking severity.

**In IEF.** Our LMS channels are young contracts. Every future action added to
`IEF_Plugin_Actions` should be additive; handlers must ignore unknown actions and
unknown payload fields gracefully — which is also what makes C4-class bugs
(severity card sends `observationType`, dashboard ignores it) survivable instead
of fatal.

---

## 8. Events and dispatch semantics

**Concept.** Cordis gives every event an explicit dispatch mode: `emit` (observe),
`waterfall` (sequential middleware, short-circuitable), `parallel`, `serial`.
The mode is part of the public contract. Most homegrown systems have exactly one
implicit mode and chaos where they needed four.

**In IEF.** `IEF_Plugin_Actions` currently means "fire and hope": producers publish,
dashboard switches on `action`. No ordering, no interception, no acknowledgment.
We don't need Cordis's full machinery, but classifying actions (observe vs mutate
vs navigate-intent) with defined semantics costs little and prevents drift.

---

## 9. Capability models and negative space

**Concept.** Figma declares what plugins _cannot_ do as rigorously as what they
can (no network outside allow-listed domains, no execution when not running).
Permissions belong in the registration record — auditable and enforced by the
host — not buried in plugin behavior.

**In IEF.** `IHD_Plugin__mdt` has enable/order/location but no capability surface.
Today trust is implicit: any plugin could publish any LMS action. Negative space
to define: can a plugin reconfigure other plugins? write logs? filter other
cards' data? Decide explicitly, encode as CMDT fields the host enforces centrally.

---

## 10. Revertible composition & honest configuration

**Concept.** Cordis registrations return disposers; unload unwinds in reverse
order (their paper proves final state is independent of load/unload history).
dsh composes config in declared layers and prints the effective tree
(`--dump-config`) — making "what is actually configured?" answerable.

**In IEF.** Apex can't hot-unload, so runtime revertibility doesn't transfer —
but two residues do: (a) every registry row needs defined removal semantics
(uninstalling a package must leave no orphaned rows breaking boot), and (b) we
need an "effective composition" view: which rows resolved, in what order, which
failed to instantiate and why. Today instantiation failures vanish into a debug
log (`IHD_PluginRegistry.getInstance`). That's the opposite of introspectable.

---

## Self-test (answer against the code, not memory)

1. Trace one TRIGGER plugin from metadata row to invocation. Which class owns the
   try/catch, and what happens to the business transaction if the plugin throws?
2. Why does `ApexClassName__c='N/A'` exist? What seam role is missing that makes
   it necessary?
3. If a plugin package pins core 1.4.2 and core renames an LMS payload field in
   1.5, what does the user see? What _should_ they see?
4. Name one place where IEF violates "declare statically, execute lazily" and one
   where it honors it perfectly.
5. What would you add to `IHD_Plugin__mdt` to implement capability enforcement,
   and which class becomes the enforcer?
