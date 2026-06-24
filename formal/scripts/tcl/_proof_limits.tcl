# Bound focused proofs so an ineffective strategy cannot consume a host all day.

if {[info exists env(JG_TIME_LIMIT)] && $env(JG_TIME_LIMIT) ne ""} {
    set PROOF_TIME_LIMIT $env(JG_TIME_LIMIT)
} else {
    set PROOF_TIME_LIMIT 5m
}

puts "Focused proof time limit: $PROOF_TIME_LIMIT"
set_prove_time_limit $PROOF_TIME_LIMIT
set_prove_per_property_max_time_limit $PROOF_TIME_LIMIT
