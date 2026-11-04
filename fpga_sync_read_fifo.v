`timescale 1ns / 1ps

// ============================================================================
// Project       : FPGA-Oriented Synchronous-Read FIFO
// Module        : fpga_sync_read_fifo
// Learning Level: Level 5 - FPGA-Oriented Memory Implementation
// Developer     : Ghulam Yaseen Nangraj
// HDL           : Verilog-2001
// Date          : 4th November 2026
// Development Tool : Xilinx Vivado 2025.2.1
// Simulator     : XSIM
// Target FPGA   : Xilinx Artix-7 (Arty A7-100T)
//
// ============================================================================
// DESCRIPTION:
// ============================================================================
//
// This module implements a parameterized synchronous FIFO (First-In,
// First-Out) using a synchronous-read memory coding style.
//
// The design is intended for FPGA implementation experiments, particularly
// investigating memory inference and registered read behavior.
//
// FIFO operation follows the First-In, First-Out principle:
//
//   1. Data is written into memory using the write pointer.
//   2. Data is read from memory using the read pointer.
//   3. The write pointer advances after every accepted write.
//   4. The read pointer advances after every accepted read.
//   5. Both pointers wrap around when they reach the final memory location.
//   6. The occupancy counter tracks the number of stored words.
//   7. data_valid pulses high for one clock cycle after every accepted read,
//      telling the consumer that data_out contains a newly read word.
//
// IMPORTANT FPGA IMPLEMENTATION NOTE:
//
// The memory read operation is synchronous because data_out is updated
// inside a clocked always block.
//
// This coding style can support FPGA block RAM inference, depending on the
// target device, memory configuration, and synthesis implementation.
//
// Actual BRAM inference must be confirmed using Vivado synthesis reports.
//
// ============================================================================
// FEATURES:
// ============================================================================
//
//   - Parameterized data width and FIFO depth.
//   - Synchronous active-high reset.
//   - Independent read and write enable signals.
//   - Synchronous registered memory read.
//   - data_valid output that flags when data_out holds freshly read data.
//   - Circular read and write pointers.
//   - Automatic pointer wraparound.
//   - Full and empty status indicators.
//   - FIFO occupancy counter.
//   - Simultaneous read/write support when both operations are accepted.
//   - Protection against writing into a full FIFO.
//   - Protection against reading from an empty FIFO.
//
// ============================================================================
// PARAMETERS:
// ============================================================================
//
// DATA_WIDTH  : Number of bits stored in each FIFO memory location.
//               Default = 8 bits.
//
// DEPTH       : Total number of words that the FIFO can store.
//               Default = 16 words.
//
// ADDR_WIDTH  : Number of bits required to address FIFO memory locations.
//               Default = 4 bits for 16 locations.
//
// COUNT_WIDTH : Number of bits required by the occupancy counter.
//               Default = 5 bits for representing values from 0 to 16.
//
// ============================================================================
// INPUT PORTS:
// ============================================================================
//
// clk     : System clock. All FIFO operations occur on its rising edge.
//
// rst     : Active-high synchronous reset.
//           Clears pointers, output register, data_valid flag,
//           and occupancy counter.
//
// wr_en   : Write enable.
//           A write is accepted when wr_en is high and FIFO is not full.
//
// data_in : Input data to be stored in FIFO memory.
//
// rd_en   : Read enable.
//           A read is accepted when rd_en is high and FIFO is not empty.
//
// ============================================================================
// OUTPUT PORTS:
// ============================================================================
//
// data_out : Registered output data obtained from FIFO memory.
//
// data_valid : Registered flag. Goes high on the same clock edge that
//              data_out is loaded by an accepted read, and stays high for
//              exactly one clock cycle (unless another read is accepted on
//              the next edge, in which case it remains high).
//              Goes low when no read was accepted on the latest clock edge.
//
// full     : Asserted when FIFO occupancy reaches its maximum capacity.
//
// empty    : Asserted when FIFO contains no valid data.
//
// count    : Current number of stored FIFO words.
//
// ============================================================================
// INTERNAL REGISTERS AND SIGNALS:
// ============================================================================
//
// memory       : Storage array containing FIFO data.
//
// wr_ptr       : Write pointer identifying the next memory write location.
//
// rd_ptr       : Read pointer identifying the next memory read location.
//
// wr_accept    : Indicates that a write operation is accepted.
//
// rd_accept    : Indicates that a read operation is accepted.
//
// ============================================================================
// OPERATIONAL NOTES:
// ============================================================================
//
// 1. Reset is synchronous and active-high.
//
// 2. A read is accepted only when the FIFO is not empty.
//
// 3. A write is accepted only when the FIFO is not full.
//
// 4. If read and write operations are accepted simultaneously, occupancy
//    remains unchanged.
//
// 5. If both operations are rejected or neither is requested, occupancy
//    remains unchanged.
//
// 6. data_out retains its previous value when no read is accepted.
//
// 7. data_valid is high only in the cycle(s) immediately following an
//    accepted read. A rejected read (FIFO empty) leaves data_out unchanged
//    and drives data_valid low, so the consumer can tell stale data from
//    new data.
//
// ============================================================================


module fpga_sync_read_fifo #(

    // ------------------------------------------------------------------------
    // FIFO Configuration Parameters
    // ------------------------------------------------------------------------

    parameter DATA_WIDTH  = 8,   // Width of each stored data word.
    parameter DEPTH       = 16,  // Total FIFO memory locations.
    parameter ADDR_WIDTH  = 4,   // Width of memory address pointers.
    parameter COUNT_WIDTH = 5    // Width of FIFO occupancy counter.

)(

    // ------------------------------------------------------------------------
    // Clock and Reset Inputs
    // ------------------------------------------------------------------------

    input wire clk,              // System clock.
    input wire rst,              // Active-high synchronous reset.

    // ------------------------------------------------------------------------
    // FIFO Write Interface
    // ------------------------------------------------------------------------

    input wire wr_en,            // Write request enable.

    input wire [DATA_WIDTH-1:0] data_in,
                                 // Input data word to be stored.

    // ------------------------------------------------------------------------
    // FIFO Read Interface
    // ------------------------------------------------------------------------

    input wire rd_en,            // Read request enable.

    output reg [DATA_WIDTH-1:0] data_out,
                                 // Registered FIFO data output.

    output reg data_valid,       // High when data_out holds newly read data.

    // ------------------------------------------------------------------------
    // FIFO Status Outputs
    // ------------------------------------------------------------------------

    output wire full,            // FIFO full status.
    output wire empty,           // FIFO empty status.

    output reg [COUNT_WIDTH-1:0] count
                                 // Number of currently stored words.

);


    // ========================================================================
    // INTERNAL MEMORY AND CONTROL REGISTERS
    // ========================================================================

    // FIFO memory array.
    // Each location stores one DATA_WIDTH-bit data word.
    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    // Write pointer:
    // Identifies the memory location where the next accepted write occurs.
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // Read pointer:
    // Identifies the memory location from which the next accepted read occurs.
    reg [ADDR_WIDTH-1:0] rd_ptr;

    // ========================================================================
    // FIFO STATUS FLAG GENERATION
    // ========================================================================

    // FIFO is FULL when the occupancy counter reaches DEPTH.
    assign full = (count == DEPTH);

    // FIFO is EMPTY when the occupancy counter is zero.
    assign empty = (count == 0);


    // ========================================================================
    // READ AND WRITE ACCEPTANCE LOGIC
    // ========================================================================

    // A write operation is accepted only when:
    //   1. Write enable is asserted.
    //   2. FIFO is not full.
    //
    // If FIFO is full, the write request is rejected.
    wire wr_accept = wr_en && !full;


    // A read operation is accepted only when:
    //   1. Read enable is asserted.
    //   2. FIFO is not empty.
    //
    // If FIFO is empty, the read request is rejected.
    wire rd_accept = rd_en && !empty;


    // ========================================================================
    // SEQUENTIAL FIFO CONTROL AND MEMORY OPERATIONS
    // ========================================================================

    // All memory operations, pointer updates, output-register updates,
    // and occupancy-counter updates are synchronized to the rising edge
    // of the system clock.

    always @(posedge clk) begin

        // --------------------------------------------------------------------
        // SYNCHRONOUS RESET
        // --------------------------------------------------------------------

        if (rst) begin

            // Reset write pointer to the first memory location.
            wr_ptr <= 0;

            // Reset read pointer to the first memory location.
            rd_ptr <= 0;

            // Clear registered output data.
            data_out <= 0;

            // Clear data-valid flag.
            data_valid <= 0;

            // Reset FIFO occupancy to zero.
            count <= 0;

        end

        // --------------------------------------------------------------------
        // NORMAL FIFO OPERATION
        // --------------------------------------------------------------------

        else begin

            // ================================================================
            // 1. FIFO WRITE OPERATION
            // ================================================================

            // Perform a memory write only when the write request
            // has been accepted.
            if (wr_accept) begin

                // Store input data at the current write-pointer location.
                memory[wr_ptr] <= data_in;

                // Check whether the write pointer has reached
                // the final FIFO memory location.
                if (wr_ptr == DEPTH-1)

                    // Wrap write pointer back to location zero.
                    wr_ptr <= 0;

                else

                    // Otherwise, advance to the next memory location.
                    wr_ptr <= wr_ptr + 1'b1;

            end


            // ================================================================
            // 2. FIFO SYNCHRONOUS READ OPERATION
            // ================================================================

            // Drive the data-valid flag.
            // It becomes 1 on the same clock edge that data_out is loaded
            // by an accepted read, and 0 when no read was accepted.
            data_valid <= rd_accept;


            // Execute a read only when the FIFO is not empty.
            if (rd_accept) begin

                // Read the selected memory location into the output register.
                //
                // Because this assignment is inside a clocked always block,
                // data_out is updated synchronously with the clock.
                data_out <= memory[rd_ptr];


                // Check whether the read pointer has reached
                // the final FIFO memory location.
                if (rd_ptr == DEPTH-1)

                    // Wrap read pointer back to memory location zero.
                    rd_ptr <= 0;

                else

                    // Otherwise, advance to the next memory location.
                    rd_ptr <= rd_ptr + 1'b1;

            end


            // ================================================================
            // 3. FIFO OCCUPANCY COUNTER CONTROL
            // ================================================================

            // The occupancy counter changes according to accepted
            // read and write operations.
            //
            // wr_accept = 1, rd_accept = 0:
            //     One word is written. Occupancy increases by one.
            //
            // wr_accept = 0, rd_accept = 1:
            //     One word is read. Occupancy decreases by one.
            //
            // wr_accept = 1, rd_accept = 1:
            //     One word is written and one word is read.
            //     Occupancy remains unchanged.
            //
            // wr_accept = 0, rd_accept = 0:
            //     No operation is accepted.
            //     Occupancy remains unchanged.

            case ({wr_accept, rd_accept})

                // Accepted write only: increment occupancy.
                2'b10: count <= count + 1'b1;

                // Accepted read only: decrement occupancy.
                2'b01: count <= count - 1'b1;

                // Both accepted or neither accepted:
                // Maintain the current occupancy.
                default: count <= count;

            endcase

        end

    end

endmodule


// ============================================================================
// END OF MODULE
// ============================================================================
//
// Learning Level : Level 5
// Design Category: FPGA-Oriented Synchronous-Read FIFO
// HDL Standard   : Verilog-2001
// Development Tool: Xilinx Vivado 2025.2.1
//
// ============================================================================