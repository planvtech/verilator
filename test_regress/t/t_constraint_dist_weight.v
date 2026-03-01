// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define check_range(gotv,minv,maxv) do if ((gotv) < (minv) || (gotv) > (maxv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d-%0d\n", `__FILE__,`__LINE__, (gotv), (minv), (maxv)); `stop; end while(0);
// verilog_format: on

// Test that dist constraint weights (:= and :/) produce correct distributions.
// IEEE 1800-2017 18.5.4

class DistScalar;
  rand bit [7:0] x;
  // := weight is per-value: 0 has weight 1, 255 has weight 3 => ~75% should be 255
  constraint c { x dist { 8'd0 := 1, 8'd255 := 3 }; }
endclass

class DistRange;
  rand bit [7:0] x;
  // :/ weight is per-range: [0:9] has total weight 1, [10:19] has total weight 3
  constraint c { x dist { [8'd0:8'd9] :/ 1, [8'd10:8'd19] :/ 3 }; }
endclass

class DistZeroWeight;
  rand bit [7:0] x;
  // Weight 0 means never selected
  constraint c { x dist { 8'd0 := 0, 8'd1 := 1, 8'd2 := 1 }; }
endclass

module t;
  initial begin
    DistScalar sc;
    DistRange rg;
    DistZeroWeight zw;
    int count_high;
    int count_range_high;
    int total;

    total = 2000;

    // Test 1: := scalar weights (expect ~75% for value 255)
    sc = new;
    count_high = 0;
    repeat (total) begin
      `checkd(sc.randomize(), 1);
      if (sc.x == 8'd255) count_high++;
      else `checkd(sc.x, 0);  // Only 0 or 255 should appear
    end
    // 75% of 2000 = 1500, allow wide range for statistical test
    `check_range(count_high, 1200, 1800);

    // Test 2: :/ range weights (expect ~75% in [10:19])
    rg = new;
    count_range_high = 0;
    repeat (total) begin
      `checkd(rg.randomize(), 1);
      if (rg.x >= 8'd10 && rg.x <= 8'd19) count_range_high++;
      else if (rg.x > 8'd9) begin
        $write("%%Error: x=%0d outside valid range [0:19]\n", rg.x);
        `stop;
      end
    end
    `check_range(count_range_high, 1200, 1800);

    // Test 3: Zero weight exclusion (value 0 should never appear)
    zw = new;
    repeat (total) begin
      `checkd(zw.randomize(), 1);
      if (zw.x == 8'd0) begin
        $write("%%Error: zero-weight value 0 was selected\n");
        `stop;
      end
      `check_range(zw.x, 1, 2);
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
