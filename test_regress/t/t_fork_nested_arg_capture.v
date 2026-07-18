// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t;
  class c;
    bit [1:0] got[$];

    task automatic go(bit [1:0] val, bit field_only = 0, bit is_wkup = 0);
      fork
        begin : non_blocking_fork
          fork
            begin : iso_fork
              fork
                begin : payload
                  #0;
                  got.push_back({field_only, is_wkup});
                end
                begin : killer
                  #10;
                end
              join_any
              disable fork;
            end
          join
        end
      join_none
    endtask
  endclass

  initial begin
    automatic c o = new();
    o.go(.val(3), .field_only(1), .is_wkup(1));
    o.go(.val(3), .field_only(1), .is_wkup(0));
    #1;
    if (o.got.size() == 2 && ((o.got[0] == 2'b11 && o.got[1] == 2'b10)
                              || (o.got[0] == 2'b10 && o.got[1] == 2'b11))) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
    else begin
      $display("%%Error: got=%p expected {2'b11,2'b10} in any order", o.got);
      $stop;
    end
  end
endmodule
