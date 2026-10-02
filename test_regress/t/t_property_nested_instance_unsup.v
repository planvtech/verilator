// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// A named property instance nested under a property operator (|->), where
// the enclosing expression has no multi-cycle construct (##, [*], etc.).
// V3AssertNfa's hasMultiCycleExpr() check gates its own nested-instance
// rejection ("Unsupported: property instance inside a multi-cycle property
// expression" in V3AssertNfa.cpp), so a single-cycle nested instance like
// this one skips that guard entirely and previously reached V3AssertPre
// unguarded, leaving a dangling AstFuncRef->AstProperty link that crashed
// V3Broken. See #8295.

module t (
    input clk
);

  bit a = 0;

  property q;
    a;
  endproperty

  assert property (@(posedge clk) a |-> q);

endmodule