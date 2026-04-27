# Upstream PR -- Issue #7472

## Title

Fix internal error on multi-cycle SVA under default clocking

## Body

```markdown
## Summary

This patch fixes an internal error when a concurrent assertion uses the module's `default clocking` (IEEE 1800-2023 14.12) and contains a multi-cycle property such as `b throughout (c ##1 d)`. The same path also flows `default disable iff` (IEEE 16.15) into multi-cycle bodies. Fixes #7472.

## Reproducer

```systemverilog
module t (input clk, input a, b, c, d);
  default clocking @(posedge clk); endclocking
  assert property (a |=> b throughout (c ##1 d));
endmodule
```

On master:
```
%Error: ...: Internal: Unexpected Call
   ... |       a |=> b throughout (c ##1 d)
%Error: Internal Error: ../V3AstNodeExpr.h:#: Unexpected Call
```

Root cause: `V3AssertNfa::processAssertion` consulted `propSpecp->sensesp()`, which is null when only `default clocking` is in scope, so it bailed and the `AstSThroughout(AstSExpr)` subtree leaked to V3Clean and fatalled in `AstSExpr::cleanOut()`. V3AssertPre's `|=>` fallback then wrapped the RHS in `AstOr{Not{Past{a}}, rhsp}` without lowering the temporal operators.

## Changes

- `src/V3AssertNfa.{cpp,h}` (`AssertNfaVisitor`, new `V3AssertNfa::collectModuleDefaults`): scan the enclosing module once for `default clocking` / `default disable iff` and apply them to a `PropSpec` whose `sensesp()` / `disablep()` are still null, before lowering. The scan helper is shared with V3AssertPre so both passes resolve the same first-found defaults.
- `src/V3AssertPre.cpp` (`visit(AstNodeModule)`): consume the shared helper instead of re-scanning, and pre-create the clocking event var before `iterateChildren` so `visit(AstClocking)` does not unlink it out from under a later `ensureEventp()`.

## Test

- Added `test_regress/t/t_property_default_clocking_sexpr.{v,py}` -- CRC-driven 99-cycle stimulus across four `assert property` shapes (`|=>` throughout repro, `|->` overlapped variant, no-throughout baseline, nested throughout) plus two `cover property` cases under default clocking and `default disable iff (cyc < 10)`; counted-failure totals validated against Questa.

---
Developed by PlanV GmbH, assisted with Claude Code.

Reviewed by YilouWang.
```
