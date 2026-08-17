# Evidence tiers in OKF bundles

[Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) (v0.2, Google Cloud, Apache-2.0) is the emerging portable format for agent knowledge and memory: a directory of markdown + YAML frontmatter, with `sources` (provenance), `generated` (who wrote), `verified` (who confirmed → unverified / machine-confirmed / human-reviewed), `status`, `stale_after`, and per-claim footnote attribution keyed to `sources[].id`. It is the right place for portable memory to live; this project does not define a competing format.

What OKF's trust model does not carry is *how the writer knew* — its tiers key off who **verified** (`human:` vs machine), not whether the producer **ran** something, **read** a source, was **told**, or **recalled** it. Two claims both `generated.by: some_agent/x` and both machine-verified read the same whether one came from an executed check and the other from the model's memory. That axis is orthogonal to OKF's and is what this spec adds.

## Carrier: `sources[].evidence` + `generated.evidence`

Additive, uses OKF §4.1's "producers MAY include any additional keys", and follows OKF §5.1's rule of recording objective signals rather than scores.

```yaml
type: Note
title: wait_t units
generated: { by: hermes/claude-fable-5, at: 2026-08-17T15:00:00Z, evidence: inferred }
sources:
  - id: sim-run
    resource: references/wait_t-repro.log
    evidence: ran            # producer executed and observed the result
    digest: sha256:9b3ab…    # optional; makes the claim checkable
  - id: lang-ref
    resource: https://vendor.example/lang-ref#4.2
    evidence: read           # producer read it in this artifact
    last_modified: 2026-05-30
  - id: vendor-support
    resource: "email from vendor support, 2026-07-01"
    evidence: told           # asserted by a party; nothing to recompute
```

- `sources[].evidence` ∈ `ran` · `read` · `told` — how the producer touched *this* source. Per-claim granularity comes for free through OKF's footnote join (`[^sim-run]`).
- `generated.evidence` — the concept's overall basis when it is not carried by a source: `recalled` (from the model's own memory; no source) or `inferred` (derived from the cited sources; effective tier = weakest cited source, Evidence-Tier R4).
- Absence carries meaning, as everywhere in OKF: no `evidence` key ⇒ unknown, which consumers SHOULD read as `told` by the producer (Evidence-Tier R7 — never infer `ran` from tone).

## Why a tier and not a confidence float

OKF §5.1 declines to store a credibility score because it is subjective, unportable across consumers, and stale on arrival. A confidence float (proposed in knowledge-catalog #151/#160) has the same problems. An evidence tier does not: it names *what a verifier can do* — resolve the run, re-open the artifact, ask the party, or nothing — which is objective, portable, and does not decay. Confidence, if wanted, stays a separate asserted field (Evidence-Tier R1).

## Mapping to the Evidence-Tier record

An OKF concept with `sources[].evidence` is losslessly expressible as an Evidence-Tier Statement: subject = the concept file by digest; one claim per footnoted sentence (or one per concept); `ran` sources → `action` evidence, `read` sources → `artifact` evidence (`uri` = `resource`, `digest` if present), `told` sources → `party`. `ev verify` then computes effective tiers exactly as for any other Statement.

## Memory that is yours and portable — the practical answer

- Store memory as an OKF bundle (or anything that exports one; several Claude Code exporters and consumers exist: `okf-skills` ★312, `mcp-memory` ★179, `Vault-Agent-Memory`, `hermes-okf`).
- Give each memory `generated: { by, at, evidence }` and `sources[].evidence`. That is the whole delta between "an agent's notes" and "notes a stranger can weigh."
- Supersession: use the typed relationship edges proposed in knowledge-catalog #195 (`supersedes`) rather than inventing a field here.
