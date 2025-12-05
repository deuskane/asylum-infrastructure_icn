# asylum-infrastructure_icn

Interconnection component based on OR-Bus protocol for the Asylum project. This repository contains an SBI (Serial Bus Interface) interconnect infrastructure that routes transactions between initiator ports and multiple target ports.

## Table of Contents

1. [Introduction](#introduction)
2. [Modules](#modules)
   - [sbi_icn](#sbi_icn)
   - [sbi_wrapper_target](#sbi_wrapper_target)
3. [Project Structure](#project-structure)
4. [Building and Using](#building-and-using)

---

## Introduction

The asylum-infrastructure_icn repository provides the core interconnection logic for the Asylum project. It implements an SBI-based (Serial Bus Interface) interconnect that:

- Routes transactions from a single initiator to multiple targets
- Supports configurable address decoding (binary or one-hot encoding)
- Implements two selection algorithms: OR-based and MUX-based
- Provides address and size customization per target

The interconnect is designed to work with the Asylum SBI protocol and follows VHDL best practices with proper reset and clock management.

---

## Modules

### sbi_icn

**File:** `hdl/sbi_icn.vhd`

The main interconnect module that routes SBI transactions from an initiator port to multiple target ports.

#### Generics

| Generic | Type | Default | Description |
|---------|------|---------|-------------|
| `NB_TARGET` | positive | 1 | Number of target ports in the interconnect |
| `TARGET_ID` | sbi_addrs_t | - | Array of target IDs for address decoding (one per target) |
| `TARGET_ADDR_WIDTH` | naturals_t | - | Array of address widths for each target (defines the IP address space size) |
| `TARGET_ADDR_ENCODING` | string | - | Address encoding scheme: `"binary"` for binary ID encoding or `"one_hot"` for one-hot encoding |
| `ALGO_SEL` | string | "or" | Selection algorithm: `"or"` for OR-based response or `"mux"` for multiplexed response |

#### Ports

| Port | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock input |
| `cke_i` | in | std_logic | Clock enable signal |
| `arst_b_i` | in | std_logic | Asynchronous reset (active low) |
| `sbi_ini_i` | in | sbi_ini_t | Initiator request (from bus master) |
| `sbi_tgt_o` | out | sbi_tgt_t | Initiator response (to bus master) |
| `sbi_inis_o` | out | sbi_inis_t[NB_TARGET-1:0] | Array of target requests (to targets) |
| `sbi_tgts_i` | in | sbi_tgts_t[NB_TARGET-1:0] | Array of target responses (from targets) |

#### Operation

The `sbi_icn` module performs the following functions:

1. **Address Decoding:** Extracts target ID from the incoming address based on the TARGET_ADDR_WIDTH configuration to determine which target should be addressed.

2. **Request Routing:** Routes the incoming SBI initiator request (`sbi_ini_i`) to all target ports (`sbi_inis_o`). Each target's chip select is determined by its TARGET_ID matching the decoded address.

3. **Response Aggregation:** Combines responses from all targets into a single response sent back to the initiator:
   - **OR Algorithm** (`ALGO_SEL="or"`): Uses bitwise OR to aggregate all target responses. This assumes open-drain/wired-OR protocol where multiple drivers can drive simultaneously.
   - **MUX Algorithm** (`ALGO_SEL="mux"`): Multiplexes the response from the selected target. Only the target with matching ID drives the response; others are zeroed.

4. **Address Encoding:** 
   - **Binary**: TARGET_ID is treated as a numerical value that matches against the decoded address MSBs.
   - **One-Hot**: TARGET_ID is treated as a one-hot encoded vector where exactly one bit indicates the target's selection index.

#### Internal Structure

The module instantiates `NB_TARGET` instances of `sbi_wrapper_target`, each responsible for:
- Decoding its portion of the address space
- Controlling chip select for its associated IP
- Forwarding the address to the IP with proper size adjustment

---

### sbi_wrapper_target

**File:** `hdl/sbi_wrapper_target.vhd`

A wrapper module that adapts an SBI interface from the interconnect to a target IP's interface, handling address decoding and chip select generation.

#### Generics

| Generic | Type | Default | Description |
|---------|------|---------|-------------|
| `SIZE_DATA` | natural | 8 | Data width in bits (typically set to `SBI_DATA_WIDTH` constant) |
| `SIZE_ADDR_IP` | natural | 0 | Address width for the IP's address space (number of LSBs forwarded to IP) |
| `ID` | std_logic_vector | (others=>'0') | Target ID for address matching (length = `SBI_ADDR_WIDTH`) |
| `ADDR_ENCODING` | string | "binary" | Address encoding scheme: `"binary"` or `"one_hot"` |
| `TGT_ZEROING` | boolean | false | Enable response zeroing when this target is not selected (used in OR mode) |

#### Ports

| Port | Direction | Type | Description |
|------|-----------|------|-------------|
| `cs_o` | out | std_logic | Chip select output to IP (1 = selected) |
| `sbi_ini_i` | in | sbi_ini_t | Initiator request from bus |
| `sbi_tgt_i` | in | sbi_tgt_t | Response from IP |
| `sbi_ini_o` | out | sbi_ini_t | Initiator request to IP (with adjusted address) |
| `sbi_tgt_o` | out | sbi_tgt_t | Response to bus |

#### Operation

The `sbi_wrapper_target` module performs the following functions:

1. **Address Decoding:** Extracts the target ID bits from the incoming address and compares with its configured ID:
   - **Binary mode**: Extracts MSBs as a binary value and compares for equality.
   - **One-Hot mode**: Checks the bit at position `IDX` (derived from the one-hot ID).

2. **Chip Select Generation:** Generates `cs_o` = '1' when the decoded ID matches this target's ID, '0' otherwise.

3. **Address Adjustment:** Removes the ID bits from the address and forwards only the lower `SIZE_ADDR_IP` bits to the IP, allowing the IP to address its own address space directly.

4. **Request Forwarding:** Passes through control signals (`re`, `we`, `cs`) and data (`wdata`) from the bus to the IP, modified by the chip select.

5. **Response Handling:**
   - **With TGT_ZEROING=true**: Returns the IP response only when selected (cs='1'), returns zeros and ready='1' when not selected.
   - **With TGT_ZEROING=false**: Always forwards IP response regardless of selection (used in MUX mode where only selected target's response matters).

---

## Project Structure

```
asylum-infrastructure_icn/
├── README.md                    # This file
├── ICN.core                     # FuseSoC core definition
└── hdl/
    ├── icn_pkg.vhd              # Package containing component declarations
    ├── sbi_icn.vhd              # Main interconnect entity
    └── sbi_wrapper_target.vhd    # Target wrapper entity
```

### File Descriptions

- **`ICN.core`** - FuseSoC core file that defines the project as a reusable component. Specifies version 1.2.2, file dependencies, and build targets.

- **`hdl/icn_pkg.vhd`** - VHDL package file containing the component declarations for `sbi_icn` and `sbi_wrapper_target`, allowing them to be instantiated in other designs.

- **`hdl/sbi_icn.vhd`** - Implementation of the main interconnect. Handles address decoding, target selection, and response aggregation using either OR or MUX algorithm.

- **`hdl/sbi_wrapper_target.vhd`** - Implementation of the target wrapper. Each instance handles a single target's address space and provides the adaptation layer between the SBI bus and the target IP.

