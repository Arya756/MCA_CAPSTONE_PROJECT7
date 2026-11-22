// ============================================================================
// Testbench:    tb_lru_random
// Project:      Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:        Member 2 (LRU Logic & Replacement Verification)
// Description:  Pseudo-random test against a software reference model.
//
//   The SAME random sequence of reads and writes is sent to:
//     (1) the real RTL  (cache_2way_lru + main_memory), and
//     (2) a small behavioural reference model of a 2-way LRU,
//         write-through, no-write-allocate cache (written from the spec,
//         not copied from the RTL).
//
//   After EVERY access the testbench compares:
//     - hit / miss result
//     - returned data word (reads)
//     - valid bits, tags and LRU bit of the accessed set
//   At the end it also compares hit/miss counters and the whole main memory.
//
//   Addresses are drawn from a small pool (NSETS sets x NTAGS tags per set,
//   NTAGS > 2 ways) so that conflicts and LRU evictions happen constantly.
//   The seed is fixed, so every run is reproducible.
// ============================================================================

`timescale 1ns / 1ps

module tb_lru_random;

    // ------------------------------------------------------------------------
    // Test configuration (change SEED to explore other sequences)
    // ------------------------------------------------------------------------
    parameter integer NUM_OPS = 5000;
    parameter integer SEED    = 32'h2026_1124;
    parameter integer NSETS   = 6;     // sets 0..5 are used
    parameter integer NTAGS   = 5;     // 5 different blocks compete for 2 ways
    parameter integer WR_THR  = 90;    // write if random byte < 90  (~35% writes)

    reg         clk;
    reg         rst;

    reg         cpu_req;
    reg         cpu_we;
    reg  [31:0] cpu_addr;
    reg  [31:0] cpu_wdata;
    wire        cpu_ready;
    wire [31:0] cpu_rdata;

    wire        mem_req;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    wire [31:0] hit_count;
    wire [31:0] miss_count;
    wire [31:0] cycle_count;

    // ------------------------------------------------------------------------
    // Design under test
    // ------------------------------------------------------------------------
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

    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Reference model state (independent of the RTL)
    // ------------------------------------------------------------------------
    reg        m_valid0 [0:31];
    reg        m_valid1 [0:31];
    reg [22:0] m_tag0   [0:31];
    reg [22:0] m_tag1   [0:31];
    reg        m_lru    [0:31];   // value = way that is LRU (victim when both valid)
    reg [31:0] m_mem    [0:4095]; // golden main memory

    integer m_hits, m_misses, m_evictions, n_reads, n_writes;
    integer errors;

    // ------------------------------------------------------------------------
    // CPU helper tasks (same handshake as the directed testbench)
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

    // ------------------------------------------------------------------------
    // Reference model: one access (rules taken from the design specification)
    //   hit  -> lru = other way
    //   miss -> read: victim = invalid way0, else invalid way1, else lru;
    //                 fill victim; lru = other way
    //           write: no allocation, LRU unchanged
    //   write-through: memory is always updated on a write
    // ------------------------------------------------------------------------
    task model_access;
        input  [31:0] addr;
        input         we;
        input  [31:0] wdata;
        output        exp_hit;
        output [31:0] exp_data;
        reg [4:0]  idx;
        reg [22:0] tg;
        reg        h0, h1, v;
        begin
            idx = addr[8:4];
            tg  = addr[31:9];
            h0  = m_valid0[idx] && (m_tag0[idx] == tg);
            h1  = m_valid1[idx] && (m_tag1[idx] == tg);
            exp_hit = h0 | h1;

            if (exp_hit) begin
                m_lru[idx] = h1 ? 1'b0 : 1'b1;      // other way becomes LRU
                m_hits = m_hits + 1;
            end else begin
                m_misses = m_misses + 1;
                if (!we) begin
                    if (!m_valid0[idx])      v = 1'b0;
                    else if (!m_valid1[idx]) v = 1'b1;
                    else begin
                        v = m_lru[idx];
                        m_evictions = m_evictions + 1;
                    end
                    if (v == 1'b0) begin
                        m_valid0[idx] = 1'b1;
                        m_tag0[idx]   = tg;
                    end else begin
                        m_valid1[idx] = 1'b1;
                        m_tag1[idx]   = tg;
                    end
                    m_lru[idx] = ~v;
                end
                // write miss: nothing changes in the cache (no-write-allocate)
            end

            if (we) begin
                m_mem[addr[13:2]] = wdata;
                exp_data = wdata;
            end else begin
                exp_data = m_mem[addr[13:2]];
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Compare the RTL state of one set with the reference model
    // ------------------------------------------------------------------------
    task check_set;
        input [4:0] idx;
        input integer op_no;
        begin
            if (uut_cache.valid0[idx] !== m_valid0[idx] ||
                uut_cache.valid1[idx] !== m_valid1[idx] ||
                (m_valid0[idx] && uut_cache.tag0[idx] !== m_tag0[idx]) ||
                (m_valid1[idx] && uut_cache.tag1[idx] !== m_tag1[idx])) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL: op %0d set %0d contents differ: RTL v0=%b v1=%b t0=%0d t1=%0d | MODEL v0=%b v1=%b t0=%0d t1=%0d",
                             op_no, idx,
                             uut_cache.valid0[idx], uut_cache.valid1[idx], uut_cache.tag0[idx], uut_cache.tag1[idx],
                             m_valid0[idx], m_valid1[idx], m_tag0[idx], m_tag1[idx]);
            end
            if (uut_cache.lru[idx] !== m_lru[idx]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL: op %0d set %0d LRU bit differs: RTL=%b MODEL=%b",
                             op_no, idx, uut_cache.lru[idx], m_lru[idx]);
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Main stimulus
    // ------------------------------------------------------------------------
    integer     seed;
    integer     n, w;
    reg [31:0]  r1, r2, r3, r4, wd;
    reg [31:0]  a_set, a_tag, a_word, addr;
    reg         is_wr;
    reg         e_hit, d_hit;
    reg [31:0]  e_data, d_data;

    initial begin
        clk = 0; rst = 1;
        cpu_req = 0; cpu_we = 0; cpu_addr = 0; cpu_wdata = 0;
        errors = 0; m_hits = 0; m_misses = 0; m_evictions = 0;
        n_reads = 0; n_writes = 0;
        seed = SEED;

        $display("------------------------------------------------------------");
        $display("STARTING RANDOM REFERENCE-MODEL TEST (%0d ops, seed %0d)", NUM_OPS, SEED);
        $display("------------------------------------------------------------");

        #20;
        @(posedge clk);
        rst = 0;
        repeat (3) @(posedge clk);

        // Fill BOTH memories with the same non-trivial pattern, clear the model cache
        for (w = 0; w < 4096; w = w + 1) begin
            u_mem.mem_array[w] = 32'hC0DE_0000 + (w * 7);
            m_mem[w]           = 32'hC0DE_0000 + (w * 7);
        end
        for (w = 0; w < 32; w = w + 1) begin
            m_valid0[w] = 1'b0;  m_valid1[w] = 1'b0;
            m_tag0[w]   = 23'd0; m_tag1[w]   = 23'd0;
            m_lru[w]    = 1'b0;
        end

        for (n = 0; n < NUM_OPS; n = n + 1) begin
            r1 = $random(seed);
            r2 = $random(seed);
            r3 = $random(seed);
            r4 = $random(seed);
            wd = $random(seed);

            a_set  = r1[7:0] % NSETS;
            a_tag  = r2[7:0] % NTAGS;
            a_word = r3[1:0];
            is_wr  = (r4[7:0] < WR_THR);
            addr   = (a_tag << 9) | (a_set << 4) | (a_word << 2);

            model_access(addr, is_wr, wd, e_hit, e_data);

            if (is_wr) begin
                n_writes = n_writes + 1;
                cpu_write(addr, wd, d_hit);
            end else begin
                n_reads = n_reads + 1;
                cpu_read(addr, d_data, d_hit);
            end

            if (d_hit !== e_hit) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL: op %0d (%s addr %h) hit/miss differs: RTL=%b MODEL=%b",
                             n, is_wr ? "WR" : "RD", addr, d_hit, e_hit);
            end
            if (!is_wr && d_data !== e_data) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL: op %0d (RD addr %h) data differs: RTL=%h MODEL=%h",
                             n, addr, d_data, e_data);
            end
            check_set(a_set[4:0], n);
        end

        // Final end-of-test checks
        if (hit_count !== m_hits || miss_count !== m_misses) begin
            errors = errors + 1;
            $display("  FAIL: counters differ: RTL hits=%0d misses=%0d | MODEL hits=%0d misses=%0d",
                     hit_count, miss_count, m_hits, m_misses);
        end
        for (w = 0; w < 4096; w = w + 1) begin
            if (u_mem.mem_array[w] !== m_mem[w]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL: main memory word %0d differs: RTL=%h MODEL=%h",
                             w, u_mem.mem_array[w], m_mem[w]);
            end
        end

        $display("Ops: %0d (reads %0d, writes %0d) | model hits %0d, misses %0d, LRU evictions %0d",
                 NUM_OPS, n_reads, n_writes, m_hits, m_misses, m_evictions);
        $display("------------------------------------------------------------");
        if (errors == 0) begin
            $display("Random reference-model test: every access matched the model");
            $display("Random test: PASS");
        end else begin
            $display("Random reference-model test: %0d mismatches", errors);
            $display("Random test: FAIL");
        end
        $display("------------------------------------------------------------");
        $finish;
    end

    // Watchdog: abort if the DUT ever hangs
    initial begin
        #200000000;
        $display("Random test: FAIL (timeout, DUT did not respond)");
        $finish;
    end

endmodule
