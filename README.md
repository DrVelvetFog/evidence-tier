# ev — evidence tiers for agent claims

A five-word label for **how an agent knows something** — `ran` · `read` · `told` · `recalled` · `inferred` — bound to the output by digest, carried as a standard in-toto Statement, checkable offline. See [SPEC.md](SPEC.md).

```bash
./test.sh                                              # 15 checks
./ev digest report.md                                  # sha256 for subject / artifact digests
./ev verify report.evidence.json --subject report.md   # per-claim declared vs effective tier
```

Rules in one breath: the tier names the *check*, not the confidence (R1); evidence binds by digest (R2); unresolvable evidence **downgrades to `told`** rather than failing (R3); an inference is as strong as its weakest premise (R4); the record binds to the subject and *that* mismatch is the one hard FAIL (R5); un-annotated prose has no tier — never read `ran` from tone (R7).

`ran` claims resolve against [rv](../reversible/) journals (`rv:<repo>#<seq>` + output digest). Worked example in `examples/` is real: six claims from the rv v0 report, one of which is honestly downgraded because it ran before journaling existed.

Carriers: sidecar JSON (here) · [OKF bundle frontmatter](OKF.md) (`sources[].evidence`) · MCP tool-result `_meta` · a chat `Evidence:` footer for humans.
