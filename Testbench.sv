  import enum_pkg::*;
  import Uart_packet::*;

module testbench;


  logic       clk;
  logic       rst_n;
  logic       tx_start;
  logic [7:0] data_in;
  logic       parity_en;
  logic       even_parity;
  logic       tx;
  logic       tx_busy;

  uart_tx dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .tx_start   (tx_start),
    .data_in    (data_in),
    .parity_en  (parity_en),
    .even_parity(even_parity),
    .tx         (tx),
    .tx_busy    (tx_busy)
  );

    typedef struct packed {
        bit [7:0] expected_data;
        bit       expected_parity_bit;
        parity_t  parity_mode;
    } expected_t;

    typedef struct packed {
        bit [7:0] rx_byte;
        bit parity_bit;
    } collecting_output;

	transmission tr;
	
    transmission tr_q [$];
    
    //transmission tr_manual;

    expected_t expected_queue[$];

    collecting_output actual_queue [$];

  task automatic generate_stimulus();
        for (int i = 0; i < 100; i++) begin 
            tr = new();
            assert(tr.randomize()) else $finish;
            tr_q.push_back(tr);
        end
        $display("generating");
    endtask

    task automatic golden_model();
        foreach(tr_q[i]) begin 
            expected_t exp;
            
            exp.expected_data  = tr_q[i].data_in_test;
            exp.parity_mode    = tr_q[i].parity_mode;
            
            if (exp.parity_mode == ODD) begin
                exp.expected_parity_bit = ^tr_q[i].data_in_test;
            end
            else if (exp.parity_mode == EVEN) begin
                exp.expected_parity_bit = ~(^tr_q[i].data_in_test);
            end 
            else begin
                exp.expected_parity_bit = 0;  // NO_PARITY
            end
            
            expected_queue.push_back(exp);
            
        end
         $display("golden");
    endtask 

    task automatic drive_stim(ref logic clk, ref logic tx_start, ref logic [7:0] data_in,
                              ref logic parity_en, ref logic even_parity, ref logic tx_busy);
        foreach (tr_q[i]) begin
            data_in = tr_q[i].data_in_test;
            
            if(tr_q[i].parity_mode == ODD) begin 
                parity_en = 1;
                even_parity = 0;
            end 
            else if(tr_q[i].parity_mode == EVEN) begin 
                parity_en = 1;
                even_parity = 1;
            end
            else begin
                parity_en = 0;
                even_parity = 0;  // don't care
            end
            
            @(posedge clk);
            tx_start = 1;
            
            @(posedge clk);
            tx_start = 0;
            
            #10ns;
            wait (tx_busy == 0);
        end
        $display("driving");
    endtask

    task automatic collect_output(ref logic clk, ref logic tx, ref logic tx_start, ref logic parity_en);
        $display("I am here 4");
		foreach (tr_q[i]) begin
            collecting_output act;
            bit [7:0] rx_byte;
            @(posedge clk);  // START bit cycle
            
            for (int j = 0; j < 8; j++) begin
                @(posedge clk);
                rx_byte[j] = tx;
            end
            $display("before parity_en");
            
            if (parity_en == 1) begin 
                @(posedge clk);
                act.parity_bit = tx;
            end 
            else begin 
                act.parity_bit = 0;
            end 
            
            @(posedge clk);  // stop bit
            
            act.rx_byte = rx_byte;
            actual_queue.push_back(act);
            
        end   
        $display("collecting");           
    endtask

    task automatic check_result();
        int counter = 0;
        int failed_iterations[$];
        
        foreach(expected_queue[i]) begin 
            if (expected_queue[i].expected_data == actual_queue[i].rx_byte) begin
                if(expected_queue[i].parity_mode != NO_PARITY) begin 
                    if(expected_queue[i].expected_parity_bit == actual_queue[i].parity_bit) begin 
                        $display("passed");
                        $display("Transmission %0d: Expected data = %0d, Actual data = %0d", 
                                 i, expected_queue[i].expected_data, actual_queue[i].rx_byte);
                    end 
                    else begin 
                        $display("failed");
                        $display("Transmission %0d: Expected data = %0d, Actual data = %0d", 
                                 i, expected_queue[i].expected_data, actual_queue[i].rx_byte);
                        counter++;
                        failed_iterations.push_back(i);
                    end 
                end
                else begin
                    $display("no parity ");
                    $display("Transmission %0d: Expected data = %0d, Actual data = %0d", 
                             i, expected_queue[i].expected_data, actual_queue[i].rx_byte);
                end
            end
            else begin 
                $display("failed");
                $display("Transmission %0d: Expected data = %0d, Actual data = %0d", 
                         i, expected_queue[i].expected_data, actual_queue[i].rx_byte);
                counter++;
                failed_iterations.push_back(i);
            end 
        end 
        
        $display("no of fails = %0d", counter);
        foreach(failed_iterations[i]) begin 
            $display("code of failed iteration = %0d", failed_iterations[i]);
        end
    endtask



  initial begin
    clk = 1'b0;
    forever #5ns clk = ~clk;
  end

  initial begin
	rst_n       = 1'b0;
	tx_start    = 1'b0;
	data_in     = 8'h00;
	parity_en   = 1'b0;
	even_parity = 1'b0;

	#20ns;
	rst_n = 1'b1;

    generate_stimulus();
    golden_model();

    // tx_busy is a DUT output, so it is not passed to drive_stim.
    drive_stim(
      clk,
      tx_start,
      data_in,
      parity_en,
      even_parity,
      tx_busy
    );

    //wait (tr_q.size() == 99);

    collect_output(
      clk,
      tx,
      tx_start,
      parity_en
    );

    check_result();

    $finish;
  end

endmodule