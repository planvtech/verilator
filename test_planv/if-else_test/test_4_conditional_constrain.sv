typedef enum bit[15:0] { 
    ONE = 3,
    TWO = 5,
    THREE = 8,
    FOUR = 13
} ENUM;

class cls;
    rand ENUM enum_4_;
    rand bit[31:0] lgc_32_bit;
    rand bit x;

    constraint enum_con {
        enum_4_ inside {TWO, THREE};
    }
    function new();
        enum_4_ = ONE;
    endfunction
endclass

class w_sequence_item;
    cls cls_1_;
    int r;
    int flag = 0;

    rand logic[7:0] data1;
    rand logic[7:0] data2;
    rand logic[7:0] data3;
    rand int delay;
    
    // constraint w_delay_con { delay > 90 && delay < 700;}
    constraint data1_con {
        // conditional doesn't work
        if(flag) {
            data1 inside {1, 2, 3}; //|| data % 2 == 0;
        } else {
            // mask
            (data1 & 8'hF0) == 8'hA0;
        }
    }

    constraint data2_con {
        data2 inside {1, 2, 3};
    }

    constraint data3_con {
        (data3 & 8'hF0) == 8'hA0;
    }

    function new(string name = "w_sequence_item");
        cls_1_ = new();
        r = cls_1_.randomize(); // randomize() with {} is not supported in Verilator currently.
        flag = cls_1_.x;
    endfunction

endclass

module test_4_conditional_constrain;
    w_sequence_item w;
    int v;
    initial begin
        repeat(10) begin
            //$display("***************************");
            $display("***************************");
            w = new();
            $display("w_sequence_item: delay: %0d, flag: %b", w.delay, w.flag);
            $display("data1(h) = %h", w.data1);
            //$display("data1(d) = %d", w.data1);
            $display("data2(h) = %h", w.data2);
            //$display("data2(d) = %d", w.data2);
            $display("data3(h) = %h", w.data3);
            //$display("data3(d) = %d", w.data3);
            //$display("w_data has constraints that, if flag=1, data inside {1,2,3} or data is even. else, data high 4 bit is 1010.");
            $display("cls: enum_4_: %0d, lgc_32_bit: %h, x: %b", w.cls_1_.enum_4_, w.cls_1_.lgc_32_bit, w.cls_1_.x);
            //$display("cls has constraints that, enum_4_ inside {5, 8}");
            $display("***************************");

            v = w.randomize(); // with { delay > 90 && delay < 700; };
            if (v !=1 ) $stop;
            
            //$display(w);
            $display("w_sequence_item: delay: %0d, flag: %b", w.delay, w.flag);
            $display("data1(h) = %h", w.data1);
            //$display("data1(d) = %d", w.data1);
            $display("data2(h) = %h", w.data2);
            //$display("data2(d) = %d", w.data2);
            $display("data3(h) = %h", w.data3);
            //$display("data3(d) = %d", w.data3);

            //$display("w_data has constraints that, if flag=1, data inside {1,2,3} or data is even. else, data high 4 bit is 1010.");
            $display("cls: enum_4_: %0d, lgc_32_bit: %h, x: %b", w.cls_1_.enum_4_, w.cls_1_.lgc_32_bit, w.cls_1_.x);

            //$display("cls has constraints that, enum_4_ inside {5, 8}");
            $display("***************************");
            //$display("***************************");
        end
        $finish;
    end
endmodule