# ---------------------------------------------------
# test_systolic.py – cocotb testbench for the systolic array
# ---------------------------------------------------
import random
import numpy as np
import cocotb
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure


# -----------------
# Helper utilities
# -----------------
def gen_matrix(N, bits):
    """Generate a random NxN unsigned integer matrix that fits into `bits`."""
    max_val = (1 << bits) - 1
    return np.random.randint(0, max_val + 1, size=(N, N), dtype=np.uint64)


def flatten_row_major(mat):
    """Return a Python list of the matrix elements row‑wise."""
    return mat.flatten().tolist()


def flatten_column_major(mat):
    """Column‑major order (used for B stream)."""
    return mat.T.flatten().tolist()


@cocotb.test()
async def systolic_array_test(dut):
    """
    End‑to‑end functional test:
      1. Reset the DUT.
      2. Send random matrices A (row‑major) and B (column‑major).
      3. Capture the output stream C.
      4. Compare with NumPy's matmul.
    """
    N          = int(dut.N.value) if hasattr(dut, "N") else 4   # if parameter accessible
    DATA_W     = int(dut.DATA_WIDTH.value) if hasattr(dut, "DATA_WIDTH") else 8
    ACC_W      = int(dut.ACC_WIDTH.value) if hasattr(dut, "ACC_WIDTH") else 32

    # -----------------------------------------------------------------
    # 1) Clock & Reset
    # -----------------------------------------------------------------
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Ensure dut is in known reset state
    dut.rst_n.value = 0
    dut.a_valid.value = 0
    dut.b_valid.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # -----------------------------------------------------------------
    # 2) Generate random matrices & compute golden result
    # -----------------------------------------------------------------
    A = gen_matrix(N, DATA_W)
    B = gen_matrix(N, DATA_W)
    # Golden result using 64‑bit accumulator for safety
    C_golden = (A.astype(np.uint64) @ B.astype(np.uint64)).astype(np.uint64)

    # Debug print
    dut._log.info("Matrix A:\n%s", A)
    dut._log.info("Matrix B:\n%s", B)
    dut._log.info("Golden C:\n%s", C_golden)

    # -----------------------------------------------------------------
    # 3) Stream matrices into the DUT
    # -----------------------------------------------------------------
    # A is streamed row‑major, one element per cycle with a_valid = 1.
    # B is streamed column‑major (i.e., column by column), also one element per cycle.
    a_seq = flatten_row_major(A)
    b_seq = flatten_column_major(B)

    # Use a simple scheduler: push A and B simultaneously.
    # In a realistic design they could arrive asynchronously,
    # but for this test we keep them aligned.
    for idx in range(N * N):
        dut.a_valid.value = 1
        dut.b_valid.value = 1
        dut.a_data.value = a_seq[idx]
        dut.b_data.value = b_seq[idx]
        await RisingEdge(dut.clk)

    # De‑assert valid after all elements have been sent
    dut.a_valid.value = 0
    dut.b_valid.value = 0

    # -----------------------------------------------------------------
    # 4) Capture output C stream
    # -----------------------------------------------------------------
    # The DUT asserts c_valid for exactly N*N cycles after latency.
    # We'll collect the data into a Python list.
    c_received = []
    expected_latency = 3 * N - 2
    # Wait until first c_valid (skip idle cycles)
    while dut.c_valid.value.integer == 0:
        await RisingEdge(dut.clk)

    # Now capture N*N cycles
    for _ in range(N * N):
        assert dut.c_valid.value.integer == 1, "c_valid dropped early"
        c_received.append(dut.c_data.value.integer)
        await RisingEdge(dut.clk)

    # Convert captured list back to matrix form (row‑major)
    C_hw = np.array(c_received, dtype=np.uint64).reshape(N, N)

    dut._log.info("Hardware C:\n%s", C_hw)

    # -----------------------------------------------------------------
    # 5) Compare
    # -----------------------------------------------------------------
    if not np.array_equal(C_hw, C_golden):
        diff = C_hw - C_golden
        raise TestFailure(
            f"Matrix multiplication mismatch!\n"
            f"Golden:\n{C_golden}\nHW:\n{C_hw}\nDiff:\n{diff}"
        )
    else:
        dut._log.info("✅  Result matches golden model!")


# -----------------------------------------------------------------
# End of testbench
# -----------------------------------------------------------------
