<!--
  README GENERATION INSTRUCTIONS (for the next regeneration run)
  ----------------------------------------------------------------
  This README follows the common Asylum IP model. Regenerate it from the
  sources, never from the previous README text alone.

  Sources of truth (in priority order):
    1. hdl/*.vhd            : entities, generics, ports, packages
    2. hdl/csr/*.hjson      : register map (regtool); *_csr.md/.h are generated
    3. <IP>.core            : VLNV (name), filesets, targets, depends, revisions
    4. mk/targets.txt       : target list shown by `make help`; mk/defs.mk
    5. sim/, syn/, esw/, boards/ : testbenches, constraints, software
  Section order (keep it, same headings in every IP):
    CI badge / Title + one-line description + VLNV / Table of Contents /
    Introduction (Key Features) / Block Diagram / Top-Level (Parameters,
    Ports, Instantiation Example) / HDL Modules / Register Map /
    Verification / Synthesis / Design Notes (optional) /
    Directory Structure / Dependencies
  Rules:
    - Language: English. Tables: Parameters = Name|Type|Default|Description,
      Ports = Name|Direction|Type|Description (grouped by interface).
    - Register Map: link to the generated hdl/csr/<X>_csr.md (plus the
      .hjson source and _csr.h header); never copy register tables here.
    - Top-Level = sbi_* wrapper if present, else the entity used by the
      `default` target, else the main entity (libraries: list packages).
    - Write "This IP has no software-visible registers." / "No dedicated
      synthesis target ..." instead of removing a section.
    - Keep still-accurate hand-written content (ISA tables, results,
      images) in "Design Notes"; drop anything not backed by the sources.
    - Block diagram: doc/<NAME>.drawio (NAME = 4th field of the VLNV),
      top entity box with generics on top, inputs left, outputs right,
      bus interfaces as bold arrows, internal blocks colour-coded
      (CSR yellow, FIFO/memory green, core logic blue, external grey).
      Update it whenever ports/generics/sub-blocks change.
    - Do not edit generated files (hdl/csr/*_csr.*) or the CI badge URL.
-->
[![CI](https://github.com/deuskane/asylum-infrastructure_icn/actions/workflows/ci.yml/badge.svg)](https://github.com/deuskane/asylum-infrastructure_icn/actions/workflows/ci.yml)

# asylum-infrastructure_icn

**SBI interconnect: N masters to M targets with fixed-priority or round-robin arbitration, binary or one-hot address decoding, default slave and optional pipeline stages.**

VLNV: `asylum:infrastructure:icn:1.3.4`

## Table of Contents

1. [Introduction](#introduction)
2. [Block Diagram](#block-diagram)
3. [Top-Level](#top-level)
4. [HDL Modules](#hdl-modules)
5. [Register Map](#register-map)
6. [Verification](#verification)
7. [Synthesis](#synthesis)
8. [Design Notes](#design-notes)
9. [Directory Structure](#directory-structure)
10. [Dependencies](#dependencies)

## Introduction

This IP is the bus interconnect of the Asylum SoCs. `sbi_icn` connects `NB_MASTER` SBI initiators to `NB_TARGET` SBI targets: an arbiter grants one master at a time, each target is selected by an address decoder (`sbi_wrapper_target`) that forwards only its local address bits, and the responses are merged back (wired-OR or multiplexer) to the granted master. Accesses that hit no target are answered by a default slave (internal, or an external target connected to the last port). Optional `sbi_pipe` stages can be inserted on every master input and on every target output to cut timing paths. In simulation, the interconnect prints its address map and checks it (one-hot IDs, alignment, overlaps).

### Key Features

- `NB_MASTER` initiator ports, arbitration `MASTER_SEL = "fix"` (lowest index first) or `"roundrobin"`
- `NB_TARGET` target ports with a base address (`TARGET_ID`) and a local address width (`TARGET_ADDR_WIDTH`) per target
- Address decoding `TARGET_ADDR_ENCODING = "binary"` (address MSBs compared with the ID) or `"one_hot"` (one address bit per target)
- Response merge `TARGET_SEL = "or"` (non-selected targets zeroed, then ORed) or `"mux"` (selected target)
- Default slave for unmapped addresses: internal `sbi_default_slave` (ready, read data 0) or external, on the last target port (`INTERNAL_DEFAULT_SLAVE = False`)
- Optional registered stage per master input (`PIPEIN_ENABLE`) and per target output (`PIPEOUT_ENABLE`)
- Response `info.name` set to `NAME`; target names used in the simulation reports
- Simulation-only elaboration checks of the address map
- Component declarations of all entities in `asylum.icn_pkg`

## Block Diagram

Diagram: [doc/icn.drawio](doc/icn.drawio) (open with diagrams.net or the VS Code Draw.io extension).

- Each master request `sbi_inis_i(m)` goes through an `sbi_pipe` (`ENABLE = PIPEIN_ENABLE = '1'`), then to the arbiter `sbi_icn_mux_mst`, which forwards the request of the granted master (`sbi_ini_mux`).
- `NB_TARGET_INT` `sbi_wrapper_target` instances (`NB_TARGET`, or `NB_TARGET-1` with an external default slave) decode the address, generate `tgt_cs` and forward the local address to the target.
- When no target is selected (`any_cs = 0`), the request is presented to the default slave: the internal `sbi_default_slave`, or the wrapper of the last target port.
- Each target port goes through an `sbi_pipe` (`ENABLE = PIPEOUT_ENABLE(tgt) = '1'`) to `sbi_inis_o(tgt)` / `sbi_tgts_i(tgt)`.
- `sbi_icn_mux_tgt` merges the target and default-slave responses (OR or mux) into `sbi_tgt_mux`, which the arbiter returns to the granted master only.

## Top-Level

Top-level entity: **`sbi_icn`** ([hdl/sbi_icn.vhd](hdl/sbi_icn.vhd)), library `asylum`, component declared in `asylum.icn_pkg`.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `NAME` | string | `"sbi_icn"` | Instance name: returned in `sbi_tgts_o(m).info.name`, used in simulation reports and forwarded to all sub-instances |
| `NB_MASTER` | positive | `1` | Number of initiator ports |
| `MASTER_SEL` | string | `"fix"` | Arbitration: `"fix"` (fixed priority, master 0 first) or `"roundrobin"` |
| `NB_TARGET` | positive | `1` | Number of target ports (including the external default slave when `INTERNAL_DEFAULT_SLAVE = False`) |
| `TARGET_SEL` | string | `"or"` | Response merge: `"or"` (responses of non-selected targets forced to 0, then ORed) or `"mux"` |
| `TARGET_ID` | sbi_addrs_t | *(none)* | Base address (`binary`) or one-hot select vector (`one_hot`) of each target, `SBI_ADDR_WIDTH` bits each |
| `TARGET_ADDR_WIDTH` | naturals_t | *(none)* | Local address width of each target (number of LSBs forwarded) |
| `TARGET_ADDR_ENCODING` | string | *(none)* | `"binary"` or `"one_hot"` |
| `INTERNAL_DEFAULT_SLAVE` | boolean | `True` | `True`: internal `sbi_default_slave`; `False`: the last target port (`NB_TARGET-1`) is the default slave, selected when no other target matches |
| `PIPEOUT_ENABLE` | std_logic_vector(NB_TARGET-1 downto 0) | `(others => '0')` | Per target: `'1'` inserts an `sbi_pipe` stage on the target port |
| `PIPEIN_ENABLE` | std_logic | `'0'` | `'1'` inserts an `sbi_pipe` stage on every master port |

### Ports

#### Clock & Reset

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock |
| `cke_i` | in | std_logic | Clock enable (arbiter and pipe stages) |
| `arst_b_i` | in | std_logic | Asynchronous reset, active low |

#### Bus (SBI) - Masters

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `sbi_inis_i` | in | sbi_inis_t(NB_MASTER-1 downto 0) | Requests from the initiators (`cs`, `re`, `we`, `addr`, `wdata`) |
| `sbi_tgts_o` | out | sbi_tgts_t(NB_MASTER-1 downto 0) | Responses to the initiators (`ready` only for the granted master, `rdata`, `info.name = NAME`) |

#### Bus (SBI) - Targets

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `sbi_inis_o` | out | sbi_inis_t(NB_TARGET-1 downto 0) | Requests to the targets (`cs` decoded, local address zero-extended) |
| `sbi_tgts_i` | in | sbi_tgts_t(NB_TARGET-1 downto 0) | Responses from the targets (`ready`, `rdata`, `info`) |

### Instantiation Example

```vhdl
library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;

  -- 2 masters, 3 targets: 0x00-0x3F, 0x40-0x7F, 0x80-0x87
  ins_sbi_icn : entity asylum.sbi_icn
    generic map
    ( NAME                   => "icn"
     ,NB_MASTER              => 2
     ,MASTER_SEL             => "roundrobin"
     ,NB_TARGET              => 3
     ,TARGET_SEL             => "mux"
     ,TARGET_ID              => (0 => x"00", 1 => x"40", 2 => x"80")
     ,TARGET_ADDR_WIDTH      => (0 => 6,     1 => 6,     2 => 3    )
     ,TARGET_ADDR_ENCODING   => "binary"
     ,INTERNAL_DEFAULT_SLAVE => true
     ,PIPEOUT_ENABLE         => "100"   -- pipe stage on target 2 only
     ,PIPEIN_ENABLE          => '0'
    )
    port map
    ( clk_i      => clk
     ,cke_i      => '1'
     ,arst_b_i   => arst_b
     ,sbi_inis_i => mst_sbi_inis   -- sbi_inis_t(1 downto 0)(addr(7 downto 0), wdata(7 downto 0))
     ,sbi_tgts_o => mst_sbi_tgts   -- sbi_tgts_t(1 downto 0)(rdata(7 downto 0))
     ,sbi_inis_o => tgt_sbi_inis   -- sbi_inis_t(2 downto 0)(addr(7 downto 0), wdata(7 downto 0))
     ,sbi_tgts_i => tgt_sbi_tgts   -- sbi_tgts_t(2 downto 0)(rdata(7 downto 0))
    );
```

The internal response signals are constrained with `SBI_DATA_WIDTH` (8 bits, `asylum.sbi_pkg`); the request `addr` / `wdata` widths follow `sbi_inis_i(0)`.

## HDL Modules

| File | Unit | Kind | Role |
|------|------|------|------|
| [hdl/icn_pkg.vhd](hdl/icn_pkg.vhd) | `icn_pkg` | package | Component declarations of all the entities below |
| [hdl/sbi_icn.vhd](hdl/sbi_icn.vhd) | `sbi_icn` | entity | Top-level interconnect: pipes, arbiter, decoders, default slave, response merge, simulation checks |
| [hdl/sbi_icn_mux_mst.vhd](hdl/sbi_icn_mux_mst.vhd) | `sbi_icn_mux_mst` | entity | Master arbiter and request multiplexer |
| [hdl/sbi_icn_mux_tgt.vhd](hdl/sbi_icn_mux_tgt.vhd) | `sbi_icn_mux_tgt` | entity | Target response merge (OR / mux) with default-slave response |
| [hdl/sbi_wrapper_target.vhd](hdl/sbi_wrapper_target.vhd) | `sbi_wrapper_target` | entity | Address decoder of one target: chip select, local address, optional response zeroing |
| [hdl/sbi_pipe.vhd](hdl/sbi_pipe.vhd) | `sbi_pipe` | entity | Optional registered SBI stage (request and response) |
| [hdl/sbi_default_slave.vhd](hdl/sbi_default_slave.vhd) | `sbi_default_slave` | entity | Default slave: always ready, read data 0 |

### sbi_icn_mux_mst

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `NAME` | string | `"sbi_icn"` | Instance name (not used in the architecture) |
| `NB_MASTER` | positive | `1` | Number of masters |
| `MASTER_SEL` | string | `"fix"` | `"fix"`: lowest-index requesting master; `"roundrobin"`: search starts after the last granted master |

#### Ports

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock |
| `cke_i` | in | std_logic | Clock enable |
| `arst_b_i` | in | std_logic | Asynchronous reset, active low |
| `sbi_inis_i` | in | sbi_inis_t(NB_MASTER-1 downto 0) | Master requests |
| `sbi_tgts_o` | out | sbi_tgts_t(NB_MASTER-1 downto 0) | Master responses (`ready` forced to 0 except for the granted master) |
| `sbi_ini_o` | out | sbi_ini_t | Request of the granted master (`cs` gated by `busy`) |
| `sbi_tgt_i` | in | sbi_tgt_t | Response from the interconnect |

### sbi_icn_mux_tgt

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `NAME` | string | `"sbi_icn"` | Written in `sbi_tgt_o.info.name` |
| `NB_TARGET` | positive | `1` | Number of targets |
| `TARGET_SEL` | string | `"or"` | `"or"`: OR of all responses and of the default slave; `"mux"`: response of the target whose `tgt_cs_i` is set (highest index wins), default slave otherwise |

#### Ports

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `sbi_tgts_i` | in | sbi_tgts_t(NB_TARGET-1 downto 0) | Target responses (from the wrappers) |
| `sbi_tgt_ds_i` | in | sbi_tgt_t | Default slave response |
| `tgt_cs_i` | in | std_logic_vector(NB_TARGET-1 downto 0) | Target chip selects (used by `"mux"`) |
| `sbi_tgt_o` | out | sbi_tgt_t | Merged response |

### sbi_wrapper_target

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `NAME` | string | `"sbi_icn"` | Instance name (not used in the architecture) |
| `SIZE_DATA` | natural | `8` | Data width (not used in the architecture; `sbi_icn` passes `SBI_DATA_WIDTH`) |
| `SIZE_ADDR_IP` | natural | `0` | Local address width: number of address LSBs forwarded to the target |
| `ID` | std_logic_vector(SBI_ADDR_WIDTH-1 downto 0) | `(others => '0')` | Base address (`binary`) or one-hot select vector (`one_hot`) |
| `ADDR_ENCODING` | string | `"binary"` | `"binary"`: `cs` when `addr(MSB downto SIZE_ADDR_IP) = ID(MSB downto SIZE_ADDR_IP)`; `"one_hot"`: `cs` when `addr(IDX) = 1`, `IDX` = index of the bit set in `ID` |
| `TGT_ZEROING` | boolean | `false` | `true`: `rdata` and `ready` forced to 0 when the target is not selected |

#### Ports

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `cs_o` | out | std_logic | Target selected (`sbi_ini_i.cs` and address match) |
| `sbi_ini_o` | out | sbi_ini_t | Request to the target: decoded `cs`, `re` / `we` / `wdata` unchanged, `addr` = local address zero-extended |
| `sbi_tgt_i` | in | sbi_tgt_t | Response from the target |
| `sbi_ini_i` | in | sbi_ini_t | Request from the bus |
| `sbi_tgt_o` | out | sbi_tgt_t | Response to the bus (`info` forwarded from the target) |

### sbi_pipe

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `NAME` | string | `"sbi_icn"` | Prefix of the `VERBOSE` reports |
| `ENABLE` | boolean | `true` | `true`: registered stage; `false`: wires (`sbi_ini_o <= sbi_ini_i`, `sbi_tgt_o <= sbi_tgt_i`) |
| `VERBOSE` | boolean | `false` | Simulation only: report every write / read crossing the stage |

#### Ports

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock |
| `cke_i` | in | std_logic | Clock enable |
| `arst_b_i` | in | std_logic | Asynchronous reset, active low |
| `sbi_ini_i` | in | sbi_ini_t | Request from the initiator side |
| `sbi_tgt_o` | out | sbi_tgt_t | Response to the initiator side |
| `sbi_ini_o` | out | sbi_ini_t | Request to the target side |
| `sbi_tgt_i` | in | sbi_tgt_t | Response from the target side |

### sbi_default_slave

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `NAME` | string | `"sbi_icn"` | `info.name = NAME & ".default_slave"`, prefix of the simulation report |

#### Ports

| Name | Direction | Type | Description |
|------|-----------|------|-------------|
| `clk_i` | in | std_logic | Clock (simulation report only) |
| `cke_i` | in | std_logic | Clock enable (simulation report only) |
| `arst_b_i` | in | std_logic | Asynchronous reset, active low (not used) |
| `sbi_ini_i` | in | sbi_ini_t | Request |
| `sbi_tgt_o` | out | sbi_tgt_t | Response: `ready = cs`, `rdata = 0` |

## Register Map

This IP has no software-visible registers.

## Verification

### Testbenches

| File | DUT | Description |
|------|-----|-------------|
| [sim/tb_sbi_icn.vhd](sim/tb_sbi_icn.vhd) + [sim/tb_sbi_icn_pkg.vhd](sim/tb_sbi_icn_pkg.vhd), [sim/tb_sbi_icn_suite_pkg.vhd](sim/tb_sbi_icn_suite_pkg.vhd) | `sbi_icn` (`NB_MASTER = 2`, `"roundrobin"`, `NB_TARGET = 3`, IDs `0x00` / `0x40` / `0x80`, 6-bit local addresses, `"binary"`, `"mux"`, internal default slave; generics `PIPEIN` / `PIPEOUT` (default `false`) set `PIPEIN_ENABLE = '1'` / `PIPEOUT_ENABLE = "111"`) | UVVM testbench: two masters driven by the SBI BFM (`bitvis_vip_sbi`), three zero-wait-state memory models (64 bytes each) as targets. The suite runs TC1 to TC3 and ends with `report_alert_counters(FINAL)` |
| [sim/tb_sbi_icn_tc1_pkg.vhd](sim/tb_sbi_icn_tc1_pkg.vhd) | idem | TC1: write / read-check on each target, data written by one master and checked by the other |
| [sim/tb_sbi_icn_tc2_pkg.vhd](sim/tb_sbi_icn_tc2_pkg.vhd) | idem | TC2: default slave: write to `0xC0`, read `0xC0` and `0xFF` must return `0x00` |
| [sim/tb_sbi_icn_tc3_pkg.vhd](sim/tb_sbi_icn_tc3_pkg.vhd) | idem | TC3: exhaustive write / check of the 64 words of targets 0 and 1, then back-to-back accesses to different targets |

The masters access the bus one after the other: concurrent requests, `"fix"` arbitration, `"or"` merge, `"one_hot"` decoding and the external default slave are not exercised. `sim_pipe` runs the same suite with an `sbi_pipe` stage on every master and target port, so the `sbi_pipe` protocol check (request stable while pending) is active on all of them.

### Targets

| Target | Toplevel | Description |
|--------|----------|-------------|
| `default` | *(none)* | HDL fileset only (not a simulation) |
| `sim_basic` | `tb_sbi_icn` | Simulation of basic unit tests (GHDL, UVVM), no pipe stage |
| `sim_pipe` | `tb_sbi_icn` | Same suite with `PIPEIN=true`, `PIPEOUT=true` (`sbi_pipe` on all master and target ports) |

### How to Run

The default tool is GHDL (`mk/defs.mk`: `TOOL ?= ghdl`, `TARGET ?= sim_basic`).

```bash
make help                 # variables, rules and target list (mk/targets.txt)
make sim_basic            # run one target (log in log/)
make nonreg_sim           # run every sim_* target
make clean                # remove build/
```

Equivalent FuseSoC command:

```bash
fusesoc --cores-root . run --build-root build --target sim_basic asylum:infrastructure:icn:1.3.4
```

### Simulation Features

- `sim_basic` and `sim_pipe` analyze with `-Wall -fsynopsys -frelaxed --no-vital-checks` and run with `--fst=dut.fst --ieee-asserts=disable --assert-level=error` (waveform always written to `dut.fst`; any VHDL assertion of severity `error`, such as the `sbi_pipe` protocol check, stops the simulation with a failure).
- The `.core` parameters `PIPEIN` / `PIPEOUT` (bool, default `false`) are testbench generics used by `sim_pipe`.
- `sbi_icn` reports its configuration and the address range of every target (with the target `info.name`) and stops with a failure on: one-hot ID with more than one bit set, binary ID not aligned on its address width, external default slave without `ID = 0` and full address width, overlapping target ranges.
- `sbi_default_slave` reports every access (address) it receives.
- `sbi_pipe` (`VERBOSE = true`) reports the transactions. Out of reset, on every enabled clock edge in `PENDING` without `ready`, it checks that the initiator keeps its request stable (`sbi_ini_i = sbi_ini_o`, assertion of severity `error`) and sets the sticky flag `transaction_error_q` on a violation.

## Synthesis

No dedicated synthesis target. The HDL of the `default` target (VHDL-2008, `vhdlSource-2008`) is synthesizable: all simulation-only code (`report`, `wait`, protocol assertion) is enclosed in `pragma translate_off / translate_on` in `sbi_icn`, `sbi_pipe` and `sbi_default_slave`. Resource-relevant generics:

- `NB_MASTER` / `NB_TARGET`: width of the request and response multiplexers and number of decoders.
- `TARGET_SEL`: `"or"` adds zeroing gates per target and an OR tree; `"mux"` a priority multiplexer.
- `PIPEIN_ENABLE` / `PIPEOUT_ENABLE`: each enabled `sbi_pipe` registers a full request and response (and adds latency).
- The arbiter registers `master_id` and `busy` (plus `rr_ptr` with `"roundrobin"`).

## Design Notes

### Address Decoding

- `binary`: target `t` is selected when the address bits above `TARGET_ADDR_WIDTH(t)` equal those of `TARGET_ID(t)`; its range is `TARGET_ID(t) .. TARGET_ID(t) + 2**TARGET_ADDR_WIDTH(t) - 1`.
- `one_hot`: target `t` is selected when the address bit at the index of the bit set in `TARGET_ID(t)` is 1.
- The target receives `addr(TARGET_ADDR_WIDTH(t)-1 downto 0)` zero-extended to the bus width; `re`, `we` and `wdata` are broadcast to all targets, only `cs` is decoded.

### Arbitration and Latency

- The arbiter grants a master on a clock edge where it is idle (`busy = 0`) and that master has `cs = 1`; the request reaches the targets only once `busy = 1`, and `busy` is released on the edge where the granted transfer returns `ready = 1`. With zero-wait-state targets an access therefore takes two cycles, also with `NB_MASTER = 1`.
- `"roundrobin"` starts the search at the master following the last granted one; `"fix"` always starts at master 0.
- An enabled `sbi_pipe` runs `IDLE -> PENDING -> RESPONSE -> IDLE`: the request is registered in `IDLE`, held with `cs = 1` in `PENDING` until the target answers, and the registered response (`ready = 1`) is presented to the initiator during `RESPONSE`.

### Default Slave

- Internal (`INTERNAL_DEFAULT_SLAVE = True`): `sbi_default_slave` receives `cs = sbi_ini_mux.cs and not any_cs` (no target matched), answers `ready = cs` with `rdata = 0`.
- External (`INTERNAL_DEFAULT_SLAVE = False`): the last target port is decoded with the same gated `cs`, so it receives every access not claimed by targets `0 .. NB_TARGET-2`; its `TARGET_ID` must be 0 and its `TARGET_ADDR_WIDTH` the full address width (simulation check).

## Directory Structure

```
asylum-infrastructure_icn/
├── ICN.core                       # FuseSoC core (asylum:infrastructure:icn)
├── Makefile                       # Common Asylum Makefile (FuseSoC wrapper)
├── mk/
│   ├── defs.mk                    # FILE_CORE, default TARGET and TOOL
│   └── targets.txt                # Target list (generated from the .core)
├── doc/
│   └── icn.drawio                 # Block diagram
├── hdl/
│   ├── icn_pkg.vhd
│   ├── sbi_default_slave.vhd
│   ├── sbi_pipe.vhd
│   ├── sbi_icn_mux_mst.vhd
│   ├── sbi_icn_mux_tgt.vhd
│   ├── sbi_icn.vhd
│   └── sbi_wrapper_target.vhd
├── sim/
│   ├── tb_sbi_icn.vhd             # UVVM testbench top
│   ├── tb_sbi_icn_pkg.vhd         # SBI BFM interface array type
│   ├── tb_sbi_icn_suite_pkg.vhd   # Test suite (TC1..TC3)
│   ├── tb_sbi_icn_tc1_pkg.vhd
│   ├── tb_sbi_icn_tc2_pkg.vhd
│   └── tb_sbi_icn_tc3_pkg.vhd
└── .github/workflows/ci.yml       # CI (sim_basic, sim_pipe)
```

## Dependencies

| Core | Used by (fileset) | Purpose |
|------|-------------------|---------|
| `asylum:utils:pkg` | `hdl` | Common packages (`sbi_pkg`: SBI records and operators; `logic_pkg`: `count_ones`; `convert_pkg`: `onehot_to_integer`) |
| `bitvis:verification:uvvm` | `sim_basic` (targets `sim_basic`, `sim_pipe`) | UVVM utility library and SBI BFM (`bitvis_vip_sbi`) |
