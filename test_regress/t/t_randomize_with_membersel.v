// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain, for
// any use, without warranty, 2025 by PlanV GmbH.
// SPDX-License-Identifier: CC0-1.0

class Payload;

  rand bit [7:0] data;
  rand bit [7:0] limit_min;
  bit [7:0] limit_max = 140;

  function bit run();
    return randomize() with { 
      data inside {[100:200]};
      limit_min inside {[110:120]};
      data <= limit_max;
      data >= limit_min; };
  endfunction

endclass


module t_randomize_with_membersel;

  Payload p = new();
  bit success, valid;
  initial begin
    success = p.run();
    valid = success && (p.data inside {[100:200]}) && (p.limit_min inside {[110:120]}) && (p.limit_max == 140) && (p.data <= p.limit_max) && (p.data >= p.limit_min);
    // $display("p.data = %0d, p.limit_min = %0d, p.limit_max = %0d", p.data, p.limit_min, p.limit_max);
    if (!valid) $stop;
    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
