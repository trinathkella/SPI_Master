# SPI Master for TDC7200

A synthesizable SystemVerilog SPI master designed to interface an FPGA (AMD Xilinx Zynq UltraScale+ MPSoC) with the Texas Instruments **TDC7200** Time-to-Digital Converter, for a photon-counting application in a photonic quantum processor control system.

## Overview

The TDC7200 exposes its configuration, status, and measurement-result registers over a 4-wire SPI-like interface (`CSB`, `SCLK`, `DIN`, `DOUT`). This module acts purely as a protocol engine — it takes a simple parallel command (address, read/write, width, write-data) from upstream FPGA logic and produces the correctly-timed serial transaction on the physical interface, with **no knowledge of what any given register means**. That semantic layer (which register to read, when, and what to do with the result) is intentionally kept outside this module, the same way a generic SPI controller's hardware knows nothing about the device it's talking to — that intelligence lives in whatever drives it.

## Protocol summary (from the TDC7200 datasheet)

- **Command byte** (always sent first, MSB-first): `[Auto-Increment | R/W | Address(6-bit)]`
- **Write** = 8-bit command + 8-bit data = 16 SCLK edges
- **Read** = 8-bit command + 8 or 24 bits of data (register-dependent) = 16 or 32 SCLK edges
- Data is latched on SCLK's **rising edge**; SCLK may idle high or low, so the TDC7200 is compatible with SPI **Mode 0 or Mode 3**. This design uses **Mode 0** (CPOL=0).
- `CSB` must remain low for the full duration of a transaction (command + data) and is subject to fixed setup (`t6`) and hold (`t7`) timing requirements before/after the first/last SCLK edge.
- Registers `00h–09h` are 8-bit (CONFIG1, CONFIG2, INT_STATUS, etc.); `10h–1Ch` are 24-bit (TIME1–6, CLOCK_COUNT1–5, CALIBRATION1/2). Addresses `0Ah–0Fh` are reserved.

## Interface

| Port | Direction | Description |
|---|---|---|
| `clk`, `rst_n` | in | System clock, active-low async reset |
| `start` | in | One-cycle pulse to begin a transaction |
| `addr[5:0]` | in | Target register address |
| `rw` | in | 0 = read, 1 = write |
| `auto_inc` | in | Auto-increment bit for chained register access |
| `width_flag` | in | 0 = 8-bit data phase, 1 = 24-bit data phase |
| `wr_data[7:0]` | in | Write data (ignored for reads) |
| `rd_data[23:0]` | out | Captured read data, valid when `done` pulses |
| `done` | out | One-cycle pulse on transaction completion |
| `busy` | out | High while a transaction is in progress |
| `sclk`, `csb`, `din` | out | Physical interface to the TDC7200 |
| `dout` | in | Physical interface from the TDC7200 |

## References

1. Texas Instruments, *TDC7200 Time-to-Digital Converter for Time-of-Flight Applications Datasheet* — https://www.ti.com/product/TDC7200
2. Analog Devices, *Introduction to SPI Interface* — https://www.analog.com/en/analog-dialogue/articles/introduction-to-spi-interface.html
