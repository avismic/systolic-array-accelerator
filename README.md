
# Parameterizable Systolic‑Array Accelerator

> A SystemVerilog implementation of an N×N systolic array for high‑throughput matrix multiplication, verified with cocotb + NumPy. Designed for an NVIDIA NCG interview project.

## Table of Contents
- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Getting Started (Cloud)](#getting-started-cloud)
- [Running the Simulation](#running-the-simulation)
- [Waveform](#waveform)
- [Design Files](#design-files)
- [How It Works (Latency, Skew, etc.)](#how-it-works)
- [Future Work](#future-work)
- [Resume Highlights](#resume-highlights)

## Features
- Fully parameterizable **grid size `N`**, **data width**, **accumulator width**.
- Input‑skewing buffers automatically generate required pipeline delays.
- Pure‑SystemVerilog design (compatible with ASIC flow).
- **cocotb** test‑bench compares RTL output to NumPy gold‑model.
- Cloud‑native: runs in GitHub Codespaces, no local EDA install required.
- CI pipeline via GitHub Actions with waveform artifact.

## Architecture Overview
- **PE (`pe.sv`)** – multiply‑accumulate + forward ports.
- **Skew Buffer (`skew_buffer.sv`)** – configurable shift register.
- **Systolic Array (`systolic_array.sv`)** – N×N mesh of PEs.
- **Top (`top.sv`)** – integrates skew buffers, array, and streaming I/O.

![Systolic Array Diagram](docs/array_diagram.png)

## Getting Started (Cloud)

```bash
# 1. Create a Codespace from the repo (GitHub UI → Code → Codespaces → New)
# 2. In the terminal inside the codespace:
sudo apt update && sudo apt install -y iverilog gtkwave
pip install --upgrade pip
pip install cocotb numpy
