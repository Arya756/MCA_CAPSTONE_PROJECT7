// ============================================================================
// Module Name: cache_2way_lru
// Project:     Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
// Owner:       Member 1 (Team Lead - 2-Way Cache RTL & Architecture)
// Description: 2-Way Set-Associative L1 Data Cache with True LRU replacement
//              and Write-Through No-Write-Allocate memory policy.
//
// ============================================================================
// PARAMETER TABLE & DERIVATION:
// ----------------------------------------------------------------------------
// Parameter        Value       Formula / Derivation
// ----------------------------------------------------------------------------
// ADDR_WIDTH       32 bits     Standard 32-bit microprocessor address
// DATA_WIDTH       32 bits     32-bit data word (4 bytes per word)
// CACHE_CAPACITY   1024 Bytes  1 KB total data capacity (excluding tags/valid)
// BLOCK_SIZE       16 Bytes    Block size (burst unit from memory: 4 words)
// NUM_WAYS         2 ways      2-way set associativity (2 blocks per set)
// NUM_SETS         32 sets     CACHE_CAPACITY / (BLOCK_SIZE * NUM_WAYS)
//                              = 1024 / (16 * 2) = 32 sets
// OFFSET_BITS      4 bits      log2(BLOCK_SIZE) = log2(16) -> cpu_addr[3:0]
// WORD_SEL_BITS    2 bits      cpu_addr[3:2] selects 1 of 4 words in block
// BYTE_SEL_BITS    2 bits      cpu_addr[1:0] byte offset (assumed 2'b00 aligned)
// INDEX_BITS       5 bits      log2(NUM_SETS) = log2(32)   -> cpu_addr[8:4]
// TAG_BITS         23 bits     32 - INDEX_BITS - OFFSET_BITS
//                              = 32 - 5 - 4 = 23 bits      -> cpu_addr[31:9]
// ----------------------------------------------------------------------------
//
// ADDRESS BIT BREAKDOWN (32 BITS TOTAL):
//  31                         9 8       4 3    2 1    0
// +----------------------------+---------+------+------+
// |         TAG (23 bits)      | INDEX(5)| WORD | BYTE |
// +----------------------------+---------+------+------+
//                               \_______/ \___________/
//                                32 Sets     16-Byte
//                                (0 to 31)    Offset
//
// HARDWARE STRUCTURE:
// - Two identical ways: Way 0 and Way 1.
// - Each set contains:
//     * Way 0: valid bit (1 bit), tag (23 bits), data block (4 x 32 bits = 128 bits)
//     * Way 1: valid bit (1 bit), tag (23 bits), data block (4 x 32 bits = 128 bits)
//     * LRU bit (1 bit per set, tracking which way is least recently used)
// - Parallel tag comparison: tags of Way 0 and Way 1 are compared simultaneously.
//
// REPLACEMENT POLICY (TRUE LRU):
// - Exactly ONE LRU bit per set: `lru[set]`.
// - Interpretation:
//     * lru[set] == 1'b0: Way 0 is LRU (victim is Way 0 if both ways are valid).
//     * lru[set] == 1'b1: Way 1 is LRU (victim is Way 1 if both ways are valid).
// - Update Rules:
//     * On Hit (Read or Write): `lru[set] <= ~hit_way`
//       (accessing Way 0 makes Way 1 the LRU victim -> lru <= 1).
//     * On Refill: `lru[set] <= ~victim_way`
//       (refilling Way 0 makes Way 1 the LRU victim -> lru <= 1).
// - Victim Selection Priority:
//     1. If Way 0 is invalid (!valid0[set]) -> choose Way 0.
//     2. Else if Way 1 is invalid (!valid1[set]) -> choose Way 1.
//     3. Else (both ways valid) -> choose `lru[set]`.
//     This ensures invalid lines are filled before any valid line is evicted.
//
// WRITE POLICY:
// Write-Through, No-Write-Allocate:
// - Write Hit:  Update data word in matching cache way, update LRU bit,
//               and send write-through to main memory.
// - Write Miss: Do NOT fetch block! Send write directly to main memory.
//               Cache contents and LRU remain unchanged.
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

    // ------------------------------------------------------------------------
    // CPU / Processor Bus Interface
    // ------------------------------------------------------------------------
    input  wire                   cpu_req,    // 1 = Active request from CPU
    input  wire                   cpu_we,     // 1 = Write request, 0 = Read request
    input  wire [ADDR_WIDTH-1:0]  cpu_addr,   // 32-bit byte address from CPU
    input  wire [DATA_WIDTH-1:0]  cpu_wdata,  // 32-bit write data from CPU
    output reg                    cpu_ready,  // 1 = Operation complete (1-cycle pulse)
    output reg  [DATA_WIDTH-1:0]  cpu_rdata,  // 32-bit read data returning to CPU

    // ------------------------------------------------------------------------
    // Memory Controller Bus Interface
    // ------------------------------------------------------------------------
    output reg                    mem_req,    // 1 = Memory request strobe
    output reg                    mem_we,     // 1 = Write word, 0 = Read 4-word block
    output reg  [ADDR_WIDTH-1:0]  mem_addr,   // Memory address (block-aligned for reads)
    output reg  [DATA_WIDTH-1:0]  mem_wdata,  // Memory write data word
    input  wire                   mem_ready,  // 1 = Memory ready acknowledgment / burst strobe
    input  wire [DATA_WIDTH-1:0]  mem_rdata,  // Memory read data word from burst

    // ------------------------------------------------------------------------
    // Performance & Diagnostic Counters
    // ------------------------------------------------------------------------
    output reg  [31:0]            hit_count,   // Increments on read hit or write hit
    output reg  [31:0]            miss_count,  // Increments on read miss or write miss
    output reg  [31:0]            cycle_count  // Active clock cycles servicing CPU requests
);

    // ------------------------------------------------------------------------
    // Derived Architectural Constants
    // ------------------------------------------------------------------------
    localparam integer WORDS_PER_BLOCK = BLOCK_SIZE / (DATA_WIDTH / 8);        // 4 words (16B / 4B)
    localparam integer NUM_SETS        = CACHE_CAPACITY / (BLOCK_SIZE * NUM_WAYS); // 32 sets
    localparam integer OFFSET_BITS     = 4;                                    // log2(16)
    localparam integer INDEX_BITS      = 5;                                    // log2(32)
    localparam integer TAG_BITS        = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 32 - 5 - 4 = 23 bits

    // ------------------------------------------------------------------------
    // Cache Storage Arrays
    // ------------------------------------------------------------------------
    // Way 0 Storage:
    reg                  valid0 [0:NUM_SETS-1];                       // Valid bits (1 per set)
    reg [TAG_BITS-1:0]   tag0   [0:NUM_SETS-1];                       // Tag bits (23 per set)
    reg [DATA_WIDTH-1:0] data0  [0:NUM_SETS-1][0:WORDS_PER_BLOCK-1];  // 4 data words per set

    // Way 1 Storage:
    reg                  valid1 [0:NUM_SETS-1];                       // Valid bits (1 per set)
    reg [TAG_BITS-1:0]   tag1   [0:NUM_SETS-1];                       // Tag bits (23 per set)
    reg [DATA_WIDTH-1:0] data1  [0:NUM_SETS-1][0:WORDS_PER_BLOCK-1];  // 4 data words per set

    // LRU Storage: 1 bit per set
    // lru[s] == 0: Way 0 is LRU victim; lru[s] == 1: Way 1 is LRU victim
    reg                  lru    [0:NUM_SETS-1];

    // ------------------------------------------------------------------------
    // Controller Finite State Machine (FSM) State Encoding
    // ------------------------------------------------------------------------
    // Streamlined 4-state architecture:
    // STATE_IDLE:          Wait for cpu_req, latch inputs
    // STATE_LOOKUP:        Parallel tag compare, hit/miss decision, instant hit respond
    // STATE_MISS_FETCH:    Issue block read, collect 4-word burst, refill & respond
    // STATE_WRITE_THROUGH: Issue word write to memory, await acknowledgment & respond
    localparam [2:0]
        STATE_IDLE          = 3'b000,
        STATE_LOOKUP        = 3'b001,
        STATE_MISS_FETCH    = 3'b010,
        STATE_WRITE_THROUGH = 3'b011;

    reg [2:0] state;

    // ------------------------------------------------------------------------
    // Latched Request Registers (stable throughout multi-cycle operations)
    // ------------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] req_addr;   // Latched CPU address
    reg                  req_we;     // Latched read/write command
    reg [DATA_WIDTH-1:0] req_wdata;  // Latched write data word

    // ------------------------------------------------------------------------
    // Address Field Extraction
    // ------------------------------------------------------------------------
    wire [TAG_BITS-1:0]   req_tag      = req_addr[31 : 32 - TAG_BITS];       // bits [31:9] (23 bits)
    wire [INDEX_BITS-1:0] req_index    = req_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS]; // bits [8:4] (5 bits)
    wire [1:0]            req_word_sel = req_addr[3:2];                      // bits [3:2] word offset

    // ------------------------------------------------------------------------
    // Parallel Tag Comparison Logic
    // ------------------------------------------------------------------------
    // Both tag comparators evaluate simultaneously in hardware
    wire hit0 = valid0[req_index] && (tag0[req_index] == req_tag); // Tag match on Way 0
    wire hit1 = valid1[req_index] && (tag1[req_index] == req_tag); // Tag match on Way 1
    wire hit  = hit0 || hit1;                                      // Overall cache hit
    wire hit_way = hit1; // 1'b0 if hit on Way 0, 1'b1 if hit on Way 1

    // ------------------------------------------------------------------------
    // Victim Selection Logic
    // ------------------------------------------------------------------------
    // Priority:
    // 1. If Way 0 is empty (invalid), use Way 0.
    // 2. Else if Way 1 is empty (invalid), use Way 1.
    // 3. If both ways are valid, use the True LRU bit to pick the victim.
    wire victim_way = (!valid0[req_index]) ? 1'b0 :
                      (!valid1[req_index]) ? 1'b1 :
                      lru[req_index];

    // ------------------------------------------------------------------------
    // Refill Burst Buffer & Counter
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] refill_buf [0:WORDS_PER_BLOCK-1]; // Holds burst words 0, 1, 2
    reg [1:0]            refill_count;                     // Counts incoming words 0 to 3

    integer idx, w_idx;

    // ------------------------------------------------------------------------
    // Synchronous FSM & Datapath Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Asynchronous reset of all control registers, flags, and storage
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

            // Invalidate all cache lines and initialize LRU bits to Way 0 victim
            for (idx = 0; idx < NUM_SETS; idx = idx + 1) begin
                valid0[idx] <= 1'b0;
                valid1[idx] <= 1'b0;
                tag0[idx]   <= {TAG_BITS{1'b0}};
                tag1[idx]   <= {TAG_BITS{1'b0}};
                lru[idx]    <= 1'b0; // Default: Way 0 is initial LRU victim
                for (w_idx = 0; w_idx < WORDS_PER_BLOCK; w_idx = w_idx + 1) begin
                    data0[idx][w_idx] <= 32'h0;
                    data1[idx][w_idx] <= 32'h0;
                end
            end
        end else begin
            // Cycle counter increments only when actively servicing a request
            if (state != STATE_IDLE || cpu_req) begin
                cycle_count <= cycle_count + 1;
            end

            // Default: cpu_ready is a 1-clock-cycle pulse
            cpu_ready <= 1'b0;

            case (state)
                // ------------------------------------------------------------
                // STATE_IDLE: Awaiting CPU Request
                // ------------------------------------------------------------
                STATE_IDLE: begin
                    refill_count <= 2'b00;
                    mem_req      <= 1'b0;

                    if (cpu_req) begin
                        // Latch CPU bus inputs for duration of access
                        req_addr  <= cpu_addr;
                        req_we    <= cpu_we;
                        req_wdata <= cpu_wdata;
                        state     <= STATE_LOOKUP;
                    end
                end

                // ------------------------------------------------------------
                // STATE_LOOKUP: Parallel Tag Comparison & Hit/Miss Routing
                // ------------------------------------------------------------
                STATE_LOOKUP: begin
                    if (hit) begin
                        // ----------------------------------------------------
                        // HIT CASE (Read Hit or Write Hit)
                        // ----------------------------------------------------
                        hit_count <= hit_count + 1;

                        // LRU Update Rule:
                        // Accessed way becomes MRU -> the OTHER way becomes LRU victim
                        lru[req_index] <= ~hit_way;

                        if (!req_we) begin
                            // Read Hit: Hit-way multiplexer selects data from matching way
                            // Operation completes in exactly 2 clock cycles
                            cpu_rdata <= (hit_way == 1'b1) ?
                                         data1[req_index][req_word_sel] :
                                         data0[req_index][req_word_sel];
                            cpu_ready <= 1'b1;
                            state     <= STATE_IDLE;
                        end else begin
                            // Write Hit:
                            // 1. Update data word in the matching cache way
                            if (hit_way == 1'b1)
                                data1[req_index][req_word_sel] <= req_wdata;
                            else
                                data0[req_index][req_word_sel] <= req_wdata;

                            // 2. Initiate write-through to main memory
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= req_addr;
                            mem_wdata <= req_wdata;
                            state     <= STATE_WRITE_THROUGH;
                        end
                    end else begin
                        // ----------------------------------------------------
                        // MISS CASE (Read Miss or Write Miss)
                        // ----------------------------------------------------
                        miss_count <= miss_count + 1;

                        if (!req_we) begin
                            // Read Miss:
                            // Initiate 4-word block read from main memory
                            // Address aligned to 16-byte boundary: {req_addr[31:4], 4'b0000}
                            mem_req      <= 1'b1;
                            mem_we       <= 1'b0;
                            mem_addr     <= {req_addr[31:4], 4'b0000};
                            refill_count <= 2'b00;
                            state        <= STATE_MISS_FETCH;
                        end else begin
                            // Write Miss (No-Write-Allocate):
                            // Do NOT refill cache! Send write directly to memory
                            // Cache arrays and LRU bit remain completely untouched
                            mem_req   <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= req_addr;
                            mem_wdata <= req_wdata;
                            state     <= STATE_WRITE_THROUGH;
                        end
                    end
                end

                // ------------------------------------------------------------
                // STATE_MISS_FETCH: Memory Read Latency & 4-Word Burst Refill
                // ------------------------------------------------------------
                STATE_MISS_FETCH: begin
                    // Deassert mem_req once memory has accepted the request
                    mem_req <= 1'b0;

                    // Sample incoming words from main memory burst
                    if (mem_ready) begin
                        refill_buf[refill_count] <= mem_rdata;
                        refill_count <= refill_count + 1;

                        if (refill_count == 2'd3) begin
                            // Word 3 received (last word of 16-byte block):
                            // Refill the selected victim way with all 4 words
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

                            // LRU Update Rule on Refill:
                            // Refilled way becomes MRU -> the OTHER way becomes LRU victim
                            lru[req_index] <= ~victim_way;

                            // Forward requested word directly to CPU read data bus
                            if (req_word_sel == 2'd3)
                                cpu_rdata <= mem_rdata;
                            else
                                cpu_rdata <= refill_buf[req_word_sel];

                            // Assert completion handshake and return to IDLE
                            cpu_ready <= 1'b1;
                            state     <= STATE_IDLE;
                        end
                    end
                end

                // ------------------------------------------------------------
                // STATE_WRITE_THROUGH: Memory Word Write Latency
                // ------------------------------------------------------------
                STATE_WRITE_THROUGH: begin
                    // Deassert strobe after launching request
                    mem_req <= 1'b0;

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
