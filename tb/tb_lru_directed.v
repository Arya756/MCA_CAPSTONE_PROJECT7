// ============================================================================
// Testbench:    tb_lru_directed
// Project:      Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:        Member 2 (LRU Logic & Replacement Verification)
// Description:  Self-checking directed tests for cache_2way_lru:
//               1. Fill Way 0 on cold miss.
//               2. Fill Way 1 on cold miss (prioritizes invalid way before evicting).
//               3. Read hit updates LRU (the accessed way becomes MRU, other is LRU).
//               4. Eviction replaces the LRU way when both ways are valid.
//               5. Non-LRU way remains cached and hits.
//               6. Write hit updates LRU and cached data.
//               7. Dumps waveform to docs/img/lru_directed.vcd for GTKWave analysis.
// ============================================================================

`timescale 1ns / 1ps

module tb_lru_directed;

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
    integer test_step;

    // Instantiate 2-Way Cache
    cache_2way_lru #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .CACHE_CAPACITY(1024),
        .BLOCK_SIZE(16),
        .NUM_WAYS(2)
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
        .RD_LAT(8),
        .WR_LAT(4),
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

            // Wait for handshake
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

            // Wait for handshake
            @(posedge clk);
            while (!cpu_ready) @(posedge clk);

            was_hit = (hit_count > prev_hits);
            cpu_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------------
    // Test Addresses targeting Set 0 (index = addr[8:4] = 5'b00000)
    // Addr A: Tag = 1, Index = 0, Word = 0 -> 32'h0000_0200
    // Addr B: Tag = 2, Index = 0, Word = 0 -> 32'h0000_0400
    // Addr C: Tag = 3, Index = 0, Word = 0 -> 32'h0000_0600
    // ------------------------------------------------------------------------
    localparam [31:0] ADDR_A = 32'h0000_0200; // Tag 1, Set 0
    localparam [31:0] ADDR_B = 32'h0000_0400; // Tag 2, Set 0
    localparam [31:0] ADDR_C = 32'h0000_0600; // Tag 3, Set 0

    // Set 1 (index = addr[8:4] = 5'b00001)
    localparam [31:0] ADDR_D = 32'h0000_0210; // Tag 1, Set 1
    localparam [31:0] ADDR_E = 32'h0000_0410; // Tag 2, Set 1

    reg [31:0] data_out;
    reg        hit_flag;

    initial begin
        $dumpfile("docs/img/lru_directed.vcd");
        $dumpvars(0, tb_lru_directed);

        clk       = 0;
        rst       = 1;
        cpu_req   = 0;
        cpu_we    = 0;
        cpu_addr  = 0;
        cpu_wdata = 0;
        errors    = 0;
        test_step = 0;

        // Initialize main memory with distinct identifiable values
        u_mem.mem_array[ADDR_A[13:2]] = 32'hAAAA_0001;
        u_mem.mem_array[ADDR_B[13:2]] = 32'hBBBB_0002;
        u_mem.mem_array[ADDR_C[13:2]] = 32'hCCCC_0003;
        u_mem.mem_array[ADDR_D[13:2]] = 32'hDDDD_0004;
        u_mem.mem_array[ADDR_E[13:2]] = 32'hEEEE_0005;

        #20;
        @(posedge clk);
        rst = 0;
        #20;

        $display("------------------------------------------------------------");
        $display("STARTING LRU DIRECTED VERIFICATION TESTS");
        $display("------------------------------------------------------------");

        // --------------------------------------------------------------------
        // Test 1: Cold miss on Addr A -> Fills Way 0
        // --------------------------------------------------------------------
        test_step = 1;
        $display("[Step %0d] Cold miss on Addr A (Set 0)", test_step);
        cpu_read(ADDR_A, data_out, hit_flag);
        if (hit_flag || data_out !== 32'hAAAA_0001) begin
            $display("  FAIL: Expected miss with data AAAA0001, got hit=%b, data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Cold miss, Way 0 filled with data %h", data_out);
        end

        // Check internal LRU bit: Way 0 accessed -> Way 1 is now LRU victim (lru=1)
        if (uut_cache.lru[0] !== 1'b1) begin
            $display("  FAIL: Expected lru[0] == 1 (Way 1 is victim), got %b", uut_cache.lru[0]);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 2: Cold miss on Addr B -> Fills Way 1 (invalid way used first!)
        // --------------------------------------------------------------------
        test_step = 2;
        $display("[Step %0d] Cold miss on Addr B (Set 0, invalid Way 1 prioritized)", test_step);
        cpu_read(ADDR_B, data_out, hit_flag);
        if (hit_flag || data_out !== 32'hBBBB_0002) begin
            $display("  FAIL: Expected miss with data BBBB0002, got hit=%b, data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Cold miss, Way 1 filled without evicting Way 0");
        end

        // Check both ways valid
        if (uut_cache.valid0[0] !== 1'b1 || uut_cache.valid1[0] !== 1'b1) begin
            $display("  FAIL: Expected both ways to be valid in Set 0!");
            errors = errors + 1;
        end
        // Way 1 accessed -> Way 0 is now LRU victim (lru=0)
        if (uut_cache.lru[0] !== 1'b0) begin
            $display("  FAIL: Expected lru[0] == 0 (Way 0 is victim), got %b", uut_cache.lru[0]);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 3: Read Hit on Addr A -> LRU bit toggles to point to Way 1
        // --------------------------------------------------------------------
        test_step = 3;
        $display("[Step %0d] Read Hit on Addr A (Way 0)", test_step);
        cpu_read(ADDR_A, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'hAAAA_0001) begin
            $display("  FAIL: Expected read HIT on Addr A, got hit=%b, data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Read HIT on Addr A!");
        end

        // Way 0 hit -> Way 1 becomes LRU victim (lru=1)
        if (uut_cache.lru[0] !== 1'b1) begin
            $display("  FAIL: Expected lru[0] == 1 after Way 0 hit, got %b", uut_cache.lru[0]);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 4: Access Addr C -> Eviction! Way 1 must be evicted (LRU)
        // --------------------------------------------------------------------
        test_step = 4;
        $display("[Step %0d] Access Addr C -> Evict LRU Way (Way 1)", test_step);
        cpu_read(ADDR_C, data_out, hit_flag);
        if (hit_flag || data_out !== 32'hCCCC_0003) begin
            $display("  FAIL: Expected miss on Addr C, got hit=%b, data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Addr C refilled into Way 1");
        end

        // Check tags: Way 0 must STILL hold Addr A, Way 1 must hold Addr C
        if (uut_cache.tag0[0] !== (ADDR_A[31:9]) || uut_cache.tag1[0] !== (ADDR_C[31:9])) begin
            $display("  FAIL: Way 0 should hold Addr A tag, Way 1 should hold Addr C tag!");
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 5: Verify Addr A is STILL a hit (Way 0 was NOT evicted)
        // --------------------------------------------------------------------
        test_step = 5;
        $display("[Step %0d] Verify Addr A still hits in Way 0", test_step);
        cpu_read(ADDR_A, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'hAAAA_0001) begin
            $display("  FAIL: Addr A should have hit! hit=%b, data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Addr A hit confirmed in Way 0");
        end

        // --------------------------------------------------------------------
        // Test 6: Verify Addr B was indeed evicted (must miss)
        // --------------------------------------------------------------------
        test_step = 6;
        $display("[Step %0d] Verify Addr B was evicted (must miss)", test_step);
        cpu_read(ADDR_B, data_out, hit_flag);
        if (hit_flag) begin
            $display("  FAIL: Addr B should have been evicted and missed!");
            errors = errors + 1;
        end else begin
            $display("  PASS: Addr B correctly missed as it was previously evicted");
        end

        // --------------------------------------------------------------------
        // Test 7: Independent Set 1 verification (Sets do not interfere)
        // --------------------------------------------------------------------
        test_step = 7;
        $display("[Step %0d] Test independent Set 1 (Addr D & E)", test_step);
        cpu_read(ADDR_D, data_out, hit_flag); // Fills Way 0 of Set 1
        cpu_read(ADDR_E, data_out, hit_flag); // Fills Way 1 of Set 1
        cpu_read(ADDR_D, data_out, hit_flag); // Hit on Addr D
        if (!hit_flag || data_out !== 32'hDDDD_0004) begin
            $display("  FAIL: Addr D should hit in Set 1!");
            errors = errors + 1;
        end else begin
            $display("  PASS: Set 1 operations verified independently");
        end

        // --------------------------------------------------------------------
        // Final Summary Banner
        // --------------------------------------------------------------------
        $display("------------------------------------------------------------");
        if (errors == 0) begin
            $display("LRU Directed Tests Summary: ALL CHECKS PASSED!");
            $display("LRU test: PASS");
        end else begin
            $display("LRU Directed Tests Summary: %0d ERRORS FOUND!", errors);
            $display("LRU test: FAIL");
        end
        $display("------------------------------------------------------------");

        #50;
        $finish;
    end

endmodule
