// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

class C;
  rand int unsigned a;
  rand int unsigned b;
  constraint a_c {a inside {[1 : 10]};}
  constraint b_c {b inside {[20 : 30]};}

  task run_single();
    fork
      begin
        if (this.randomize(a) == 0) $stop;
        if (!(a inside {[1 : 10]})) $stop;
      end
    join_none
    wait fork;
  endtask

  task run_multi();
    fork
      begin
        if (this.randomize(a, b) == 0) $stop;
        if (!(a inside {[1 : 10]})) $stop;
        if (!(b inside {[20 : 30]})) $stop;
      end
    join_none
    wait fork;
  endtask

  task run_with();
    fork
      begin
        if (this.randomize(a) with {a > 5;} == 0) $stop;
        if (!(a inside {[6 : 10]})) $stop;
      end
    join_none
    wait fork;
  endtask

  task run_cmode();
    fork
      begin
        this.b_c.constraint_mode(0);
        if (this.randomize(a) == 0) $stop;
        if (!(a inside {[1 : 10]})) $stop;
        this.b_c.constraint_mode(1);
      end
    join_none
    wait fork;
  endtask

  task run_nested();
    fork
      begin
        fork
          begin
            if (this.randomize(b) == 0) $stop;
            if (!(b inside {[20 : 30]})) $stop;
          end
        join_any
      end
    join_none
    wait fork;
  endtask
endclass

module t;
  initial begin
    C c;
    int i;
    c = new;
    if (c.randomize() == 0) $stop;
    for (i = 0; i < 20; i++) begin
      c.run_single();
      c.run_multi();
      c.run_with();
      c.run_cmode();
      c.run_nested();
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
