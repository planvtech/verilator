class implication_con_and_if_else_con_class;

    rand int flag = 0;
    rand int sub_flag = 0;

    rand bit [2:0] ic_data1;
    rand logic[3:0] ic_data2;

    rand logic[7:0] iec_data1;
    rand logic[7:0] iec_data2;
    rand logic[9:0] iec_data3;
    
    constraint imp_con {
        ic_data1 > 2 -> ic_data2 inside {1, 2, 3};
    }
    
    constraint flag_con {
        flag > -4 && flag < 4;
        sub_flag inside {-15, -10, -5, 0, 10, 20, 25};
    }

    constraint if_else_con_1 {
        if(flag > 2) {
            iec_data1 inside {1, 2, 3} || iec_data1 % 2 == 0;
        } else {
            (iec_data1 & 8'hF0) == 8'hA0;
        }
    }
    
    constraint if_else_con_2 {
        if(flag > 2) {
            iec_data2 inside {1, 2, 3};
        } else if (flag > 0) {
            iec_data2 inside {4, 5};
        } else if (flag > -2) {
            iec_data2 inside {6, 7};
        }
        else {
            iec_data2 inside {8, 9};
        }
    }
    
    constraint if_else_con_3 {
        if (flag > 0) {
            if (sub_flag > 10) {
                iec_data3 inside {1, 2, 3} || iec_data3 % 2 == 0;
            } else if (sub_flag == 10) {
                iec_data3 inside {6, 7};
            } else {
                iec_data3 inside {4, 5};
            }
        } else if (flag == 0 || flag == -1) {
            if (sub_flag < -10) {
                iec_data3 inside {10, 11};
            } else {
                iec_data3 inside {12, 13};
            }
        } else {
            if (sub_flag > 20) {
                iec_data3 inside {14, 15};
            } else if (sub_flag == 20) {
                iec_data3 inside {16, 17};
            } else {
                iec_data3 inside {8, 9};
            }
        }
    }
endclass

module implication_con_and_if_else_con;

    implication_con_and_if_else_con_class w = new;
    int v;

    initial begin
        
        repeat(50) begin

            $display("***************************");

            v = w.randomize(); // with { delay > 90 && delay < 700; };
            if (v !=1 ) $stop;
            
            // Test results
            
            if (w.ic_data1 > 2) begin
                if (!(w.ic_data2 == 1 || w.ic_data2 == 2 || w.ic_data2 == 3)) $display("Constraint violated: ic_data1 = %0d, ic_data2 = %0d", w.ic_data1, w.ic_data2);
            end

            if (w.flag > 2) begin
                if (!(w.iec_data1 == 1 || w.iec_data1 == 2 || w.iec_data1 == 3 || w.iec_data1 % 2 == 0)) $display("Constraint violated: flag = %0d, iec_data1 = %0d", w.flag, w.iec_data1);
            end else begin
                if (!((w.iec_data1 & 8'hF0) == 8'hA0)) $display("Constraint violated: flag = %0d, iec_data1 = %0d", w.flag, w.iec_data1);
            end

            if (w.flag > 2) begin
                if (!(w.iec_data2 == 1 || w.iec_data2 == 2 || w.iec_data2 == 3)) $display("Constraint violated: flag = %0d, iec_data2 = %0d", w.flag, w.iec_data2);
            end else if (w.flag > 0) begin
                if (!(w.iec_data2 == 4 || w.iec_data2 == 5)) $display("Constraint violated: flag = %0d, iec_data2 = %0d", w.flag, w.iec_data2);
            end else if (w.flag > -2) begin
                if (!(w.iec_data2 == 6 || w.iec_data2 == 7)) $display("Constraint violated: flag = %0d, iec_data2 = %0d", w.flag, w.iec_data2);
            end else begin
                if (!(w.iec_data2 == 8 || w.iec_data2 == 9)) $display("Constraint violated: flag = %0d, iec_data2 = %0d", w.flag, w.iec_data2);
            end
                // assert doesn't work!
            if (w.flag > 0) begin
                if (w.sub_flag > 10) begin
                    assert(w.iec_data3 == 1 || w.iec_data3 == 2 || w.iec_data3 == 3 || w.iec_data3 % 2 == 0) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end else if (w.sub_flag == 10) begin
                    assert(w.iec_data3 == 6 || w.iec_data3 == 7) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end else begin
                    assert(w.iec_data3 == 4 || w.iec_data3 == 5) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end
            end else if (w.flag == 0 || w.flag == -1) begin
                if (w.sub_flag < -10) begin
                    assert(w.iec_data3 == 10 || w.iec_data3 == 11) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end else begin
                    assert(w.iec_data3 == 12 || w.iec_data3 == 13) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end
            end else begin
                if (w.sub_flag > 20) begin
                    assert(w.iec_data3 == 14 || w.iec_data3 == 15) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end else if (w.sub_flag == 20) begin
                    assert(w.iec_data3 == 16 || w.iec_data3 == 17) else $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end else begin
                    // Error
                    if(!(w.iec_data3 == 8 || w.iec_data3 == 9)) $error("Constraint violated: flag = %0d, sub_flag = %0d, iec_data3 = %0d", w.flag, w.sub_flag, w.iec_data3);
                end
            end

            $display("ic_data1(h) = %h", w.ic_data1);
            $display("ic_data2(h) = %h", w.ic_data2);

            $display("flag(d) = %d", w.flag);
            $display("sub_flag(d) = %d", w.sub_flag);
            $display("iec_data1(h) = %h", w.iec_data1);
            $display("iec_data2(d) = %d", w.iec_data2);
            $display("iec_data3(d) = %d", w.iec_data3);

        end
        $finish;
    end
endmodule