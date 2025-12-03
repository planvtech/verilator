// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain, for
// any use, without warranty, 2025 by PlanV GmbH.
// SPDX-License-Identifier: CC0-1.0


class axi_agent_config;
   rand bit r_ready_delays;
   constraint r_ready_delays_c {
      r_ready_delays == 0;
   }
endclass

class axi_env_config;
   rand axi_agent_config   axim_agt_cfg;
   function new();
      axim_agt_cfg = new;
   endfunction
endclass

class axi_base_test;
  axi_env_config axi_env_cfg;
  virtual function void build_phase();
    configure_axi_env();
  endfunction
  function void configure_axi_env();
    axi_env_cfg = new;
  endfunction
endclass

class axi_wrap_test extends axi_base_test;
  function void configure_axi_env();
    axi_env_cfg = new;
    void'(axi_env_cfg.randomize());
  endfunction
endclass

module t_fix_global_constraints;
  initial begin
    axi_wrap_test x = new();
    x.build_phase();
    if (x.axi_env_cfg.axim_agt_cfg.r_ready_delays != 0) begin
      $write("ERROR: r_ready_delays constraint violation: %0d\n",
             x.axi_env_cfg.axim_agt_cfg.r_ready_delays);
    end else begin
      $write("INFO: r_ready_delays constraint satisfied: %0d\n",
             x.axi_env_cfg.axim_agt_cfg.r_ready_delays);
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
