// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t;

  class Item;
    static function Item create(string s);
      Item i = new;
      return i;
    endfunction
  endclass

  class BaseSeq #(
      type REQ = Item
  );
    REQ m_req;
  endclass

  // A genuinely undefined name as a '::' operand inside a class with a
  // parameterized base must still error -- the deferral only delays resolution
  // to linkDotParamed, it does not mask real errors for instantiated classes.
  class ChildSeq #(
      type REQ_T = Item
  ) extends BaseSeq #(REQ_T);
    function void make();
      Item r;
      r = Undefined::create("x");
      m_req = r;
    endfunction
  endclass

  ChildSeq #(Item) c;

  initial begin
    c = new;
    c.make();
  end

endmodule
