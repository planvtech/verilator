//DEBUG USE

typedef enum bit[15:0] { 
    ONE = 3,
    TWO = 5,
    THREE = 8,
    FOUR = 13
} ENUM;

typedef union packed {
    int x;
    bit [7:0] byte_value;
} UNION;

class cls;
    rand ENUM enum_4_;
    rand UNION union_2_;    //UNSPORTED IN VERILATOR(A DIRECTION TO VESTIGATE)
    rand int dyn_arr[];
    rand bit[31:0] lgc_1_;
    rand bit x;

    constraint combined_debug {
        enum_4_ inside {TWO, THREE};
        //if (lgc_1_ < 100) {
        //    union_2_.x < 10000;
        // } else {
        //    union_2_.byte_value inside {8'h0, 8'hFF};
        //}
        //dyn_arr.size() < 5;
    }
    function new();
        enum_4_ = ONE;
    endfunction
endclass
//DEBUG USE

class w_sequence_item;
    cls cls_1_;
    int r;

    rand logic[7:0] data1;
    rand logic[7:0] data2;
    rand logic[7:0] data3;
    rand int delay;
    rand logic flag;
    
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
    endfunction

endclass

module simple_tb;
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
            $display("cls: enum_4_: %0d, lgc_1_: %h, x: %b", w.cls_1_.enum_4_, w.cls_1_.lgc_1_, w.cls_1_.x);
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
            $display("cls: enum_4_: %0d, lgc_1_: %h, x: %b", w.cls_1_.enum_4_, w.cls_1_.lgc_1_, w.cls_1_.x);

            //$display("cls has constraints that, enum_4_ inside {5, 8}");
            $display("***************************");
            //$display("***************************");
        end
        $finish;
    end
endmodule