# FPGA-Oriented Synchronous-Read FIFO
## Level 5 — FPGA-Oriented Memory Implementation

**Project:** FPGA Synchronous-Read FIFO Memory  
**Top Module:** `fpga_sync_read_fifo`  
**Testbench:** `tb_fpga_sync_read_fifo`  
**Developer:** Ghulam Yaseen Nangraj  
**Date:** 4th November 2026  
**HDL Standard:** Verilog-2001  
**Development Tool:** Xilinx Vivado 2025.2.1  
**Simulator:** XSIM  
**Target FPGA:** Xilinx Artix-7 (Arty A7-100T)  
**Design Category:** Digital Logic Design / FPGA Memory Architecture  
**Learning Level:** Level 5

---

# 1. Project Overview

This project implements a parameterized, FPGA-oriented Synchronous FIFO (First-In, First-Out) using Verilog-2001.

The primary objective is to explore a memory-oriented FIFO architecture in which memory read operations are performed synchronously with the system clock.

Unlike a basic FIFO implementation that may use combinational memory reads, this architecture registers the memory output inside a clocked `always` block.

This coding methodology is suitable for FPGA memory inference and provides an opportunity to understand how RTL coding styles influence the synthesis and physical implementation of memory resources.

The FIFO follows the First-In, First-Out principle:

- The first data word written into the FIFO is the first word read.
- Every accepted write stores one data word in memory.
- Every accepted read retrieves the oldest available data word.
- Read and write pointers independently track memory locations.
- An occupancy counter maintains the number of stored words.
- Status flags indicate whether the FIFO is full or empty.

The architecture also supports simultaneous accepted read and write operations.

# 2. Design Objectives

The main engineering objectives are:

1. Develop a parameterized synchronous FIFO.
2. Implement synchronous registered memory reading.
3. Explore FPGA-oriented memory inference.
4. Implement circular read and write pointers.
5. Generate reliable Full and Empty status indicators.
6. Support simultaneous read and write transactions.
7. Protect FIFO memory against invalid read and write requests.
8. Implement an occupancy counter.
9. Generate a registered `data_valid` output.
10. Verify FIFO functionality using a dedicated self-checking testbench.
11. Observe internal memory and pointer behavior using Vivado XSIM waveforms.

# 3. Architecture Overview

The FIFO architecture consists of the following functional blocks:

| Functional Block | Description |
|---|---|
| FIFO Memory | Stores input data words |
| Write Pointer | Selects the next memory write location |
| Read Pointer | Selects the next memory read location |
| Write Acceptance Logic | Determines whether a write is permitted |
| Read Acceptance Logic | Determines whether a read is permitted |
| Full Detection | Detects maximum FIFO occupancy |
| Empty Detection | Detects zero FIFO occupancy |
| Occupancy Counter | Tracks the number of stored words |
| Registered Read Output | Holds the retrieved FIFO data |
| Data Valid Logic | Identifies newly retrieved data |

## 3.1 Functional Block Diagram

```text
                 FPGA SYNCHRONOUS FIFO
                 =====================

                       +-----------+
                       |   CLOCK   |
                       |   RESET   |
                       +-----+-----+
                             |
              +--------------+--------------+
              |                             |
              v                             v
       +-------------+              +-------------+
       | WRITE       |              | READ        |
       | ACCEPTANCE  |              | ACCEPTANCE  |
       | LOGIC       |              | LOGIC       |
       +------+------+              +------+------+
              |                             |
              v                             v
       +-------------+              +-------------+
       | WRITE       |              | READ        |
       | POINTER     |              | POINTER     |
       +------+------+              +------+------+
              |                             |
              v                             v
       +-----------------------------------------+
       |                                         |
       |           FIFO MEMORY ARRAY             |
       |                                         |
       |          DEPTH x DATA_WIDTH             |
       |                                         |
       +--------------------+--------------------+
                            |
                            v
                    +---------------+
                    | REGISTERED    |
                    | MEMORY READ   |
                    | OUTPUT        |
                    +-------+-------+
                            |
                            v
                       +---------+
                       | DATA_OUT|
                       +---------+
                            |
                            v
                       +---------+
                       | DATA_   |
                       | VALID   |
                       +---------+

              +-------------------------+
              | FIFO OCCUPANCY COUNTER  |
              +------------+------------+
                           |
                    +------+------+
                    |             |
                    v             v
                  FULL          EMPTY
```

# 4. FIFO Operating Principle

## 4.1 Write Operation

A write operation is accepted when:

```verilog
wr_accept = wr_en && !full;
```

When a write is accepted:

1. Input data is stored at the current write-pointer address.
2. The write pointer advances by one.
3. The pointer wraps around when it reaches the final memory location.
4. The occupancy counter increases if no read is accepted simultaneously.

Memory write operation:

```verilog
if (wr_accept) begin

    memory[wr_ptr] <= data_in;

end
```

## 4.2 Read Operation

A read operation is accepted when:

```verilog
rd_accept = rd_en && !empty;
```

When a read is accepted:

1. The memory location selected by the read pointer is accessed.
2. The retrieved word is registered into `data_out`.
3. The read pointer advances by one.
4. The pointer wraps around when it reaches the final memory location.
5. The occupancy counter decreases if no write is accepted simultaneously.

Memory read operation:

```verilog
if (rd_accept) begin

    data_out <= memory[rd_ptr];

end
```

**Important:** The memory read is synchronous because the memory access and output-register assignment occur inside a clocked `always @(posedge clk)` block.

## 4.3 Simultaneous Read and Write

The architecture supports simultaneous read and write requests.

The occupancy counter is controlled by the accepted-operation signals rather than the raw enable signals.

| wr_accept | rd_accept | FIFO Operation | Occupancy |
|---|---|---|---|
| 0 | 0 | No operation | Unchanged |
| 0 | 1 | Read only | Decreases by 1 |
| 1 | 0 | Write only | Increases by 1 |
| 1 | 1 | Read and write | Unchanged |

The occupancy logic is implemented using:

```verilog
case ({wr_accept, rd_accept})

    2'b10: count <= count + 1'b1;

    2'b01: count <= count - 1'b1;

    default: count <= count;

endcase
```

**Boundary condition:** Acceptance is evaluated using the current FIFO status. Therefore, a simultaneous read and write when the FIFO is empty accepts the write but rejects the read. When the FIFO is full, it accepts the read but rejects the write. This implementation does not use look-ahead acceptance logic.

# 5. Synchronous Memory Read Architecture

One of the most important learning objectives of this project is understanding synchronous memory read behavior.

In a synchronous-read architecture, the memory output is updated in response to a clock edge.

The implementation uses:

```verilog
always @(posedge clk) begin

    if (rd_accept) begin

        data_out <= memory[rd_ptr];

    end

end
```

Because a nonblocking assignment is used, the output register updates after the active clock edge.

### Synchronous Read Characteristics

- Read operations are synchronized to the system clock.
- The output is registered.
- `data_out` retains its previous value when no read is accepted.
- The consumer uses `data_valid` to identify newly retrieved data.
- This coding style can support FPGA Block RAM inference.

## 5.1 BRAM Inference Considerations

FPGA devices provide dedicated memory resources, including:

- Block RAM (BRAM)
- Distributed RAM (LUT-based memory)
- Other device-specific memory resources

A synchronous-read RTL coding style is suitable for BRAM inference, but it does not guarantee BRAM implementation.

Actual memory mapping depends on:

1. Memory depth and data width.
2. Target FPGA architecture.
3. Supported memory configurations.
4. Read and write coding style.
5. Reset requirements.
6. Synthesis optimization and implementation decisions.

**Engineering Rule:** Always inspect the Vivado synthesis reports to confirm whether the memory is implemented using Block RAM, distributed RAM, or another resource.

# 6. Data Valid Signal

The `data_valid` output indicates whether `data_out` contains a newly retrieved FIFO word.

Implementation:

```verilog
data_valid <= rd_accept;
```

Behavior:

| Condition | data_valid |
|---|---|
| Accepted read | 1 |
| No read request | 0 |
| Read rejected because FIFO is empty | 0 |
| Accepted write only | 0 |
| Reset | 0 |

The signal is registered and remains high for each clock cycle in which a read is accepted.

If consecutive reads are accepted, `data_valid` remains continuously high.

This signal is particularly useful when connecting the FIFO to downstream processing logic, data pipelines, or communication interfaces.

# 7. FIFO Pointer Architecture

Two independent pointers control FIFO memory access.

## 7.1 Write Pointer

`wr_ptr` identifies the memory location where the next accepted write will occur.

After reaching the final location, it returns to zero.

```verilog
if (wr_ptr == DEPTH-1)

    wr_ptr <= 0;

else

    wr_ptr <= wr_ptr + 1'b1;
```

## 7.2 Read Pointer

`rd_ptr` identifies the memory location from which the next accepted read will occur.

It also wraps around to zero after reaching the final location.

```verilog
if (rd_ptr == DEPTH-1)

    rd_ptr <= 0;

else

    rd_ptr <= rd_ptr + 1'b1;
```

Both pointers operate independently and are updated only when their corresponding operations are accepted.

# 8. FIFO Status Generation

The design uses an occupancy counter to generate Full and Empty flags.

### Full Detection

```verilog
assign full = (count == DEPTH);
```

The Full flag becomes high when the FIFO reaches its maximum storage capacity.

### Empty Detection

```verilog
assign empty = (count == 0);
```

The Empty flag becomes high when the FIFO contains no valid data.

### Occupancy Counter

The counter represents the number of currently stored FIFO words.

For the default configuration:

- Minimum occupancy = 0
- Maximum occupancy = 16
- Counter width = 5 bits

A five-bit counter is required because it must represent values from 0 through 16.

# 9. Module Interface

## 9.1 Input Ports

| Signal | Width | Description |
|---|---:|---|
| clk | 1 | System clock |
| rst | 1 | Synchronous active-high reset |
| wr_en | 1 | Write request enable |
| data_in | DATA_WIDTH | Input data word |
| rd_en | 1 | Read request enable |

## 9.2 Output Ports

| Signal | Width | Description |
|---|---:|---|
| data_out | DATA_WIDTH | Registered FIFO output |
| data_valid | 1 | Indicates newly retrieved data |
| full | 1 | FIFO full status |
| empty | 1 | FIFO empty status |
| count | COUNT_WIDTH | Current FIFO occupancy |

# 10. Parameter Configuration

The design supports configurable data width, memory depth, pointer width, and counter width.

| Parameter | Default | Description |
|---|---:|---|
| DATA_WIDTH | 8 | Number of bits per FIFO word |
| DEPTH | 16 | Number of memory locations |
| ADDR_WIDTH | 4 | Width of read/write pointers |
| COUNT_WIDTH | 5 | Width of occupancy counter |

### Example Configuration

```verilog
fpga_sync_read_fifo #(

    .DATA_WIDTH(8),

    .DEPTH(16),

    .ADDR_WIDTH(4),

    .COUNT_WIDTH(5)

) DUT (

    // Port connections

);
```

### Parameter Design Requirements

For reliable configuration:

- `DATA_WIDTH` must be greater than zero.
- `DEPTH` must be greater than zero.
- `ADDR_WIDTH` must be sufficient to represent addresses from 0 to DEPTH-1.
- `COUNT_WIDTH` must be sufficient to represent values from 0 to DEPTH.

A safe minimum sizing rule is:

```text
ADDR_WIDTH  >= ceil(log2(DEPTH))

COUNT_WIDTH >= ceil(log2(DEPTH + 1))
```

For DEPTH = 1, use at least one bit for the pointer.

The explicit pointer wraparound logic allows non-power-of-two depths, provided the pointer and counter widths are configured correctly.

# 11. Testbench and Verification

A dedicated testbench, `tb_fpga_sync_read_fifo`, has been developed to verify the FIFO functionality.

The testbench applies different input conditions and checks the resulting FIFO outputs, status flags, and occupancy.

## 11.1 Verification Coverage

| Test No. | Verification Item | Expected Result |
|---|---|---|
| 1 | Synchronous reset | Pointers and count cleared |
| 2 | Basic write operation | Occupancy increases |
| 3 | FIFO read and data ordering | Correct FIFO sequence |
| 4 | Empty condition | Read rejected |
| 5 | FIFO full condition | Full flag asserted |
| 6 | Write while full | Write rejected |
| 7 | Read after full | Oldest data returned |
| 8 | Simultaneous read/write | Occupancy unchanged |
| 9 | Pointer wraparound | Correct data ordering |
| 10 | Final result | All tests pass |

Additional checks include:

- `data_valid` assertion after accepted reads.
- `data_valid` deassertion during idle cycles.
- Output-data retention when no read is accepted.
- Occupancy stability when both operations are rejected.
- Correct behavior of the Full and Empty flags.

## 11.2 Internal Memory Observation

The testbench provides a memory mirror using hierarchical references:

```verilog
assign mem_view[g] = DUT.memory[g];
```

This allows internal FIFO memory locations to be observed directly in the XSIM waveform window.

The following internal signals can also be monitored:

```verilog
wr_ptr_view
rd_ptr_view
mem_view
```

This is useful for understanding memory addressing, pointer movement, and circular FIFO behavior.

**Note:** FIFO memory is intentionally not reset. Its locations may initially display unknown (`X`) values until written.

# 12. Simulation Procedure

The project is designed for Xilinx Vivado 2025.2.1 and XSIM.

### Step 1: Create a Vivado Project

Create a new RTL project and select the appropriate FPGA device.

Target platform:

```text
FPGA Family : Xilinx Artix-7
Board       : Arty A7-100T
Tool        : Vivado 2025.2.1
```

### Step 2: Add Design Source

Add:

```text
fpga_sync_read_fifo.v
```

Set the top module to:

```text
fpga_sync_read_fifo
```

### Step 3: Add Simulation Source

Add:

```text
tb_fpga_sync_read_fifo.v
```

Set the simulation top module to:

```text
tb_fpga_sync_read_fifo
```

### Step 4: Run Behavioral Simulation

Select:

```text
Run Simulation
      |
      v
Run Behavioral Simulation
```

### Step 5: Examine Waveforms

Monitor the following signals:

```text
clk
rst
wr_en
data_in
rd_en
data_out
data_valid
full
empty
count
wr_ptr_view
rd_ptr_view
mem_view
```

### Step 6: Check Simulation Results

The testbench reports individual PASS and ERROR messages.

The expected successful completion message is:

```text
================================================

ALL TESTS PASSED SUCCESSFULLY!

================================================
```

# 13. Synthesis and FPGA Implementation

After successful behavioral simulation, proceed with RTL synthesis.

Recommended Vivado workflow:

```text
RTL Design
    |
    v
Elaboration
    |
    v
Synthesis
    |
    v
Memory Resource Analysis
    |
    v
Implementation
    |
    v
Timing Analysis
    |
    v
FPGA Bitstream Generation
```

## 13.1 Important Synthesis Reports

Inspect the following reports:

**1. Synthesis Utilization Report**

Check:

- Block RAM utilization.
- LUT utilization.
- Flip-flop utilization.
- Other memory-related resources.

**2. Synthesized Design Schematic**

Inspect the inferred memory and associated control logic.

**3. Timing Summary**

Check:

- Maximum operating frequency.
- Setup timing.
- Hold timing.
- Critical paths.

**4. Memory Inference Results**

Confirm whether the memory was mapped to:

- Block RAM (BRAM).
- Distributed RAM.
- Other FPGA resources.

Do not assume BRAM inference solely from the RTL coding style.

# 14. Reset and Memory Initialization

The FIFO uses a synchronous, active-high reset.

On the rising clock edge when reset is asserted:

- Write pointer is cleared.
- Read pointer is cleared.
- Output register is cleared.
- Data-valid flag is cleared.
- Occupancy counter is cleared.

The memory array itself is not reset.

This is intentional because resetting every memory location may prevent or complicate inference of certain FPGA memory resources.

After reset, the FIFO is logically empty, so uninitialized memory contents are not considered valid FIFO data.

# 15. Design Limitations and Engineering Considerations

This implementation is intended as an FPGA-oriented synchronous FIFO learning design.

The following considerations are important before using it in a larger system.

1. The FIFO uses a single clock domain. It is not an asynchronous FIFO.
2. The design does not implement Gray-code pointers or clock-domain crossing synchronization.
3. The read operation is synchronous.
4. Memory inference is target- and synthesis-dependent.
5. The design uses an occupancy counter for Full and Empty detection.
6. Simultaneous operations at Full and Empty boundaries use current-state acceptance logic.
7. There is no programmable Almost Full or Almost Empty threshold.
8. There is no overflow or underflow error counter.
9. There is no memory initialization mechanism.
10. No explicit memory collision-mode configuration is included.
11. No output reset or memory reset should be confused with a guarantee of physical memory initialization.

For production applications, additional features may be required, including programmable thresholds, error reporting, configurable output latency, and interface-level flow control.

# 16. Suggested Applications

Synchronous FIFO memory architectures are commonly useful in:

- FPGA data buffering.
- Digital communication systems.
- Packet buffering.
- DSP processing pipelines.
- Data acquisition systems.
- UART and serial communication buffering.
- Video processing pipelines.
- Hardware accelerators.
- Producer-consumer data interfaces.
- Temporary storage between processing stages.

# 17. Learning Outcomes

After studying and implementing this project, the learner should understand:

1. How synchronous FIFO memory works.
2. The difference between synchronous and asynchronous memory reads.
3. How registered memory outputs are implemented.
4. How FIFO pointers control circular memory access.
5. How occupancy counters generate FIFO status.
6. How simultaneous read/write operations affect FIFO occupancy.
7. How to protect memory against invalid operations.
8. How `data_valid` qualifies registered output data.
9. How testbenches verify memory-oriented RTL designs.
10. How FPGA synthesis reports confirm actual hardware resource mapping.

The most important lesson is that **RTL functionality and FPGA hardware implementation are two related but different engineering considerations.**

# 18. Project Directory Structure

Recommended project organization:

```text
Level_5_Synchronous_FIFO/
|
+-- README.md
|
+-- RTL/
|   |
|   +-- fpga_sync_read_fifo.v
|
+-- Testbench/
|   |
|   +-- tb_fpga_sync_read_fifo.v
|
+-- Simulation/
|   |
|   +-- waveform_notes.md
|   +-- simulation_results/
|
+-- Reports/
|   |
|   +-- synthesis_utilization/
|   +-- timing_summary/
|   +-- memory_inference/
|
+-- Documentation/
    |
    +-- FIFO_Architecture.md
    +-- Design_Notes.md
```

# 19. Future Development Roadmap

This Level-5 implementation provides a foundation for more advanced FPGA memory architectures.

Suggested progression:

| Level | FIFO Architecture | Main Learning Objective |
|---|---|---|
| Level 1 | Basic Synchronous FIFO | Fundamental FIFO operation |
| Level 2 | Parameterized FIFO | Configurable data width and depth |
| Level 3 | Advanced Control FIFO | Improved status and control logic |
| Level 4 | Synchronous FIFO with Enhanced Memory Handling | Memory-oriented RTL development |
| **Level 5** | **FPGA-Oriented Synchronous-Read FIFO** | **Registered reads and memory inference** |
| Level 6 | BRAM-Oriented FIFO Optimization | Explicit memory implementation considerations |
| Level 7 | FIFO with Almost Full/Almost Empty | Advanced flow control |
| Level 8 | Asynchronous FIFO | Clock-domain crossing |
| Level 9 | Gray-Code Asynchronous FIFO | Safe pointer synchronization |
| Level 10 | Advanced Asynchronous FIFO | Robust CDC and error monitoring |

# 20. Conclusion

The FPGA-Oriented Synchronous-Read FIFO represents an important step from basic FIFO logic toward practical FPGA memory implementation.

By introducing registered memory reads, independent circular pointers, occupancy tracking, accepted-operation logic, and data-valid signaling, this design demonstrates how FIFO functionality can be implemented using an FPGA-conscious RTL coding methodology.

The dedicated self-checking testbench provides functional verification, while Vivado synthesis reports provide the means to investigate the actual hardware resource mapping.

The next stage is to explore more advanced memory optimization techniques and progressively develop robust FPGA FIFO architectures.

---

**Developed by: Ghulam Yaseen Nangraj**

**Project:** FPGA-Oriented Synchronous-Read FIFO  
**Learning Level:** Level 5  
**HDL:** Verilog-2001  
**Platform:** Xilinx Artix-7 / Vivado 2025.2.1

*Engineering principle: Understand the RTL. Verify the functionality. Analyze the synthesis. Confirm the hardware implementation.*

---
