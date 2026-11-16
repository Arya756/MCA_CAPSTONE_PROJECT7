// ============================================================================
// Testbench:    tb_compare
// Project:      Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:        Member 4 (Traces, Comparison Testbench, Scripts)
// Description:  Executes access traces through BOTH cache_2way_lru and
//               cache_direct in separate, independent passes against an
//               architectural golden memory model.
//               - Runs all 9 deterministic traces (7 original + 2 extensions).
//               - Independent cycle timing measured per access from request
//                 to cpu_ready, accumulated per design without interference.
//               - Validates data correctness against golden memory (0 mismatches).
//               - Compares hits, misses, hit rates, and total cycle counts.
//               - Appends benchmark rows to results/results.csv.
// ============================================================================

`timescale 1ns / 1ps

`ifndef RD_LAT
`define RD_LAT 8
`endif

`ifndef WR_LAT
`define WR_LAT 4
`endif

module tb_compare;

    reg clk;
    reg rst_2w;
    reg rst_dir;

    // ------------------------------------------------------------------------
    // Signals for 2-Way Set-Associative Cache
    // ------------------------------------------------------------------------
    reg         cpu_req_2w;
    reg         cpu_we_2w;
    reg  [31:0] cpu_addr_2w;
    reg  [31:0] cpu_wdata_2w;
    wire        cpu_ready_2w;
    wire [31:0] cpu_rdata_2w;

    wire        mem_req_2w;
    wire        mem_we_2w;
    wire [31:0] mem_addr_2w;
    wire [31:0] mem_wdata_2w;
    wire        mem_ready_2w;
    wire [31:0] mem_rdata_2w;

    wire [31:0] hit_count_2w;
    wire [31:0] miss_count_2w;
    wire [31:0] cycle_count_2w;

    // ------------------------------------------------------------------------
    // Signals for Direct-Mapped Cache Baseline
    // ------------------------------------------------------------------------
    reg         cpu_req_dir;
    reg         cpu_we_dir;
    reg  [31:0] cpu_addr_dir;
    reg  [31:0] cpu_wdata_dir;
    wire        cpu_ready_dir;
    wire [31:0] cpu_rdata_dir;

    wire        mem_req_dir;
    wire        mem_we_dir;
    wire [31:0] mem_addr_dir;
    wire [31:0] mem_wdata_dir;
    wire        mem_ready_dir;
    wire [31:0] mem_rdata_dir;

    wire [31:0] hit_count_dir;
    wire [31:0] miss_count_dir;
    wire [31:0] cycle_count_dir;

    // ------------------------------------------------------------------------
    // Architectural Golden Memory Model (4096 words = 16 KB)
    // ------------------------------------------------------------------------
    reg [31:0] golden_mem [0:4095];
    integer total_mismatches;
    integer trace_mismatches;

    // Per-trace access, hit, miss, and accumulated cycle counters
    integer trace_accesses_2w;
    integer trace_accesses_dir;
    integer saved_hits_2w;
    integer saved_misses_2w;
    integer saved_hits_dir;
    integer saved_misses_dir;
    integer acc_cycles_2w;
    integer acc_cycles_dir;

    // Diagnostics for latency sanity checks
    integer measured_read_hit_lat;
    integer measured_read_miss_lat;
    reg [1023:0] csv_filename;

    // ------------------------------------------------------------------------
    // DUT Instantiations
    // ------------------------------------------------------------------------
    cache_2way_lru #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .CACHE_CAPACITY(1024),
        .BLOCK_SIZE(16),
        .NUM_WAYS(2)
    ) dut_2way (
        .clk(clk),
        .rst(rst_2w),
        .cpu_req(cpu_req_2w),
        .cpu_we(cpu_we_2w),
        .cpu_addr(cpu_addr_2w),
        .cpu_wdata(cpu_wdata_2w),
        .cpu_ready(cpu_ready_2w),
        .cpu_rdata(cpu_rdata_2w),
        .mem_req(mem_req_2w),
        .mem_we(mem_we_2w),
        .mem_addr(mem_addr_2w),
        .mem_wdata(mem_wdata_2w),
        .mem_ready(mem_ready_2w),
        .mem_rdata(mem_rdata_2w),
        .hit_count(hit_count_2w),
        .miss_count(miss_count_2w),
        .cycle_count(cycle_count_2w)
    );

    main_memory #(
        .RD_LAT(`RD_LAT),
        .WR_LAT(`WR_LAT),
        .MEM_WORDS(4096)
    ) mem_2way_inst (
        .clk(clk),
        .rst(rst_2w),
        .mem_req(mem_req_2w),
        .mem_we(mem_we_2w),
        .mem_addr(mem_addr_2w),
        .mem_wdata(mem_wdata_2w),
        .mem_ready(mem_ready_2w),
        .mem_rdata(mem_rdata_2w)
    );

    cache_direct #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .CACHE_CAPACITY(1024),
        .BLOCK_SIZE(16)
    ) dut_direct (
        .clk(clk),
        .rst(rst_dir),
        .cpu_req(cpu_req_dir),
        .cpu_we(cpu_we_dir),
        .cpu_addr(cpu_addr_dir),
        .cpu_wdata(cpu_wdata_dir),
        .cpu_ready(cpu_ready_dir),
        .cpu_rdata(cpu_rdata_dir),
        .mem_req(mem_req_dir),
        .mem_we(mem_we_dir),
        .mem_addr(mem_addr_dir),
        .mem_wdata(mem_wdata_dir),
        .mem_ready(mem_ready_dir),
        .mem_rdata(mem_rdata_dir),
        .hit_count(hit_count_dir),
        .miss_count(miss_count_dir),
        .cycle_count(cycle_count_dir)
    );

    main_memory #(
        .RD_LAT(`RD_LAT),
        .WR_LAT(`WR_LAT),
        .MEM_WORDS(4096)
    ) mem_direct_inst (
        .clk(clk),
        .rst(rst_dir),
        .mem_req(mem_req_dir),
        .mem_we(mem_we_dir),
        .mem_addr(mem_addr_dir),
        .mem_wdata(mem_wdata_dir),
        .mem_ready(mem_ready_dir),
        .mem_rdata(mem_rdata_dir)
    );

    // Clock generator (10 ns period -> 100 MHz)
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Initialize Golden Memory and Main Memory Backing Arrays
    // ------------------------------------------------------------------------
    task init_memories;
        integer i;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                golden_mem[i]               = 32'h1000_0000 + (i * 4);
                mem_2way_inst.mem_array[i]   = 32'h1000_0000 + (i * 4);
                mem_direct_inst.mem_array[i] = 32'h1000_0000 + (i * 4);
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Execute a single transaction on 2-Way Cache
    // ------------------------------------------------------------------------
    task execute_transaction_2w;
        input        is_write;
        input [31:0] addr;
        input [31:0] wdata;
        reg   [31:0] golden_val;
        integer      lat;
        reg   [31:0] prev_hits;
        begin
            trace_accesses_2w = trace_accesses_2w + 1;
            prev_hits = hit_count_2w;
            lat = 0;

            @(posedge clk);
            cpu_addr_2w  = addr;
            cpu_wdata_2w = wdata;
            cpu_we_2w    = is_write;
            cpu_req_2w   = 1'b1;

            // Count cycles until cpu_ready_2w is asserted
            while (!cpu_ready_2w) begin
                @(posedge clk);
                lat = lat + 1;
            end

            // cpu_ready_2w is active
            if (is_write) begin
                golden_mem[addr[13:2]] = wdata;
            end else begin
                golden_val = golden_mem[addr[13:2]];
                if (cpu_rdata_2w !== golden_val) begin
                    $display("ERROR [2-Way]: Data mismatch at addr 0x%08h! Expected 0x%08h, got 0x%08h",
                             addr, golden_val, cpu_rdata_2w);
                    trace_mismatches = trace_mismatches + 1;
                    total_mismatches = total_mismatches + 1;
                end
                if (hit_count_2w > prev_hits)
                    measured_read_hit_lat = lat;
                else
                    measured_read_miss_lat = lat;
            end

            cpu_req_2w    = 1'b0;
            acc_cycles_2w = acc_cycles_2w + lat;
        end
    endtask

    // ------------------------------------------------------------------------
    // Execute a single transaction on Direct-Mapped Cache
    // ------------------------------------------------------------------------
    task execute_transaction_dir;
        input        is_write;
        input [31:0] addr;
        input [31:0] wdata;
        reg   [31:0] golden_val;
        integer      lat;
        begin
            trace_accesses_dir = trace_accesses_dir + 1;
            lat = 0;

            @(posedge clk);
            cpu_addr_dir  = addr;
            cpu_wdata_dir = wdata;
            cpu_we_dir    = is_write;
            cpu_req_dir   = 1'b1;

            // Count cycles until cpu_ready_dir is asserted
            while (!cpu_ready_dir) begin
                @(posedge clk);
                lat = lat + 1;
            end

            // cpu_ready_dir is active
            if (is_write) begin
                golden_mem[addr[13:2]] = wdata;
            end else begin
                golden_val = golden_mem[addr[13:2]];
                if (cpu_rdata_dir !== golden_val) begin
                    $display("ERROR [Direct]: Data mismatch at addr 0x%08h! Expected 0x%08h, got 0x%08h",
                             addr, golden_val, cpu_rdata_dir);
                    trace_mismatches = trace_mismatches + 1;
                    total_mismatches = total_mismatches + 1;
                end
            end

            cpu_req_dir    = 1'b0;
            acc_cycles_dir = acc_cycles_dir + lat;
        end
    endtask

    // ------------------------------------------------------------------------
    // Run Trace through BOTH Designs in Independent Sequential Passes
    // ------------------------------------------------------------------------
    task run_trace_file;
        input [1023:0] trace_path;
        input [255:0]  trace_name;
        integer file_fd, scan_status, csv_fd;
        reg [8*1024:1] line_buf;
        reg [8*32:1]   op_str;
        reg [31:0]     addr_val;
        reg [31:0]     wdata_val;
        real           hit_rate_2w;
        real           hit_rate_dir;
        begin
            $display("\n============================================================");
            $display("RUNNING TRACE: %0s", trace_name);
            $display("============================================================");

            // ----------------------------------------------------------------
            // PASS 1: 2-Way Set-Associative Cache
            // ----------------------------------------------------------------
            trace_accesses_2w = 0;
            acc_cycles_2w     = 0;
            init_memories();

            @(posedge clk);
            rst_2w     = 1'b1;
            cpu_req_2w = 1'b0;
            cpu_we_2w  = 1'b0;
            #20;
            @(posedge clk);
            rst_2w = 1'b0;
            #20;

            file_fd = $fopen(trace_path, "r");
            if (file_fd == 0) begin
                $display("ERROR: Failed to open trace file: %0s", trace_path);
                total_mismatches = total_mismatches + 1;
            end else begin
                while ($fgets(line_buf, file_fd)) begin
                    if (line_buf[8*1024:8*1024-7] != "#" && line_buf[8*1024:8*1024-7] != "\n") begin
                        scan_status = $sscanf(line_buf, "%s %h %h", op_str, addr_val, wdata_val);
                        if (scan_status >= 2) begin
                            if (op_str == "R")
                                execute_transaction_2w(1'b0, addr_val, 32'h0);
                            else if (op_str == "W")
                                execute_transaction_2w(1'b1, addr_val, wdata_val);
                        end
                    end
                end
                $fclose(file_fd);
            end

            saved_hits_2w   = hit_count_2w;
            saved_misses_2w = miss_count_2w;

            // ----------------------------------------------------------------
            // PASS 2: Direct-Mapped Baseline Cache
            // ----------------------------------------------------------------
            trace_accesses_dir = 0;
            acc_cycles_dir     = 0;
            init_memories();

            @(posedge clk);
            rst_dir     = 1'b1;
            cpu_req_dir = 1'b0;
            cpu_we_dir  = 1'b0;
            #20;
            @(posedge clk);
            rst_dir = 1'b0;
            #20;

            file_fd = $fopen(trace_path, "r");
            if (file_fd != 0) begin
                while ($fgets(line_buf, file_fd)) begin
                    if (line_buf[8*1024:8*1024-7] != "#" && line_buf[8*1024:8*1024-7] != "\n") begin
                        scan_status = $sscanf(line_buf, "%s %h %h", op_str, addr_val, wdata_val);
                        if (scan_status >= 2) begin
                            if (op_str == "R")
                                execute_transaction_dir(1'b0, addr_val, 32'h0);
                            else if (op_str == "W")
                                execute_transaction_dir(1'b1, addr_val, wdata_val);
                        end
                    end
                end
                $fclose(file_fd);
            end

            saved_hits_dir   = hit_count_dir;
            saved_misses_dir = miss_count_dir;

            // ----------------------------------------------------------------
            // Compute Hit Rates and Display Results
            // ----------------------------------------------------------------
            hit_rate_2w  = (trace_accesses_2w > 0) ?  (saved_hits_2w * 100.0) / trace_accesses_2w  : 0.0;
            hit_rate_dir = (trace_accesses_dir > 0) ? (saved_hits_dir * 100.0) / trace_accesses_dir : 0.0;

            $display("RESULTS for %0s (Total Accesses: %0d, Mismatches: %0d):",
                     trace_name, trace_accesses_2w, trace_mismatches);
            $display("  [2-Way LRU]   Hits: %4d | Misses: %4d | Hit Rate: %6.2f%% | Cycles: %6d",
                     saved_hits_2w, saved_misses_2w, hit_rate_2w, acc_cycles_2w);
            $display("  [Direct-Map]  Hits: %4d | Misses: %4d | Hit Rate: %6.2f%% | Cycles: %6d",
                     saved_hits_dir, saved_misses_dir, hit_rate_dir, acc_cycles_dir);

            // Special Sanity Check Print for seq_stream
            if (trace_name == "seq_stream") begin
                $display("  --> [Sanity Check: seq_stream]");
                $display("      Measured Read Hit Cost:  %0d cycles", measured_read_hit_lat);
                $display("      Measured Read Miss Cost: %0d cycles", measured_read_miss_lat);
                $display("      Formula: Total Cycles = (Hits * %0d) + (Misses * %0d)",
                         measured_read_hit_lat, measured_read_miss_lat);
                $display("      2-Way:  %0d*%0d + %0d*%0d = %0d cycles (matches %0d: %s)",
                         saved_hits_2w, measured_read_hit_lat, saved_misses_2w, measured_read_miss_lat,
                         (saved_hits_2w*measured_read_hit_lat + saved_misses_2w*measured_read_miss_lat),
                         acc_cycles_2w,
                         (acc_cycles_2w == (saved_hits_2w*measured_read_hit_lat + saved_misses_2w*measured_read_miss_lat)) ? "EXACT" : "MISMATCH");
                $display("      Direct: %0d*%0d + %0d*%0d = %0d cycles (matches %0d: %s)",
                         saved_hits_dir, measured_read_hit_lat, saved_misses_dir, measured_read_miss_lat,
                         (saved_hits_dir*measured_read_hit_lat + saved_misses_dir*measured_read_miss_lat),
                         acc_cycles_dir,
                         (acc_cycles_dir == (saved_hits_dir*measured_read_hit_lat + saved_misses_dir*measured_read_miss_lat)) ? "EXACT" : "MISMATCH");
            end

            // Append rows to results CSV
            csv_fd = $fopen(csv_filename, "a");
            if (csv_fd != 0) begin
                $fdisplay(csv_fd, "%0s,2way,%0d,%0d,%0d,%0.2f,%0d",
                          trace_name, trace_accesses_2w, saved_hits_2w, saved_misses_2w, hit_rate_2w, acc_cycles_2w);
                $fdisplay(csv_fd, "%0s,direct,%0d,%0d,%0d,%0.2f,%0d",
                          trace_name, trace_accesses_dir, saved_hits_dir, saved_misses_dir, hit_rate_dir, acc_cycles_dir);
                $fclose(csv_fd);
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Simulation Execution
    // ------------------------------------------------------------------------
    reg [1023:0] cli_trace;
    integer init_csv_fd;

    initial begin
        clk                     = 0;
        rst_2w                  = 1;
        rst_dir                 = 1;
        total_mismatches        = 0;
        trace_mismatches        = 0;
        measured_read_hit_lat   = 0;
        measured_read_miss_lat  = 0;

        if (!$value$plusargs("CSV=%s", csv_filename)) begin
            csv_filename = "results/results.csv";
        end

        // Initialize CSV file with clean header
        if (!$value$plusargs("TRACE=%s", cli_trace)) begin
            init_csv_fd = $fopen(csv_filename, "w");
            if (init_csv_fd != 0) begin
                $fdisplay(init_csv_fd, "trace,design,accesses,hits,misses,hit_rate,cycles");
                $fclose(init_csv_fd);
            end
        end

        if ($value$plusargs("TRACE=%s", cli_trace)) begin
            run_trace_file(cli_trace, cli_trace);
        end else begin
            // Run all 9 standard traces (7 original + 2 Member 4 extensions)
            run_trace_file("traces/seq_stream.txt",  "seq_stream");
            run_trace_file("traces/small_loop.txt",  "small_loop");
            run_trace_file("traces/pingpong.txt",    "pingpong");
            run_trace_file("traces/cyclic3.txt",     "cyclic3");
            run_trace_file("traces/strided.txt",     "strided");
            run_trace_file("traces/random.txt",      "random");
            run_trace_file("traces/mixed_rw.txt",    "mixed_rw");
            run_trace_file("traces/large_loop.txt",  "large_loop");
            run_trace_file("traces/hot_stream.txt",  "hot_stream");
        end

        $display("\n============================================================");
        $display("FINAL COMPARISON REGRESSION SUMMARY");
        $display("============================================================");
        $display("Total Data Verification Mismatches: %0d", total_mismatches);
        $display("mismatches: %0d", total_mismatches);
        if (total_mismatches == 0) begin
            $display("Compare test: PASS");
        end else begin
            $display("Compare test: FAIL");
        end
        $display("============================================================\n");

        #50;
        $finish;
    end

endmodule
