package Uart_packet;
    
    import enum_pkg::*;
    
    class transmission;
        rand bit [7:0] data_in_test;
        rand parity_t parity_mode;
        
        // Constructor
        function new();
            // Optional initialization
        endfunction
        
        constraint c1 {
            data_in_test dist {255 := 10, 0 := 10, [1:254] :/ 80};
        }
    endclass
    

    
endpackage