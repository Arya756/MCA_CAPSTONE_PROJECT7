// ============================================================================
// Module Name: main_memory
// Project:     Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:       Member 3 (Baseline and Memory Model)
// Description: Main memory model with parameterized read and write latencies.
//              - Word-addressed backing storage of 4096 32-bit words (16 KB).
//              - Parameterized Read Latency (RD_LAT, default 8 cycles).
//              - Parameterized Write Latency (WR_LAT, default 4 cycles).
//              - Overridable via compilation flags (e.g. iverilog -DRD_LAT=4 in the testbench).
//
// BLOCK-READ PROTOCOL:
// 1. Master asserts `mem_req = 1`, `mem_we = 0`, and provides `mem_addr`.
// 2. Memory latches the request and initiates the read delay counter.
// 3. For `RD_LAT` cycles, `mem_ready` remains 0.
// 4. Starting immediately after `RD_LAT` cycles, memory bursts 4 consecutive
//    words (one 16-byte cache block) over 4 clock cycles:
//      - Burst cycle 0: mem_ready = 1, mem_rdata = word[0] (mem_addr[31:4], offset 0)
//      - Burst cycle 1: mem_ready = 1, mem_rdata = word[1] (offset 4)
//      - Burst cycle 2: mem_ready = 1, mem_rdata = word[2] (offset 8)
//      - Burst cycle 3: mem_ready = 1, mem_rdata = word[3] (offset 12)
// 5. On the cycle following the 4th word, `mem_ready` drops to 0, returning
//    to IDLE state.
//
// WORD-WRITE PROTOCOL:
// 1. Master asserts `mem_req = 1`, `mem_we = 1`, `mem_addr`, and `mem_wdata`.
// 2. Memory latches the write request and waits for `WR_LAT` cycles.
// 3. At cycle `WR_LAT`, the target word `mem_array[mem_addr[13:2]]` is updated,
//    and `mem_ready` pulses HIGH for 1 cycle as an acknowledgment.
// 4. On the next cycle, `mem_ready` drops to 0 and returns to IDLE.
// ============================================================================

`timescale 1ns / 1ps

module main_memory #(
    parameter integer RD_LAT     = 8,     // Latency in cycles before block-read burst
    parameter integer WR_LAT     = 4,     // Latency in cycles for single-word write
    parameter integer BLOCK_SIZE = 16,    // Block size in bytes (burst unit)
    parameter integer MEM_WORDS  = 4096   // Total memory capacity (4096 words = 16 KB)
) (
    input  wire        clk,
    input  wire        rst,

    // Memory Bus Interface
    input  wire        mem_req,          // Request strobe (active high)
    input  wire        mem_we,           // Write enable (1 = Write word, 0 = Read block)
    input  wire [31:0] mem_addr,         // Byte address (word-aligned: addr[1:0] == 0)
    input  wire [31:0] mem_wdata,        // Write data word

    output reg         mem_ready,        // Ready strobe / data valid
    output reg  [31:0] mem_rdata         // Read data output
);

    // Derived block parameters
    localparam integer WORDS_PER_BLOCK = BLOCK_SIZE / 4;
    localparam integer OFFSET_BITS     = $clog2(BLOCK_SIZE);
    localparam integer WORD_SEL_BITS   = (WORDS_PER_BLOCK > 1) ? $clog2(WORDS_PER_BLOCK) : 1;

    // ------------------------------------------------------------------------
    // Backing Storage: 4096 x 32-bit words
    // ------------------------------------------------------------------------
    reg [31:0] mem_array [0:MEM_WORDS-1];

    // State definitions
    localparam [1:0]
        STATE_IDLE       = 2'b00,
        STATE_READ_WAIT  = 2'b01,
        STATE_READ_BURST = 2'b10,
        STATE_WRITE_WAIT = 2'b11;

    reg [1:0]  state;
    reg [31:0] timer;
    reg [3:0]  burst_idx;
    reg [11:0] latched_block_base;       // Base word index of block
    reg [11:0] latched_word_addr;        // Word index for write
    reg [31:0] latched_wdata;

    integer i;
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            mem_array[i] = 32'h0000_0000;
        end
    end

    // ------------------------------------------------------------------------
    // Memory Controller FSM
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state              <= STATE_IDLE;
            timer              <= 0;
            burst_idx          <= 0;
            latched_block_base <= 0;
            latched_word_addr  <= 0;
            latched_wdata      <= 0;
            mem_ready          <= 1'b0;
            mem_rdata          <= 32'h0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    mem_ready <= 1'b0;
                    burst_idx <= 0;
                    timer     <= 0;

                    if (mem_req) begin
                        if (!mem_we) begin
                            // Read request for block
                            latched_block_base <= {mem_addr[13 : OFFSET_BITS], {WORD_SEL_BITS{1'b0}}};
                            if (RD_LAT <= 1) begin
                                // Immediate burst start
                                state     <= STATE_READ_BURST;
                                mem_ready <= 1'b1;
                                mem_rdata <= mem_array[{mem_addr[13 : OFFSET_BITS], {WORD_SEL_BITS{1'b0}}}];
                                burst_idx <= 1;
                            end else begin
                                timer <= 1;
                                state <= STATE_READ_WAIT;
                            end
                        end else begin
                            // Single-word write request
                            latched_word_addr <= mem_addr[13:2];
                            latched_wdata     <= mem_wdata;
                            if (WR_LAT <= 1) begin
                                mem_array[mem_addr[13:2]] <= mem_wdata;
                                mem_ready                 <= 1'b1;
                                state                     <= STATE_IDLE;
                            end else begin
                                timer <= 1;
                                state <= STATE_WRITE_WAIT;
                            end
                        end
                    end
                end

                STATE_READ_WAIT: begin
                    timer <= timer + 1;
                    if (timer >= RD_LAT - 1) begin
                        // Latency completed: start burst on next cycle
                        state     <= STATE_READ_BURST;
                        burst_idx <= 1;
                        mem_ready <= 1'b1;
                        mem_rdata <= mem_array[latched_block_base + 0];
                    end
                end

                STATE_READ_BURST: begin
                    // Deliver consecutive words of the cache block
                    mem_rdata <= mem_array[latched_block_base + burst_idx];
                    mem_ready <= 1'b1;
                    burst_idx <= burst_idx + 1;

                    if (burst_idx == (WORDS_PER_BLOCK - 1)) begin
                        // Final word delivered, complete burst
                        state <= STATE_IDLE;
                    end
                end

                STATE_WRITE_WAIT: begin
                    timer <= timer + 1;
                    if (timer >= WR_LAT - 1) begin
                        // Latency completed: perform write and assert ready
                        mem_array[latched_word_addr] <= latched_wdata;
                        mem_ready                    <= 1'b1;
                        state                        <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
