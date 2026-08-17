#!/usr/bin/env bash
# ev tests: effective tiers, downgrade on unresolvable/mismatched evidence, subject binding, inference.
set -uo pipefail
cd "$(dirname "$0")"
pass=0; fail=0
ok(){ echo "  ok   $1"; pass=$((pass+1)); }
no(){ echo "  FAIL $1"; fail=$((fail+1)); }
E=examples/rv-report.evidence.json
run(){ ./ev verify "$@" 2>&1; }

echo "1. baseline example (real claims, one honestly unjournaled)"
OUT=$(run $E --subject examples/report.md)
echo "$OUT" | grep -q '^subject: OK' && ok "subject bound" || no "subject"
echo "$OUT" | grep -q '^c1   ran       ran ' && ok "c1 ran resolves against live rv journal (cross-spec)" || no "c1"
echo "$OUT" | grep -q '^c2   ran       told       v' && ok "c2 unresolvable ran -> told (R3)" || no "c2"
echo "$OUT" | grep -q '^c3   read      read ' && echo "$OUT" | grep -q 'span L15-15' && ok "c3 read resolves w/ span" || no "c3"
echo "$OUT" | grep -q '^c5   recalled  recalled' && ok "c5 recalled stays recalled" || no "c5"
echo "$OUT" | grep -q '^c6   inferred  told ' && ok "c6 inferred = weakest premise (R4)" || no "c6"
echo "$OUT" | grep -q 'UNVERIFIED (1 downgraded)' && ok "summary counts inflation" || no "summary"

echo "2. tampered artifact -> read downgrades"
T=$(mktemp -d); cp -r examples/. "$T"/; echo tamper >> "$T/in-toto-statement-v1.md"
OUT=$(run "$T/rv-report.evidence.json" --subject "$T/report.md")
echo "$OUT" | grep -q '^c3   read      told       v' && echo "$OUT" | grep -q '(2 downgraded)' && ok "c3 -> told, 2 downgraded" || { no "tamper artifact"; echo "$OUT"; }
echo "$OUT" | grep -q '^c6   inferred  told ' && ok "c6 still told" || no "c6 after tamper"

echo "3. tampered subject -> hard FAIL, exit 1"
echo "edited" >> "$T/report.md"
run "$T/rv-report.evidence.json" --subject "$T/report.md" >/tmp/ev.out; rc=$?
grep -q 'subject: FAIL' /tmp/ev.out && [ $rc -eq 1 ] && ok "subject mismatch fails (R5)" || no "subject fail rc=$rc"

echo "4. --strict exits 1 on any downgrade; default exits 0"
run $E --subject examples/report.md --strict >/dev/null; [ $? -eq 1 ] && ok "strict" || no "strict"
run $E --subject examples/report.md >/dev/null; [ $? -eq 0 ] && ok "lenient" || no "lenient"

echo "5. shape rules: ran without action evidence -> told; inferred cycle -> told; digestless read -> told"
python3 - <<'EOF' > "$T/shape.json"
import json
print(json.dumps({"_type":"https://in-toto.io/Statement/v1","subject":[{"name":"_","digest":{"sha256":"0"*64}}],
 "predicateType":"https://github.com/DrVelvetFog/evidence-tier/v0","predicate":{"claims":[
  {"id":"a","text":"x","tier":"ran","evidence":[]},
  {"id":"b","text":"y","tier":"inferred","derived_from":["c"],"evidence":[]},
  {"id":"c","text":"z","tier":"inferred","derived_from":["b"],"evidence":[]},
  {"id":"d","text":"w","tier":"read","evidence":[{"kind":"artifact","uri":"file:report.md"}]}]}}))
EOF
OUT=$(run "$T/shape.json")
echo "$OUT" | grep -q '^a    ran       told ' && ok "ran w/o action -> told (R2)" || no "shape a"
echo "$OUT" | grep -q '^b    inferred  told ' && echo "$OUT" | grep -q '^c    inferred  told ' && ok "cycle -> told" || no "cycle"
echo "$OUT" | grep -q '^d    read      told ' && ok "digestless read -> told (R2)" || no "shape d"

echo "6. xv: attested example resolves as ran; wrong digest -> told"
mkdir -p "$T/xv"; printf 'echo hi\n' > "$T/xv/ex.sh"
python3 - "$T" <<'PY'
import json,sys,hashlib
T=sys.argv[1]; out="hi\n"; d=hashlib.sha256(out.encode()).hexdigest()
json.dump({"schema":"verified-examples/v0","attestations":[{"_type":"https://in-toto.io/Statement/v1",
 "subject":[{"name":"ex.sh","digest":{"sha256":"x"}}],"predicateType":"https://github.com/DrVelvetFog/verified-examples/v0",
 "predicate":{"id":"ex","version":"1","exit":0,"stdout":{"sha256":d},"ran_at":"t"}}]}, open(f"{T}/xv/attest.json","w"))
json.dump({"_type":"https://in-toto.io/Statement/v1","subject":[{"name":"_","digest":{"sha256":"0"*64}}],
 "predicateType":"https://github.com/DrVelvetFog/evidence-tier/v0","predicate":{"claims":[
  {"id":"g","text":"ex prints hi","tier":"ran","evidence":[{"kind":"action","ref":f"xv:{T}/xv/attest.json#ex","digest":{"sha256":d}}]},
  {"id":"b","text":"ex prints hi (wrong digest)","tier":"ran","evidence":[{"kind":"action","ref":f"xv:{T}/xv/attest.json#ex","digest":{"sha256":"0"*64}}]}]}},
 open(f"{T}/xv/claims.json","w"))
PY
OUT=$(run "$T/xv/claims.json")
echo "$OUT" | grep -q '^g    ran       ran ' && ok "xv attestation resolves as ran" || no "xv ran"
echo "$OUT" | grep -q '^b    ran       told       v' && ok "xv digest mismatch -> told" || no "xv told"

echo; echo "pass=$pass fail=$fail"
[ $fail -eq 0 ]
