// Compatibility entry point. The original expression-based fixtures predate
// the fail-closed Anthropic identity gate and could still expect an equipable
// local fallback. Preserve this command name, but execute the canonical current
// suite with the same browser / URL / output arguments and fixed simulated HTTP
// mode. This compatibility name can never authorize a paid provider call.
process.argv[5] = "simulated";
await import("./run_m1b1_anthropic_mobile_regression.mjs");
