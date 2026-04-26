# ---------------------------------------------------
# test_systolic.py – cocotb testbench for the systolic array
# ---------------------------------------------------
import numpy as np
import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

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
    # -----------------------------------------------------------------
    # 0) Get design parameters (fallback to defaults if the DUT does not expose them)
    # -----------------------------------------------------------------
    N      = int(dut.N.value)          if hasattr(dut, "N")          else 4
    DATA_W = int(dut.DATA_WIDTH.value) if hasattr(dut, "DATA_WIDTH") else 8
    ACC_W  = int(dut.ACC_WIDTH.value)  if hasattr(dut, "ACC_WIDTH")  else 32

    # -----------------------------------------------------------------
    # 1) Clock & Reset
    # -----------------------------------------------------------------
    clock = Clock(dut.clk, 10, unit="ns")   # 100 MHz
    cocotb.start_soon(clock.start())

    dut.rst_n.value   = 0
    dut.a_valid.value = 0
    dut.b_valid.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # -----------------------------------------------------------------
    # 2) Generate random matrices & golden result
    # -----------------------------------------------------------------
    A = gen_matrix(N, DATA_W)
    B = gen_matrix(N, DATA_W)

    C_golden = (A.astype(np.uint64) @ B.astype(np.uint64)).astype(np.uint64)

    dut._log.info("Matrix A:\n%s", A)
    dut._log.info("Matrix B:\n%s", B)
    dut._log.info("Golden C:\n%s", C_golden)

    # -----------------------------------------------------------------
    # 3) Stream matrices into the DUT
    # -----------------------------------------------------------------
    a_seq = flatten_row_major(A)
    b_seq = flatten_column_major(B)

    for idx in range(N * N):
        dut.a_valid.value = 1
        dut.b_valid.value = 1
        dut.a_data.value  = a_seq[idx]
        dut.b_data.value  = b_seq[idx]
        await RisingEdge(dut.clk)

    dut.a_valid.value = 0
    dut.b_valid.value = 0

    # -----------------------------------------------------------------
    # 4) Capture output C stream
    # -----------------------------------------------------------------
    c_received = []

    # Wait until the DUT asserts the first c_valid
    while dut.c_valid.value == 0:
        await RisingEdge(dut.clk)

    # Number of bits required to display the accumulator in hex
    hex_width = ACC_W // 4

    for _ in range(N * N):
        # Guard against premature de‑assertion
        assert dut.c_valid.value == 1, "c_valid dropped early"

        # ----- Read the raw value safely (replace any X/Z with 0) -----
        # `binstr` is deprecated but still works; we replace X/Z manually.
        raw_bin = dut.c_data.value.binstr.lower()
        raw_bin = raw_bin.replace("x", "0").replace("z", "0")
        raw_int = int(raw_bin, 2)

        # ----- Debug print (hex + binary) -----
        dut._log.info(
            f"C data raw = 0x{raw_int:0{hex_width}X} bin = {raw_bin}"
        )

        c_received.append(raw_int)
        await RisingEdge(dut.clk)

    # -----------------------------------------------------------------
    # 5) Re‑assemble captured data into a matrix (row‑major)
    # -----------------------------------------------------------------
    C_hw = np.array(c_received, dtype=np.uint64).reshape(N, N)
    dut._log.info("Hardware C:\n%s", C_hw)

    # -----------------------------------------------------------------
    # 6) Compare with the golden model
    # -----------------------------------------------------------------
    if not np.array_equal(C_hw, C_golden):
        diff = C_hw - C_golden
        assert False, (
            f"Matrix multiplication mismatch!\n"
            f"Golden:\n{C_golden}\n"
            f"HW:\n{C_hw}\n"
            f"Diff:\n{diff}"
        )
    else:
        dut._log.info("✅  Result matches golden model!")
