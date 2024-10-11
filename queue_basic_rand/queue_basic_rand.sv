class array;
    rand int unpacked_arr [3:1][9:3];

    task print();

        $display("Unpacked Arr:");
        foreach(unpacked_arr[i]) begin
            foreach(unpacked_arr[i][j]) begin
                $display("unpacked_arr[%0d][%0d] = %0d ." , i, j, unpacked_arr[i][j]);
            end
        end
        $display("--------------------------------------------");
        foreach(unpacked_arr[i, j]) begin
            $display("unpacked_arr[%0d][%0d] = %0d ." , i, j, unpacked_arr[i][j]);
        end
    endtask

endclass

module queue_basic_rand;

    array cl;

  initial begin
    cl = new();

    $display("%p",cl.unpacked_arr);
    cl.print();
    void'(cl.randomize());
    $display("%p",cl.unpacked_arr);
    cl.print();

  end

endmodule