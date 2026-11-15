// ============================================================================
// Module Name: cache_direct
// Project:     Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:       Member 3 (Baseline Baseline Cache & Memory Model)
// Description: Direct-mapped 1 KB L1 cache baseline.
//
// PARAMETER TABLE:
// ----------------------------------------------------------------------------
// Parameter        Value       Formula / Description
// ----------------------------------------------------------------------------
// ADDR_WIDTH       32 bits     Standard 32-bit byte address
// DATA_WIDTH       32 bits     Standard 32-bit data word
// CACHE_CAPACITY   1024 Bytes  1 KB total data capacity
// BLOCK_SIZE       16 Bytes    4 words per block (burst size)
// NUM_LINES        64 lines    CACHE_CAPACITY / BLOCK_SIZE = 1024 / 16 = 64
// OFFSET_BITS      4 bits      log2(BLOCK_SIZE) = log2(16) -> addr[3:0]
// WORD_SEL_BITS    2 bits      addr[3:2] selects 1 of 4 words in block
// INDEX_BITS       6 bits      log2(NUM_LINES) = log2(64)  -> addr[9:4]
// TAG_BITS         22 bits     32 - INDEX_BITS - OFFSET_BITS = 32 - 6 - 4 = 22 -> addr[31:10]
// ----------------------------------------------------------------------------
//
// WRITE POLICY:
// Write-Through, No-Write-Allocate:
// - Write Hit:  Update data word in cache line, write-through to main memory.
// - Write Miss: No refill! Send write directly to main memory (write-through),
//               cache contents remain unchanged.
// ============================================================================

`timescale 1ns / 1ps

module cache_direct #(
    parameter integer ADDR_WIDTH     = 32,
    parameter integer DATA_WIDTH     = 32,
    parameter integer CACHE_CAPACITY = 1024,
    parameter integer BLOCK_SIZE     = 16
) (
    input  wire                   clk,
    input  wire                   rst,

    // CPU / Processor Interface
    input  wire                   cpu_req,    // 1 = Request active
    input  wire                   cpu_we,     // 1 = Write, 0 = Read
    input  wire [ADDR_WIDTH-1:0]  cpu_addr,   // 32-bit address
    input  wire [DATA_WIDTH-1:0]  cpu_wdata,  // 32-bit write data
    output reg                    cpu_ready,  // 1 = Operation complete
    output reg  [DATA_WIDTH-1:0]  cpu_rdata,  // 32-bit read data

    // Memory Bus Interface
    output reg                    mem_req,    // Memory request strobe
    output reg                    mem_we,     // 1 = Write word, 0 = Read block
    output reg  [ADDR_WIDTH-1:0]  mem_addr,   // Memory address
    output reg  [DATA_WIDTH-1:0]  mem_wdata,  // Memory write data
    input  wire                   mem_ready,  // Memory ready strobe
    input  wire [DATA_WIDTH-1:0]  mem_rdata,  // Memory read data

    // Performance Counters
    output reg  [31:0]            hit_count,
    output reg  [31:0]            miss_count,
    output reg  [31:0]            cycle_count
);

    // ------------------------------------------------------------------------
    // Derived Architecture Parameters
    // ------------------------------------------------------------------------
    localparam integer WORDS_PER_BLOCK = BLOCK_SIZE / (DATA_WIDTH / 8); // 4
    localparam integer NUM_LINES       = CACHE_CAPACITY / BLOCK_SIZE;   // 64
    localparam integer OFFSET_BITS     = 4;                             // log2(16)
    localparam integer INDEX_BITS      = 6;                             // log2(64)
    localparam integer TAG_BITS        = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 22

    // ------------------------------------------------------------------------
    // Cache Storage Arrays
    // ------------------------------------------------------------------------
    reg                  valid_array [0:NUM_LINES-1];
    reg [TAG_BITS-1:0]   tag_array   [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array  [0:NUM_LINES-1][0:WORDS_PER_BLOCK-1];

    // ------------------------------------------------------------------------
    // FSM State Encoding
    // ------------------------------------------------------------------------
    localparam [2:0]
        STATE_IDLE          = 3'b000,
        STATE_LOOKUP        = 3'b001,
        STATE_MISS_FETCH    = 3'b010,
        STATE_WRITE_THROUGH = 3'b011;

    reg [2:0] state;

    // Latched request registers
    reg [ADDR_WIDTH-1:0] req_addr;
    reg                  req_we;
    reg [DATA_WIDTH-1:0] req_wdata;

    // Address breakdown wires
    wire [TAG_BITS-1:0]   req_tag      = req_addr[31 : 32 - TAG_BITS];       // [31:10]
    wire [INDEX_BITS-1:0] req_index    = req_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS]; // [9:4]
    wire [1:0]            req_word_sel = req_addr[3:2];

    // Refill buffer for 4-word block burst
    reg [DATA_WIDTH-1:0] refill_buf [0:WORDS_PER_BLOCK-1];
    reg [1:0]            refill_count;

    integer idx, w_idx;

    // ------------------------------------------------------------------------
    // Synchronous FSM & Datapath
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= STATE_IDLE;
            cpu_ready    <= 1'b0;
            cpu_rdata    <= 32'h0;
            mem_req      <= 1'b0;
            mem_we       <= 1'b0;
            mem_addr     <= 32'h0;
            mem_wdata    <= 32'h0;
            refill_count <= 2'b00;
            hit_count    <= 32'd0;
            miss_count   <= 32'd0;
            cycle_count  <= 32'd0;
            req_addr     <= 32'h0;
            req_we       <= 1'b0;
            req_wdata    <= 32'h0;

            for (idx = 0; idx < NUM_LINES; idx = idx + 1) begin
                valid_array[idx] <= 1'b0;
                tag_array[idx]   <= {TAG_BITS{1'b0}};
                for (w_idx = 0; w_idx < WORDS_PER_BLOCK; w_idx = w_idx + 1) begin
                    data_array[idx][w_idx] <= 32'h0;
                end
            end
        end else begin
            // Increment cycle counter while servicing active request
            if (state != STATE_IDLE || cpu_req) begin
                cycle_count <= cycle_count + 1;
            end
            cpu_ready   <= 1'b0; // Default pulse low

            case (state)
                STATE_IDLE: begin
                    refill_count <= 2'b00;
                    mem_req      <= 1'b0;

                    if (cpu_req) begin
                        req_addr  <= cpu_addr;
                        req_we    <= cpu_we;
                        req_wdata <= cpu_wdata;
                        state     <= STATE_LOOKUP;
                    end
                end

                STATE_LOOKUP: begin
                    // Tag compare
                    if (valid_array[req_index] && (tag_array[req_index] == req_tag)) begin
                        // ----------------------------------------------------
                        // HIT
                        // ----------------------------------------------------
                        hit_count <= hit_count + 1;

                        if (!req_we) begin
                            // Read Hit: provide cached data, ready immediately
                            cpu_rdata <= data_array[req_index][req_word_sel];
                            cpu_ready <= 1'b1;
                            state     <= STATE_IDLE;
                        end else begin
                            // Write Hit: update cached word, write-through to memory
                            data_array[req_index][req_word_sel] <= req_wdata;
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= req_addr;
                            mem_wdata <= req_wdata;
                            state     <= STATE_WRITE_THROUGH;
                        end
                    end else begin
                        // ----------------------------------------------------
                        // MISS
                        // ----------------------------------------------------
                        miss_count <= miss_count + 1;

                        if (!req_we) begin
                            // Read Miss: fetch 16-byte block from memory
                            mem_req      <= 1'b1;
                            mem_we       <= 1'b0;
                            mem_addr     <= {req_addr[31:4], 4'b0000};
                            refill_count <= 2'b00;
                            state        <= STATE_MISS_FETCH;
                        end else begin
                            // Write Miss (No-Write-Allocate): send straight to memory
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= req_addr;
                            mem_wdata <= req_wdata;
                            state     <= STATE_WRITE_THROUGH;
                        end
                    end
                end

                STATE_MISS_FETCH: begin
                    mem_req <= 1'b0; // Deassert strobe once request launched

                    if (mem_ready) begin
                        refill_buf[refill_count] <= mem_rdata;
                        refill_count <= refill_count + 1;

                        if (refill_count == 2'd3) begin
                            // Final word of block received: refill cache line
                            valid_array[req_index] <= 1'b1;
                            tag_array[req_index]   <= req_tag;

                            data_array[req_index][0] <= refill_buf[0];
                            data_array[req_index][1] <= refill_buf[1];
                            data_array[req_index][2] <= refill_buf[2];
                            data_array[req_index][3] <= mem_rdata;

                            // Return requested word to CPU
                            if (req_word_sel == 2'd3)
                                cpu_rdata <= mem_rdata;
                            else
                                cpu_rdata <= refill_buf[req_word_sel];

                            cpu_ready <= 1'b1;
                            state     <= STATE_IDLE;
                        end
                    end
                end

                STATE_WRITE_THROUGH: begin
                    mem_req <= 1'b0; // Request launched

                    if (mem_ready) begin
                        // Memory write acknowledgment received
                        cpu_ready <= 1'b1;
                        state     <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
