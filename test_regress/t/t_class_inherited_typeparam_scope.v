// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t;

  class Item;
    static int s_count = 0;
    typedef Item type_id;
    int id;
    static function Item create(int v);
      Item i = new;
      i.id = v;
      s_count++;
      return i;
    endfunction
  endclass

  class BaseSeq #(
      type REQ = Item
  );
    REQ m_req;
  endclass

  // Derived class forwards its own type parameter REQ_T to the parameterized
  // base, then refers to the inherited parameter REQ as the operand of '::'.
  class ChildSeq #(
      type REQ_T = Item
  ) extends BaseSeq #(REQ_T);
    function void make(int v);
      REQ r = REQ::create(v);  // inherited type param as '::' operand
      m_req = r;
    endfunction
    function Item makeNested(int v);
      return REQ::type_id::create(v);  // nested '::' via inherited param
    endfunction
    function int reqCount();
      return REQ::s_count;  // static member via inherited param '::'
    endfunction
  endclass

  // Multi-level inheritance: the grandchild reaches the grandparent's type
  // parameter via '::'.
  class MidSeq #(
      type T = Item
  ) extends BaseSeq #(T);
  endclass
  class GrandSeq #(
      type U = Item
  ) extends MidSeq #(U);
    function Item makeReq(int v);
      return REQ::create(v);
    endfunction
  endclass

  initial begin
    ChildSeq #(Item) c;
    GrandSeq #(Item) g;
    Item n;
    Item gr;

    c = new;
    g = new;

    c.make(7);
    if (c.m_req == null) $stop;
    if (c.m_req.id != 7) $stop;

    n = c.makeNested(8);
    if (n == null) $stop;
    if (n.id != 8) $stop;

    gr = g.makeReq(9);
    if (gr == null) $stop;
    if (gr.id != 9) $stop;

    if (c.reqCount() != 3) $stop;  // create() ran 3 times (7, 8, 9)

    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
