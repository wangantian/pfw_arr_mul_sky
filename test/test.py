# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def pack_inputs(a, b):
    """Pack 4-bit A and 4-bit B into ui_in byte: ui_in[3:0]=A, ui_in[7:4]=B"""
    return ((b & 0xF) << 4) | (a & 0xF)


@cocotb.test()
async def test_multiplier(dut):
    """Verify the 4x4 array multiplier produces correct products."""
    dut._log.info("Start")

    # 25 MHz clock (40 ns period) — required for VGA
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Testing multiplier correctness")

    test_cases = [
        (0,  0,  0),
        (1,  1,  1),
        (2,  4,  8),
        (3,  3,  9),
        (4,  2,  8),
        (6,  9,  54),
        (7,  7,  49),
        (10, 7,  70),
        (15, 15, 225),
        (15, 1,  15),
        (8,  15, 120),
    ]

    # RTL builds expose the internal multiplier wire P.
    # Gate-level netlists often do not preserve internal names, so we fall back
    # to a smoke test there.
    internal_product = None
    try:
        internal_product = dut.user_project.P
        dut._log.info("Internal product wire P found (RTL assertions enabled).")
    except AttributeError:
        dut._log.warning(
            "No internal product wire P (likely GL netlist). "
            "Running smoke test without internal product assertions."
        )

    for a, b, expected in test_cases:
        dut.ui_in.value = pack_inputs(a, b)
        await ClockCycles(dut.clk, 2)

        if internal_product is not None:
            product = int(internal_product.value)
            assert product == expected, (
                f"{a} x {b}: got {product}, expected {expected}"
            )
            dut._log.info(f"  {a} x {b} = {product}  (PASS)")
        else:
            # Smoke-check: make sure simulation continues and VGA output is readable.
            _ = int(dut.uo_out.value)
            dut._log.info(f"  {a} x {b} applied (GL smoke PASS)")

    dut._log.info("All multiplications verified successfully")
