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

echo; echo "pass=$pass fail=$fail"
[ $fail -eq 0 ]
