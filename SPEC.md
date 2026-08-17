# Evidence Tiers

**Status:** draft `v0` · working name `ev`
**Purpose:** give every claim an agent makes a small, portable label saying **how it is known** — executed, read, told, recalled, or inferred — bound to the output by digest, so a reader or a downstream agent can check the claim instead of trusting the tone it was written in.

Third of a set. [Change-Evidence Binding](../change-evidence/SPEC.md) binds a *change* to proof it was reviewed; [Reversible Actions](../reversible/SPEC.md) binds an *action* to proof of what it did. This binds a *claim* to proof of how it was known. All three share one rule: say which fields are recomputed and which are asserted.

---

## 1. The gap this closes

Confidently-wrong is the industry's central failure mode, and it is not mostly a model-quality problem. It is a *format* problem: an agent's output has one register. "The tests pass" reads the same whether the agent ran the tests, read a CI badge, was told by another agent, or remembers that tests usually pass. The consumer — human or agent — cannot tell, so every sentence is silently promoted to the strongest tier.

Prior art is real but sits elsewhere. W3C PROV-DM gives a general vocabulary (entity / activity / agent) but no per-claim producer-side format; the June 2026 evidence-tracing survey names "unified and interoperable trace schemas" as the open problem. Verification systems (ProvenanceGuard and kin) score frozen traces *after the fact* and publish no schema. MCP annotates tool *definitions* (`readOnlyHint` …), not results, and the 2026-07-28 release candidate ships nothing on the result side. Supply-chain attestation (in-toto / DSSE / Sigstore) has exactly the right *envelope* — a statement about a subject identified by digest — and no predicate for this.

So the design is: a five-word vocabulary, one rule for what each word obligates a verifier to do, and reuse of the in-toto Statement so it signs and ships through infrastructure that already exists.

## 2. Terminology

| Term | Meaning |
|---|---|
| **claim** | One checkable proposition in an agent's output. |
| **tier** | How the producer knows the claim: `ran` · `read` · `told` · `recalled` · `inferred`. |
| **evidence** | The thing a verifier resolves to check the claim: an action record, an artifact by digest, or a party. |
| **subject** | The output (text, file, tool result) the claims are about, identified by digest. |
| **declared / effective tier** | What the producer wrote vs what a verifier could actually resolve. |

## 3. The tiers

Ordered by **what a verifier can do**, not by how likely the claim is true.

| Tier | Meaning | Evidence REQUIRED | What a verifier does |
|---|---|---|---|
| `ran` | The producer executed something and observed the result | ≥1 `action` (journaled action, CI run, tool call) with a digest of its output or effect | Resolve the action; compare digests; optionally re-run |
| `read` | The producer read it in an artifact it can point to | ≥1 `artifact` with `uri` + `digest`, optionally a `span` | Fetch/open the artifact; check the digest; check the span supports the text |
| `told` | Another party asserted it (user, tool, other agent, API) | ≥1 `party` (`who`, `at`) | Nothing to recompute; can ask the party |
| `recalled` | From the producer's own memory / training | none — MUST be empty | Nothing; independent verification only |
| `inferred` | Derived from other claims in this record | `derived_from` ≥1 claim id; evidence MUST be empty | Effective tier = the **weakest** premise |

Ranking for "weakest": `ran` > `read` > `told` > `recalled`.

## 4. Design rules

**R1 — The tier names the check, not the confidence.** `ran` means "you can resolve the action"; it does not mean "probably true." An optional `confidence` field exists, is asserted, and is orthogonal. A consumer MUST NOT map tiers to probabilities.

**R2 — Bind evidence to content by digest.** A `read` whose artifact has no digest is not a `read`; it is a `told` by the producer. Same for a `ran` whose action record has no output/effect digest.

**R3 — Unresolvable evidence downgrades; it does not fail.** A verifier computes an *effective* tier: `ran`/`read` evidence that cannot be resolved, or whose digest mismatches, makes the claim `told` (by the producer, at record time). Both tiers are reported. Tier inflation therefore becomes a measurable quantity per producer instead of a silent failure.

**R4 — Inference is as strong as its weakest premise.** `inferred` claims carry `derived_from`; effective tier is the minimum over premises' effective tiers. A cycle or a dangling reference is `told`. (The analogue of Change-Evidence R7: coverage is contingent.)

**R5 — Claims are bound to a subject.** The record is an in-toto Statement whose `subject` is the digest of the output the claims annotate. Claims cannot be lifted onto a different output, and a subject mismatch is a hard `FAIL` — the one place the verifier fails rather than downgrades.

**R6 — Separate recomputed from asserted.** `text`, `producer`, `confidence`, declared `tier` are asserted. Digest matches, resolution results, and effective tiers are recomputed. Verifier output MUST label them.

**R7 — Absence is not a claim.** Un-annotated text has no tier. A consumer MUST NOT infer `ran` from assertive prose. This is the rule the whole spec exists to make expressible.

## 5. The record

A valid [in-toto Statement v1](examples/in-toto-statement-v1.md) with this predicate. Sign it with DSSE / Sigstore exactly as any other attestation; nothing here is bespoke.

```jsonc
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [{ "name": "report.md", "digest": { "sha256": "…" } }],   // the output being annotated
  "predicateType": "https://github.com/DrVelvetFog/evidence-tier/v0",
  "predicate": {
    "producer": { "kind": "agent", "tool": "claude-code", "model": "…", "session": "…" },   // ASSERTED
    "claims": [
      { "id": "c1", "text": "rv test.sh passes 15/15",
        "tier": "ran",
        "evidence": [{ "kind": "action", "ref": "rv:/path/to/repo#5",
                       "digest": { "sha256": "<output digest>" } }] },
      { "id": "c2", "text": "in-toto Statement subjects MUST have a digest",
        "tier": "read",
        "evidence": [{ "kind": "artifact", "uri": "file:examples/in-toto-statement-v1.md",
                       "digest": { "sha256": "…" }, "span": { "lines": [15, 15] } }] },
      { "id": "c3", "text": "agent-rewind has 0 stars",
        "tier": "told",
        "evidence": [{ "kind": "party", "who": "tool:gh-api", "at": "2026-08-17T13:58:00Z" }] },
      { "id": "c4", "text": "W3C PROV-DM models entity, activity, agent",
        "tier": "recalled", "evidence": [] },
      { "id": "c5", "text": "the open standards slot is the mechanism, not a boolean hint",
        "tier": "inferred", "derived_from": ["c2", "c3"], "evidence": [],
        "confidence": 0.8 }                                             // OPTIONAL, ASSERTED
    ]
  }
}
```

### Evidence descriptors

| kind | fields | resolves via |
|---|---|---|
| `action` | `ref` (e.g. `rv:<repo-root>#<seq>`, a CI run URL), `digest` of output or effect | the action journal / CI API |
| `artifact` | `uri`, `digest`, optional `span` (`{"lines":[a,b]}` or `{"bytes":[a,b]}`) | open the artifact, hash, slice |
| `party` | `who` (`user`, `agent:<name>`, `tool:<name>`), `at` | nothing recomputable |

## 6. Verification

Input: the Statement, the subject (or its digest), and read access to whatever the evidence points at. Offline; no vendor.

1. **Subject binding** — hash the subject; mismatch → `FAIL`. (R5)
2. **Shape** — each claim's evidence matches its tier's requirement (§3); a violation downgrades the *declared* tier to what the evidence actually supports (a `ran` with no action → `told`).
3. **Resolve** — for each `action` / `artifact`, resolve the ref and compare digests; if a `span` is given, report the slice so a human can judge support. Any miss → effective `told`. (R3)
4. **Inference** — effective tier of `inferred` = min over premises; cycles/dangling → `told`. (R4)
5. **Report** — per claim: `declared`, `effective`, reason. Summary: count of downgrades (the producer's *inflation*), and `VERIFIED` (subject bound, all evidence resolved) or `UNVERIFIED (n downgraded)`.

## 7. Carriers

- **Sidecar** — `<output>.evidence.json` next to any file; the reference implementation.
- **MCP tool results** — the predicate alone in `_meta["io.github.drvelvetfog.evidence-tier/v0"]`, subject implied (the result's content). This follows the precedent SEP-414 set for trace context in `_meta`, and is the natural home for the "annotations on tool responses" the Tool Annotations IG is discussing.
- **Chat display** — a convention, not the record: a short `Evidence` footer listing claim → tier, or inline markers `⟨ran⟩ ⟨read⟩ ⟨told⟩ ⟨recalled⟩`. Display MAY drop evidence descriptors; the record MUST NOT.

## 8. Relationship to the other two specs

`rv` records are the canonical `action` evidence: `ran` claims resolve to a journal seq whose output digest and pre/post trees are recomputable. Change-Evidence records are `artifact` evidence for claims about review coverage. And this spec's `recalled` tier is where the honest floor lives: an agent that says "I recall" instead of "it is" has already done most of the work.

## 9. Non-goals

- Not a truth oracle. It says how a claim is known and how to check it; it does not say whether it is right.
- Not a full provenance graph. PROV-DM / OpenTelemetry can carry the whole trace; this is the per-claim projection a reader needs at the point of use, and it maps onto PROV (`ran` ≈ `wasGeneratedBy` an Activity; `read` ≈ `wasDerivedFrom` an Entity; `told` ≈ `wasAttributedTo` an Agent) if someone wants the graph.
- Not confidence scoring. See R1.
