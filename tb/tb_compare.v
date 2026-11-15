// ============================================================================
// Testbench:    tb_compare
// Project:      Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:        Member 4 (Traces, Comparison Testbench, Scripts)
// Description:  Executes access traces concurrently through BOTH cache_2way_lru
//               and cache_direct against an architectural golden memory model.
//               - Validates functional data correctness (counts mismatches).
//               - Compares hits, misses, hit rate (%), and cycle counts.
//               - Appends rows to results/results.csv for performance evaluation.
// ============================================================================

`timescale 1ns / 1ps

module tb_compare;

    reg clk;
    reg rst;

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
    integer trace_accesses;

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
        .rst(rst),
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
        .RD_LAT(8),
        .WR_LAT(4),
        .MEM_WORDS(4096)
    ) mem_2way_inst (
        .clk(clk),
        .rst(rst),
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
        .rst(rst),
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
        .RD_LAT(8),
        .WR_LAT(4),
        .MEM_WORDS(4096)
    ) mem_direct_inst (
        .clk(clk),
        .rst(rst),
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
    // Reset and Memory Initialization
    // ------------------------------------------------------------------------
    task reset_system;
        integer i;
        begin
            @(posedge clk);
            rst          = 1'b1;
            cpu_req_2w   = 1'b0;
            cpu_we_2w    = 1'b0;
            cpu_addr_2w  = 32'h0;
            cpu_wdata_2w = 32'h0;
            cpu_req_dir   = 1'b0;
            cpu_we_dir    = 1'b0;
            cpu_addr_dir  = 32'h0;
            cpu_wdata_dir = 32'h0;

            for (i = 0; i < 4096; i = i + 1) begin
                golden_mem[i]               = 32'h1000_0000 + (i * 4);
                mem_2way_inst.mem_array[i]   = 32'h1000_0000 + (i * 4);
                mem_direct_inst.mem_array[i] = 32'h1000_0000 + (i * 4);
            end

            #20;
            @(posedge clk);
            rst = 1'b0;
            #20;
        end
    endtask

    // ------------------------------------------------------------------------
    // Task to run one memory transaction through both caches
    // ------------------------------------------------------------------------
    task execute_transaction;
        input        is_write;
        input [31:0] addr;
        input [31:0] wdata;
        reg [31:0] golden_val;
        begin
            trace_accesses = trace_accesses + 1;

            if (is_write) begin
                golden_mem[addr[13:2]] = wdata;

                // 2-Way Cache Write
                @(posedge clk);
                cpu_addr_2w  = addr;
                cpu_wdata_2w = wdata;
                cpu_we_2w    = 1'b1;
                cpu_req_2w   = 1'b1;
                @(posedge clk);
                while (!cpu_ready_2w) @(posedge clk);
                cpu_req_2w   = 1'b0;

                // Direct-Mapped Cache Write
                @(posedge clk);
                cpu_addr_dir  = addr;
                cpu_wdata_dir = wdata;
                cpu_we_dir    = 1'b1;
                cpu_req_dir   = 1'b1;
                @(posedge clk);
                while (!cpu_ready_dir) @(posedge clk);
                cpu_req_dir   = 1'b0;
            end else begin
                golden_val = golden_mem[addr[13:2]];

                // 2-Way Cache Read
                @(posedge clk);
                cpu_addr_2w = addr;
                cpu_we_2w   = 1'b0;
                cpu_req_2w  = 1'b1;
                @(posedge clk);
                while (!cpu_ready_2w) @(posedge clk);
                if (cpu_rdata_2w !== golden_val) begin
                    $display("ERROR [2-Way]: Mismatch at addr 0x%08h! Expected 0x%08h, got 0x%08h",
                             addr, golden_val, cpu_rdata_2w);
                    trace_mismatches = trace_mismatches + 1;
                    total_mismatches = total_mismatches + 1;
                end
                cpu_req_2w = 1'b0;

                // Direct-Mapped Cache Read
                @(posedge clk);
                cpu_addr_dir = addr;
                cpu_we_dir   = 1'b0;
                cpu_req_dir  = 1'b1;
                @(posedge clk);
                while (!cpu_ready_dir) @(posedge clk);
                if (cpu_rdata_dir !== golden_val) begin
                    $display("ERROR [Direct]: Mismatch at addr 0x%08h! Expected 0x%08h, got 0x%08h",
                             addr, golden_val, cpu_rdata_dir);
                    trace_mismatches = trace_mismatches + 1;
                    total_mismatches = total_mismatches + 1;
                end
                cpu_req_dir = 1'b0;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Task to run an entire trace file
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
            trace_mismatches = 0;
            trace_accesses   = 0;
            reset_system();

            file_fd = $fopen(trace_path, "r");
            if (file_fd == 0) begin
                $display("ERROR: Failed to open trace file: %0s", trace_path);
                total_mismatches = total_mismatches + 1;
            end else begin
                $display("\n============================================================");
                $display("RUNNING TRACE: %0s", trace_name);
                $display("============================================================");

                while ($fgets(line_buf, file_fd)) begin
                    // Skip comments and empty lines
                    if (line_buf[8*1024:8*1024-7] != "#" && line_buf[8*1024:8*1024-7] != "\n") begin
                        scan_status = $sscanf(line_buf, "%s %h %h", op_str, addr_val, wdata_val);
                        if (scan_status >= 2) begin
                            if (op_str == "R") begin
                                execute_transaction(1'b0, addr_val, 32'h0);
                            end else if (op_str == "W") begin
                                execute_transaction(1'b1, addr_val, wdata_val);
                            end
                        end
                    end
                end
                $fclose(file_fd);

                // Compute hit rates
                if (trace_accesses > 0) begin
                    hit_rate_2w  = (hit_count_2w * 100.0) / trace_accesses;
                    hit_rate_dir = (hit_count_dir * 100.0) / trace_accesses;
                end else begin
                    hit_rate_2w  = 0.0;
                    hit_rate_dir = 0.0;
                end

                $display("RESULTS for %0s (Total Accesses: %0d, Mismatches: %0d):",
                         trace_name, trace_accesses, trace_mismatches);
                $display("  [2-Way LRU]   Hits: %4d | Misses: %4d | Hit Rate: %6.2f%% | Cycles: %6d",
                         hit_count_2w, miss_count_2w, hit_rate_2w, cycle_count_2w);
                $display("  [Direct-Map]  Hits: %4d | Misses: %4d | Hit Rate: %6.2f%% | Cycles: %6d",
                         hit_count_dir, miss_count_dir, hit_rate_dir, cycle_count_dir);

                // Append rows to results/results.csv
                csv_fd = $fopen("results/results.csv", "a");
                if (csv_fd != 0) begin
                    $fdisplay(csv_fd, "%0s,2way,%0d,%0d,%0d,%0.2f,%0d",
                              trace_name, trace_accesses, hit_count_2w, miss_count_2w, hit_rate_2w, cycle_count_2w);
                    $fdisplay(csv_fd, "%0s,direct,%0d,%0d,%0d,%0.2f,%0d",
                              trace_name, trace_accesses, hit_count_dir, miss_count_dir, hit_rate_dir, cycle_count_dir);
                    $fclose(csv_fd);
                end
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Simulation Process
    // ------------------------------------------------------------------------
    reg [1023:0] cli_trace;
    integer init_csv_fd;

    initial begin
        clk              = 0;
        rst              = 1;
        total_mismatches = 0;

        // Create results.csv header if it doesn't already exist or start fresh
        if (!$value$plusargs("TRACE=%s", cli_trace)) begin
            init_csv_fd = $fopen("results/results.csv", "w");
            if (init_csv_fd != 0) begin
                $fdisplay(init_csv_fd, "trace,design,accesses,hits,misses,hit_rate,cycles");
                $fclose(init_csv_fd);
            end
        end

        // Check if specific trace provided via CLI
        if ($value$plusargs("TRACE=%s", cli_trace)) begin
            run_trace_file(cli_trace, cli_trace);
        end else begin
            // Run all 7 standard traces
            run_trace_file("traces/seq_stream.txt", "seq_stream");
            run_trace_file("traces/small_loop.txt", "small_loop");
            run_trace_file("traces/pingpong.txt",   "pingpong");
            run_trace_file("traces/cyclic3.txt",   "cyclic3");
            run_trace_file("traces/strided.txt",   "strided");
            run_trace_file("traces/random.txt",    "random");
            run_trace_file("traces/mixed_rw.txt",  "mixed_rw");
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
