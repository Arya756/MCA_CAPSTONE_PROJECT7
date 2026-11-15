// ============================================================================
// Testbench:    tb_direct_basic
// Project:      Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:        Member 3 (Direct-Mapped Baseline & Memory Model)
// Description:  Basic verification testbench for cache_direct:
//               1. Write-through and read-back on the same address.
//               2. Verification of conflict miss on two addresses mapping to
//                  the same cache line (direct conflict thrashing).
//               3. Verification of No-Write-Allocate on write miss.
// ============================================================================

`timescale 1ns / 1ps

`ifndef RD_LAT
`define RD_LAT 8
`endif

`ifndef WR_LAT
`define WR_LAT 4
`endif

module tb_direct_basic;

    reg         clk;
    reg         rst;

    // CPU interface
    reg         cpu_req;
    reg         cpu_we;
    reg  [31:0] cpu_addr;
    reg  [31:0] cpu_wdata;
    wire        cpu_ready;
    wire [31:0] cpu_rdata;

    // Memory interface
    wire        mem_req;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    // Stats
    wire [31:0] hit_count;
    wire [31:0] miss_count;
    wire [31:0] cycle_count;

    integer errors;

    // Instantiate Direct-Mapped Cache
    cache_direct #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .CACHE_CAPACITY(1024),
        .BLOCK_SIZE(16)
    ) uut_cache (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req),
        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_ready(cpu_ready),
        .cpu_rdata(cpu_rdata),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
        .hit_count(hit_count),
        .miss_count(miss_count),
        .cycle_count(cycle_count)
    );

    // Instantiate Main Memory Model
    main_memory #(
        .RD_LAT(`RD_LAT),
        .WR_LAT(`WR_LAT),
        .MEM_WORDS(4096)
    ) u_mem (
        .clk(clk),
        .rst(rst),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    // Clock generator (10 ns period -> 100 MHz)
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Helper Tasks
    // ------------------------------------------------------------------------
    task cpu_read;
        input  [31:0] addr;
        output [31:0] rdata;
        output        was_hit;
        reg [31:0] prev_hits;
        begin
            @(posedge clk);
            prev_hits = hit_count;
            cpu_addr  = addr;
            cpu_we    = 1'b0;
            cpu_req   = 1'b1;

            @(posedge clk);
            while (!cpu_ready) @(posedge clk);

            rdata   = cpu_rdata;
            was_hit = (hit_count > prev_hits);
            cpu_req = 1'b0;
            @(posedge clk);
        end
    endtask

    task cpu_write;
        input  [31:0] addr;
        input  [31:0] wdata;
        output        was_hit;
        reg [31:0] prev_hits;
        begin
            @(posedge clk);
            prev_hits = hit_count;
            cpu_addr  = addr;
            cpu_wdata = wdata;
            cpu_we    = 1'b1;
            cpu_req   = 1'b1;

            @(posedge clk);
            while (!cpu_ready) @(posedge clk);

            was_hit = (hit_count > prev_hits);
            cpu_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // Addresses for conflict test (Line Index = addr[9:4] = 6'd5)
    // Addr X: Tag = 1 -> 32'h0000_0450
    // Addr Y: Tag = 2 -> 32'h0000_0850
    localparam [31:0] ADDR_X = 32'h0000_0450;
    localparam [31:0] ADDR_Y = 32'h0000_0850;
    localparam [31:0] ADDR_W = 32'h0000_0120; // Line 18

    reg [31:0] data_out;
    reg        hit_flag;

    initial begin
        clk       = 0;
        rst       = 1;
        cpu_req   = 0;
        cpu_we    = 0;
        cpu_addr  = 0;
        cpu_wdata = 0;
        errors    = 0;

        // Initialize VCD waveform output
        $dumpfile("results/direct_basic.vcd");
        $dumpvars(0, tb_direct_basic);

        // Initialize memory backing array
        u_mem.mem_array[ADDR_X[13:2] + 0] = 32'h1111_0000;
        u_mem.mem_array[ADDR_X[13:2] + 1] = 32'h1111_0001;
        u_mem.mem_array[ADDR_X[13:2] + 2] = 32'h1111_0002;
        u_mem.mem_array[ADDR_X[13:2] + 3] = 32'h1111_0003;
        u_mem.mem_array[ADDR_Y[13:2]]     = 32'h3333_4444;

        #20;
        @(posedge clk);
        rst = 0;
        #20;

        $display("------------------------------------------------------------");
        $display("STARTING DIRECT-MAPPED BASIC VERIFICATION TESTS");
        $display("------------------------------------------------------------");

        // --------------------------------------------------------------------
        // Test 1: Write then Read the same address
        // --------------------------------------------------------------------
        $display("[Test 1] Write then Read back same address (0x%h)", ADDR_W);
        cpu_write(ADDR_W, 32'hCAFE_BABE, hit_flag); // Write miss (no-write-allocate)
        $display("  Write issued. Validating memory was written through...");
        if (u_mem.mem_array[ADDR_W[13:2]] !== 32'hCAFE_BABE) begin
            $display("  FAIL: Main memory not updated by write-through! Got %h", u_mem.mem_array[ADDR_W[13:2]]);
            errors = errors + 1;
        end else begin
            $display("  PASS: Main memory successfully updated via write-through");
        end

        // Now read back: will miss (proving No-Write-Allocate), fetch block containing our written word, and refill
        cpu_read(ADDR_W, data_out, hit_flag);
        if (hit_flag) begin
            $display("  FAIL: First read of ADDR_W hit in cache! Expected MISS (No-Write-Allocate violated)");
            errors = errors + 1;
        end else begin
            $display("  PASS: First read of ADDR_W was a verified MISS (No-Write-Allocate confirmed)");
        end

        if (data_out !== 32'hCAFE_BABE) begin
            $display("  FAIL: Read back returned %h, expected CAFEBABE", data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Read back returned %h correctly", data_out);
        end

        // Read once more: should be a HIT
        cpu_read(ADDR_W, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'hCAFE_BABE) begin
            $display("  FAIL: Expected cache HIT on second read of ADDR_W!");
            errors = errors + 1;
        end else begin
            $display("  PASS: Second read was a verified cache HIT!");
        end

        // --------------------------------------------------------------------
        // Test 2: Conflict Miss Test on same line
        // --------------------------------------------------------------------
        $display("[Test 2] Conflict Miss Test on Line 5 (ADDR_X and ADDR_Y)");
        // Step A: Read ADDR_X -> Miss & Refill
        cpu_read(ADDR_X, data_out, hit_flag);
        if (hit_flag || data_out !== 32'h1111_0000) begin
            $display("  FAIL: Cold read ADDR_X should miss! Expected 11110000, got hit=%0b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: ADDR_X cold miss and refilled with data %h", data_out);
        end

        // Step A.1: Spatial locality checks - read other words in the same refilled block
        // Word 1: ADDR_X + 4
        cpu_read(ADDR_X + 4, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'h1111_0001) begin
            $display("  FAIL: Read ADDR_X+4 expected HIT and value 11110001, got hit=%0b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: ADDR_X+4 hit in cache with data %h", data_out);
        end

        // Word 2: ADDR_X + 8
        cpu_read(ADDR_X + 8, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'h1111_0002) begin
            $display("  FAIL: Read ADDR_X+8 expected HIT and value 11110002, got hit=%0b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: ADDR_X+8 hit in cache with data %h", data_out);
        end

        // Word 3: ADDR_X + 12
        cpu_read(ADDR_X + 12, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'h1111_0003) begin
            $display("  FAIL: Read ADDR_X+12 expected HIT and value 11110003, got hit=%0b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: ADDR_X+12 hit in cache with data %h", data_out);
        end

        // Step B: Read ADDR_X again -> HIT
        cpu_read(ADDR_X, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'h1111_0000) begin
            $display("  FAIL: Repeated read of ADDR_X should HIT!");
            errors = errors + 1;
        end else begin
            $display("  PASS: Repeated read of ADDR_X was a HIT");
        end

        // Step C: Read conflicting ADDR_Y -> Conflict miss, evicts ADDR_X!
        cpu_read(ADDR_Y, data_out, hit_flag);
        if (hit_flag || data_out !== 32'h3333_4444) begin
            $display("  FAIL: ADDR_Y should miss due to conflict!");
            errors = errors + 1;
        end else begin
            $display("  PASS: ADDR_Y caused conflict miss and evicted ADDR_X");
        end

        // Step D: Read ADDR_X again -> must MISS because ADDR_Y evicted it
        cpu_read(ADDR_X, data_out, hit_flag);
        if (hit_flag || data_out !== 32'h1111_0000) begin
            $display("  FAIL: ADDR_X should have missed because it was evicted by conflict!");
            errors = errors + 1;
        end else begin
            $display("  PASS: ADDR_X confirmed evicted by conflict!");
        end

        // --------------------------------------------------------------------
        // Final Summary Banner
        // --------------------------------------------------------------------
        $display("------------------------------------------------------------");
        if (errors == 0) begin
            $display("Direct-Mapped Basic Tests Summary: ALL CHECKS PASSED!");
            $display("DIRECT test: PASS");
        end else begin
            $display("Direct-Mapped Basic Tests Summary: %0d ERRORS FOUND!", errors);
            $display("DIRECT test: FAIL");
        end
        $display("------------------------------------------------------------");

        #50;
        $finish;
    end

endmodule
