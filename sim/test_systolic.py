import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import numpy as np

N          = 4
DATA_WIDTH = 8
ACC_WIDTH  = 32

def pack_row(vals, width=DATA_WIDTH):
    """Pack a list of N integers into a single flat integer bus."""
    result = 0
    for i, v in enumerate(vals):
        result |= (int(v) & ((1<<width)-1)) << (i*width)
    return result

def unpack_result(flat_int, n=N, width=ACC_WIDTH):
    """Unpack flat integer into N×N matrix."""
    mask = (1<<width)-1
    C = np.zeros((n,n), dtype=np.int64)
    for i in range(n):
        for j in range(n):
            C[i][j] = (flat_int >> ((i*n+j)*width)) & mask
    return C

@cocotb.test()
async def test_matmul(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.a_in_flat.value = 0
    dut.b_in_flat.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    dut._log.info("Reset done.")

    A = np.random.randint(1, 8, (N,N), dtype=np.int32)
    B = np.random.randint(1, 8, (N,N), dtype=np.int32)
    C_golden = A @ B
    dut._log.info(f"A:\n{A}\nB:\n{B}\nExpected:\n{C_golden}")

    # Feed N cycles: cycle k feeds column k of A and row k of B
    for cycle in range(N + 3*N):
        if cycle < N:
            a_vals = [A[row][cycle] for row in range(N)]
            b_vals = [B[cycle][col] for col in range(N)]
        else:
            a_vals = [0]*N
            b_vals = [0]*N
        dut.a_in_flat.value = pack_row(a_vals)
        dut.b_in_flat.value = pack_row(b_vals)
        await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 3*N)

    raw = dut.c_out_flat.value.to_unsigned()
    C_rtl = unpack_result(raw)
    dut._log.info(f"RTL result:\n{C_rtl}")

    passed = True
    for i in range(N):
        for j in range(N):
            if C_rtl[i][j] != C_golden[i][j]:
                dut._log.error(f"MISMATCH C[{i}][{j}]: got {C_rtl[i][j]}, expected {C_golden[i][j]}")
                passed = False
            else:
                dut._log.info(f"  C[{i}][{j}] = {C_rtl[i][j]} ✓")

    assert passed, "❌ FAILED"
    dut._log.info("✅ ALL PASSED!")