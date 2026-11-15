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
//               7. Dumps waveform to results/lru_directed.vcd for GTKWave analysis.
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
    localparam [31:0] ADDR_F = 32'h0000_0610; // Tag 3, Set 1

    reg [31:0] data_out;
    reg        hit_flag;

    // Test 10 helpers: full A,B,A,C,B,A,C,A,B,C sequence on a fresh set (Set 2)
    integer     k;
    reg [31:0]  s10_addr  [0:9];
    reg [31:0]  s10_data  [0:9];
    reg         s10_hit   [0:9];   // expected HIT(1)/MISS(0)
    reg [1:0]   s10_w0    [0:9];   // expected Way0 content: 0=invalid,1=A,2=B,3=C
    reg [1:0]   s10_w1    [0:9];   // expected Way1 content
    reg         s10_lru   [0:9];   // expected lru[2] after the access
    reg [1:0]   got_w0, got_w1;

    initial begin
        $dumpfile("results/lru_directed.vcd");
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
        u_mem.mem_array[ADDR_F[13:2]] = 32'hFFFF_0006;
        u_mem.mem_array[32'h0000_0220 >> 2] = 32'hA0A0_0011; // Set 2, tag 1 (A)
        u_mem.mem_array[32'h0000_0420 >> 2] = 32'hB0B0_0022; // Set 2, tag 2 (B)
        u_mem.mem_array[32'h0000_0620 >> 2] = 32'hC0C0_0033; // Set 2, tag 3 (C)

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
        // Test 8: Set isolation - activity in Set 1 must not disturb Set 0 LRU
        // Expected before: Set0 {A,B} lru[0]=0 ; Set1 {D,E} lru[1]=1
        // --------------------------------------------------------------------
        test_step = 8;
        $display("[Step %0d] Set isolation: Set 1 traffic must not change Set 0 LRU", test_step);

        // 8a: Miss on F in Set 1 -> evicts E (Way 1), lru[1] becomes 0
        cpu_read(ADDR_F, data_out, hit_flag);
        if (hit_flag || data_out !== 32'hFFFF_0006) begin
            $display("  FAIL: 8a expected miss on F with FFFF0006, got hit=%b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end
        if (uut_cache.lru[1] !== 1'b0 || uut_cache.lru[0] !== 1'b0) begin
            $display("  FAIL: 8a expected lru[1]=0 and lru[0]=0, got lru[1]=%b lru[0]=%b",
                     uut_cache.lru[1], uut_cache.lru[0]);
            errors = errors + 1;
        end

        // 8b: Hit on D in Set 1 -> lru[1] becomes 1, lru[0] untouched
        cpu_read(ADDR_D, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'hDDDD_0004) begin
            $display("  FAIL: 8b expected hit on D, got hit=%b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end
        if (uut_cache.lru[1] !== 1'b1 || uut_cache.lru[0] !== 1'b0) begin
            $display("  FAIL: 8b expected lru[1]=1 and lru[0]=0, got lru[1]=%b lru[0]=%b",
                     uut_cache.lru[1], uut_cache.lru[0]);
            errors = errors + 1;
        end

        // 8c: Miss on C in Set 0 -> must evict A (Way 0), not B
        cpu_read(ADDR_C, data_out, hit_flag);
        if (hit_flag || data_out !== 32'hCCCC_0003) begin
            $display("  FAIL: 8c expected miss on C, got hit=%b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end
        if (uut_cache.tag0[0] !== ADDR_C[31:9] || uut_cache.tag1[0] !== ADDR_B[31:9]) begin
            $display("  FAIL: 8c expected Way0=C and Way1=B in Set 0");
            errors = errors + 1;
        end

        // 8d: B must still HIT (proves Set 0 LRU was not disturbed by Set 1)
        cpu_read(ADDR_B, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'hBBBB_0002) begin
            $display("  FAIL: 8d B should still hit in Set 0, got hit=%b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Set 1 traffic did not disturb Set 0 LRU (A evicted, B kept)");
        end

        // --------------------------------------------------------------------
        // Test 9: A WRITE hit must also update the LRU bit
        // State before (after Test 8): Set0 Way0=C, Way1=B, lru[0]=0 (C is LRU)
        // --------------------------------------------------------------------
        test_step = 9;
        $display("[Step %0d] Write hit must update LRU (protect C, evict B)", test_step);

        // 9a: Write hit on C (Way 0) -> lru[0] becomes 1 (B is now LRU)
        cpu_write(ADDR_C, 32'h1234_5678, hit_flag);
        if (!hit_flag) begin
            $display("  FAIL: 9a expected write HIT on C, got miss");
            errors = errors + 1;
        end
        if (uut_cache.lru[0] !== 1'b1) begin
            $display("  FAIL: 9a write hit did not update LRU, expected lru[0]=1, got %b", uut_cache.lru[0]);
            errors = errors + 1;
        end

        // 9b: Read miss on A in Set 0 -> victim must be Way 1 (B), not Way 0 (C)
        cpu_read(ADDR_A, data_out, hit_flag);
        if (hit_flag || data_out !== 32'hAAAA_0001) begin
            $display("  FAIL: 9b expected miss on A with AAAA0001, got hit=%b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end
        if (uut_cache.tag0[0] !== ADDR_C[31:9] || uut_cache.tag1[0] !== ADDR_A[31:9]) begin
            $display("  FAIL: 9b expected Way0=C (kept) and Way1=A (filled over B)");
            errors = errors + 1;
        end

        // 9c: C must still HIT and return the value written in 9a
        cpu_read(ADDR_C, data_out, hit_flag);
        if (!hit_flag || data_out !== 32'h1234_5678) begin
            $display("  FAIL: 9c expected hit on C with 12345678, got hit=%b data=%h", hit_flag, data_out);
            errors = errors + 1;
        end else begin
            $display("  PASS: Write hit updated LRU (C kept with new data, B evicted)");
        end

        // --------------------------------------------------------------------
        // Test 10: Full sequence A,B,A,C,B,A,C,A,B,C on a fresh set (Set 2)
        // Matches docs/img/lru_sequence.png (hand-derived expected states).
        // Expected: M M H M M M M H M M  (2 hits, 8 misses)
        // --------------------------------------------------------------------
        test_step = 10;
        $display("[Step %0d] Full LRU sequence A,B,A,C,B,A,C,A,B,C on Set 2", test_step);

        //                 addr          data           hit  w0 w1 lru
        s10_addr[0]=32'h220; s10_data[0]=32'hA0A0_0011; s10_hit[0]=0; s10_w0[0]=1; s10_w1[0]=0; s10_lru[0]=1; // A
        s10_addr[1]=32'h420; s10_data[1]=32'hB0B0_0022; s10_hit[1]=0; s10_w0[1]=1; s10_w1[1]=2; s10_lru[1]=0; // B
        s10_addr[2]=32'h220; s10_data[2]=32'hA0A0_0011; s10_hit[2]=1; s10_w0[2]=1; s10_w1[2]=2; s10_lru[2]=1; // A
        s10_addr[3]=32'h620; s10_data[3]=32'hC0C0_0033; s10_hit[3]=0; s10_w0[3]=1; s10_w1[3]=3; s10_lru[3]=0; // C
        s10_addr[4]=32'h420; s10_data[4]=32'hB0B0_0022; s10_hit[4]=0; s10_w0[4]=2; s10_w1[4]=3; s10_lru[4]=1; // B
        s10_addr[5]=32'h220; s10_data[5]=32'hA0A0_0011; s10_hit[5]=0; s10_w0[5]=2; s10_w1[5]=1; s10_lru[5]=0; // A
        s10_addr[6]=32'h620; s10_data[6]=32'hC0C0_0033; s10_hit[6]=0; s10_w0[6]=3; s10_w1[6]=1; s10_lru[6]=1; // C
        s10_addr[7]=32'h220; s10_data[7]=32'hA0A0_0011; s10_hit[7]=1; s10_w0[7]=3; s10_w1[7]=1; s10_lru[7]=0; // A
        s10_addr[8]=32'h420; s10_data[8]=32'hB0B0_0022; s10_hit[8]=0; s10_w0[8]=2; s10_w1[8]=1; s10_lru[8]=1; // B
        s10_addr[9]=32'h620; s10_data[9]=32'hC0C0_0033; s10_hit[9]=0; s10_w0[9]=2; s10_w1[9]=3; s10_lru[9]=0; // C

        for (k = 0; k < 10; k = k + 1) begin
            cpu_read(s10_addr[k], data_out, hit_flag);

            // Decode what each way holds (tag value equals letter number 1/2/3)
            got_w0 = uut_cache.valid0[2] ? uut_cache.tag0[2][1:0] : 2'd0;
            got_w1 = uut_cache.valid1[2] ? uut_cache.tag1[2][1:0] : 2'd0;

            if (hit_flag !== s10_hit[k] || data_out !== s10_data[k]) begin
                $display("  FAIL: 10.%0d expected hit=%b data=%h, got hit=%b data=%h",
                         k+1, s10_hit[k], s10_data[k], hit_flag, data_out);
                errors = errors + 1;
            end
            if (got_w0 !== s10_w0[k] || got_w1 !== s10_w1[k]) begin
                $display("  FAIL: 10.%0d expected ways {%0d,%0d}, got {%0d,%0d}",
                         k+1, s10_w0[k], s10_w1[k], got_w0, got_w1);
                errors = errors + 1;
            end
            if (uut_cache.lru[2] !== s10_lru[k]) begin
                $display("  FAIL: 10.%0d expected lru[2]=%b, got %b", k+1, s10_lru[k], uut_cache.lru[2]);
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("  PASS: 10/10 outcomes, way contents and LRU bits match the hand-derived table");

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