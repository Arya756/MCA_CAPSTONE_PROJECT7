// ============================================================================
// Module Name: cache_2way_lru
// Project:     Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:       Member 1 (Team Lead - 2-Way Cache RTL & Architecture)
// Description: 2-way set-associative 1 KB L1 cache with True LRU replacement
//              and Write-Through No-Write-Allocate policy.
//
// PARAMETER TABLE:
// ----------------------------------------------------------------------------
// Parameter        Value       Formula / Description
// ----------------------------------------------------------------------------
// ADDR_WIDTH       32 bits     Standard 32-bit byte address
// DATA_WIDTH       32 bits     Standard 32-bit data word
// CACHE_CAPACITY   1024 Bytes  1 KB total data capacity
// BLOCK_SIZE       16 Bytes    4 words per cache block (burst size)
// NUM_WAYS         2 ways      2-way set associativity
// NUM_SETS         32 sets     CACHE_CAPACITY / (BLOCK_SIZE * NUM_WAYS) = 1024 / (16 * 2) = 32
// OFFSET_BITS      4 bits      log2(BLOCK_SIZE) = log2(16) -> addr[3:0]
// WORD_SEL_BITS    2 bits      addr[3:2] selects 1 of 4 words in block
// INDEX_BITS       5 bits      log2(NUM_SETS) = log2(32)   -> addr[8:4]
// TAG_BITS         23 bits     32 - INDEX_BITS - OFFSET_BITS = 32 - 5 - 4 = 23 -> addr[31:9]
// ----------------------------------------------------------------------------
//
// REPLACEMENT POLICY (TRUE LRU):
// - Exactly ONE LRU bit per set: `lru[set]`.
// - Semantics: `lru[set]` points to the victim way when both ways are valid:
//     * lru[set] == 0: Way 0 is LRU (victim is Way 0).
//     * lru[set] == 1: Way 1 is LRU (victim is Way 1).
// - Update Rule:
//     * On Hit (Read/Write): `lru[set] <= ~hit_way` (the other way becomes the LRU).
//     * On Refill:           `lru[set] <= ~victim_way`.
// - Victim Selection Priority:
//     1. If Way 0 is invalid -> pick Way 0.
//     2. Else if Way 1 is invalid -> pick Way 1.
//     3. Else (both valid) -> pick `lru[set]`.
//
// WRITE POLICY:
// Write-Through, No-Write-Allocate:
// - Write Hit:  Update data word in matching cache way, update LRU bit,
//               and initiate write-through to main memory.
// - Write Miss: No refill! Send write directly to main memory (write-through),
//               cache contents and LRU remain unchanged.
// ============================================================================

`timescale 1ns / 1ps

module cache_2way_lru #(
    parameter integer ADDR_WIDTH     = 32,
    parameter integer DATA_WIDTH     = 32,
    parameter integer CACHE_CAPACITY = 1024,
    parameter integer BLOCK_SIZE     = 16,
    parameter integer NUM_WAYS       = 2
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
    localparam integer WORDS_PER_BLOCK = BLOCK_SIZE / (DATA_WIDTH / 8);        // 4 words
    localparam integer NUM_SETS        = CACHE_CAPACITY / (BLOCK_SIZE * NUM_WAYS); // 32 sets
    localparam integer OFFSET_BITS     = 4;                                    // log2(16)
    localparam integer INDEX_BITS      = 5;                                    // log2(32)
    localparam integer TAG_BITS        = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 23 bits

    // ------------------------------------------------------------------------
    // Cache Storage Arrays
    // Way 0 Arrays:
    reg                  valid0 [0:NUM_SETS-1];
    reg [TAG_BITS-1:0]   tag0   [0:NUM_SETS-1];
    reg [DATA_WIDTH-1:0] data0  [0:NUM_SETS-1][0:WORDS_PER_BLOCK-1];

    // Way 1 Arrays:
    reg                  valid1 [0:NUM_SETS-1];
    reg [TAG_BITS-1:0]   tag1   [0:NUM_SETS-1];
    reg [DATA_WIDTH-1:0] data1  [0:NUM_SETS-1][0:WORDS_PER_BLOCK-1];

    // LRU Bit Array: 1 bit per set
    // lru[s] == 0: Way 0 is LRU (victim); lru[s] == 1: Way 1 is LRU (victim)
    reg                  lru    [0:NUM_SETS-1];

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
    wire [TAG_BITS-1:0]   req_tag      = req_addr[31 : 32 - TAG_BITS];       // [31:9]
    wire [INDEX_BITS-1:0] req_index    = req_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS]; // [8:4]
    wire [1:0]            req_word_sel = req_addr[3:2];

    // Parallel Tag Comparison Logic
    wire hit0 = valid0[req_index] && (tag0[req_index] == req_tag);
    wire hit1 = valid1[req_index] && (tag1[req_index] == req_tag);
    wire hit  = hit0 || hit1;
    wire hit_way = hit1; // 0 = hit on Way 0, 1 = hit on Way 1

    // Victim Selection Logic
    // Prioritize invalid ways first; otherwise choose according to LRU bit
    wire victim_way = (!valid0[req_index]) ? 1'b0 :
                      (!valid1[req_index]) ? 1'b1 :
                      lru[req_index];

    // Refill buffer for incoming 4-word block
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

            for (idx = 0; idx < NUM_SETS; idx = idx + 1) begin
                valid0[idx] <= 1'b0;
                valid1[idx] <= 1'b0;
                tag0[idx]   <= {TAG_BITS{1'b0}};
                tag1[idx]   <= {TAG_BITS{1'b0}};
                lru[idx]    <= 1'b0; // Default: Way 0 is initial victim
                for (w_idx = 0; w_idx < WORDS_PER_BLOCK; w_idx = w_idx + 1) begin
                    data0[idx][w_idx] <= 32'h0;
                    data1[idx][w_idx] <= 32'h0;
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
                    if (hit) begin
                        // ----------------------------------------------------
                        // HIT (Read Hit or Write Hit)
                        // ----------------------------------------------------
                        hit_count <= hit_count + 1;

                        // Update LRU: the other way becomes LRU
                        lru[req_index] <= ~hit_way;

                        if (!req_we) begin
                            // Read Hit: Hit-way multiplexer selects data
                            cpu_rdata <= (hit_way == 1'b1) ?
                                         data1[req_index][req_word_sel] :
                                         data0[req_index][req_word_sel];
                            cpu_ready <= 1'b1;
                            state     <= STATE_IDLE;
                        end else begin
                            // Write Hit: update cached word in hit way
                            if (hit_way == 1'b1)
                                data1[req_index][req_word_sel] <= req_wdata;
                            else
                                data0[req_index][req_word_sel] <= req_wdata;

                            // Write-through to main memory
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= req_addr;
                            mem_wdata <= req_wdata;
                            state     <= STATE_WRITE_THROUGH;
                        end
                    end else begin
                        // ----------------------------------------------------
                        // MISS (Read Miss or Write Miss)
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
                            // Do NOT refill cache, do NOT alter LRU
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
                            // Final word received: refill victim way
                            if (victim_way == 1'b1) begin
                                valid1[req_index]       <= 1'b1;
                                tag1[req_index]         <= req_tag;
                                data1[req_index][0]     <= refill_buf[0];
                                data1[req_index][1]     <= refill_buf[1];
                                data1[req_index][2]     <= refill_buf[2];
                                data1[req_index][3]     <= mem_rdata;
                            end else begin
                                valid0[req_index]       <= 1'b1;
                                tag0[req_index]         <= req_tag;
                                data0[req_index][0]     <= refill_buf[0];
                                data0[req_index][1]     <= refill_buf[1];
                                data0[req_index][2]     <= refill_buf[2];
                                data0[req_index][3]     <= mem_rdata;
                            end

                            // Update LRU on refill: the other way becomes LRU
                            lru[req_index] <= ~victim_way;

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
