# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass

from bus2csr import bytes2int, int2bytes
from interface import I3CTopTestInterface
from cocotb.triggers import ClockCycles
import cocotb


def mask(width):
    return (1 << width) - 1


async def _read_csr(tb, register):
    return bytes2int(await tb.read_csr(register, 4))


async def _write_csr(tb, register, value):
    data = int2bytes(value, 4)
    await tb.write_csr(register, data, 4)


async def _rmw_csr(tb, register, data):
    """
    Read -> modify -> write CSR

    TODO: Only can set bytes, enable clearing bytes
    """
    value = await _read_csr(tb, tb.register_map[register])
    value = value | data
    await _write_csr(tb, tb.register_map[register], value)


@dataclass
class core_configuration:
    dat_offset: int
    dct_offset: int
    pio_offset: int
    hc_caps: int
    ec_offsets: int


async def common_procedure(tb: I3CTopTestInterface):
    """
    Part of the procedure that is common to both Active and Secondary Controller Mode.
    """
    # Read configuration from the device
    await check_version(tb)
    dat_offset, dct_offset = await get_dxt_offsets(tb)
    pio_offset = await get_pio_offset(tb)
    await get_ring_offset(tb)
    hc_caps = await eval_hc_capabilities(tb)
    ec_offsets = await discover_ec(tb)

    core_config = core_configuration(
        dat_offset=dat_offset,
        dct_offset=dct_offset,
        pio_offset=pio_offset,
        hc_caps=hc_caps,
        ec_offsets=ec_offsets,
    )
    return core_config


async def boot_init(tb: I3CTopTestInterface):
    """
    Boot sequence model should match the description in "Boot and Initialization" chapter of the documentation.

    Standby Controller Mode by default, TODO: add Active Controller Mode procedure
    """
    core_config = await common_procedure(tb)  # noqa

    # Write configuration to the device

    # Timing configuration
    await _rmw_csr(tb, "T_R_REG", 2)
    await _rmw_csr(tb, "T_HD_DAT_REG", 10)
    await _rmw_csr(tb, "T_SU_DAT_REG", 10)

    await setup_hci_thresholds(tb)

    # Start the device
    await umbrella_stby_init(tb)


async def check_version(tb):
    """Check HCI version"""
    hci_version = await _read_csr(tb, tb.register_map["HCI_VERSION"])
    assert hci_version == 0x120


async def get_dxt_offsets(tb):
    """Check DAT/DCT offsets"""
    dat_offset = await _read_csr(tb, tb.register_map["DAT_SECTION_OFFSET"])
    assert (dat_offset & mask(12)) == 0x400
    dct_offset = await _read_csr(tb, tb.register_map["DCT_SECTION_OFFSET"])
    assert (dct_offset & mask(12)) == 0x800
    return dat_offset, dct_offset


async def get_pio_offset(tb):
    """Check PIO offset"""
    offset = await _read_csr(tb, tb.register_map["PIO_SECTION_OFFSET"])
    assert (offset & mask(16)) == 0x80
    return offset


async def get_ring_offset(tb):
    """Check ring offset"""
    offset = await _read_csr(tb, tb.register_map["RING_HEADERS_SECTION_OFFSET"])
    assert (offset & mask(16)) == 0x0
    return offset


async def eval_hc_capabilities(tb):
    """Get HC Capabilities

    TODO: Check supported config
    """
    hc_caps = await _read_csr(tb, tb.register_map["HC_CAPABILITIES"])
    return hc_caps


async def discover_ec(tb):
    """
    Returns offsets of ECs in DWORDs

    If this test fails, first check if IDs of ECs in RDL
    are defined in the same order as in the expected_cap_ids variable.
    """
    base_offset = await _read_csr(tb, tb.register_map["EXT_CAPS_SECTION_OFFSET"])
    assert (base_offset & mask(16)) == 0x100

    expected_cap_ids = [0xC0, 0x12, 0xC4, 0xC1, 0x02]
    cap_ids = []
    ec_offsets = []

    offset = base_offset
    cap_id = 1
    while cap_id:
        cap_h = await _read_csr(tb, offset)
        cap_id = cap_h & mask(8)
        cocotb.log.debug(f"cap_id = {cap_id}")
        cap_len = cap_h >> 8
        offset += cap_len * 4  # len is in DWORDs, offsets are in bytes
        if cap_id:
            cap_ids.append(cap_id)
            ec_offsets.append(offset)
    assert expected_cap_ids == cap_ids

    return ec_offsets


async def setup_hci_thresholds(tb):
    """
    Setup thresholds for the queues
    """
    pass


async def enable_irqs(tb):
    """
    Enable Controller Interrupts
    """
    pass


async def enable_pio_queues(tb):
    """
    Enable and start PIO queues
    """
    pass


async def enable_target_xact(tb):
    """
    Enable the TTI interface
    """
    pass


async def get_supported_daa(tb):
    """
    Get supported DAA methods
    """
    pass


async def define_supported_ccc(tb):
    """
    1. Get supported CCC
    2. Enable desired CCC
    """
    pass


async def umbrella_stby_init(tb):
    """
    Set the BCR bits and the DCR value in register STBY_CR_DEVICE_CHAR.

    Optionally, set the PID value in registers STBY_CR_DEVICE_CHAR and STBY_CR_DEVICE_PID_LO
    if required for the Dynamic Address Assignment with ENTDAA procedure,
    or if it is known that the GETPID CCC will be used by an Active Controller.

    Configure registers to set up autonomous responses for CCCs, for those CCCs that are defined for such handling in this specification (see Section 6.17.3.1).
    Enable Secondary Controller Interrupts:
    In register STBY_CR_INTR_SIGNAL_ENABLE (Section 7.7.11.8), set the mask of enabled interrupts.

    TODO: Current implementation is a stub. Expand.
    """

    # Boot in standby mode
    await _rmw_csr(tb, "STBY_CR_CONTROL", 2 << 30)

    # Enable Target Interface
    await _rmw_csr(tb, "STBY_CR_CONTROL", 1 << 12)

    # Enable bus
    await _rmw_csr(tb, "HC_CONTROL", 1 << 31)


async def tti_init(tb):
    """
    Additional tasks needed by the TTI
    """
    pass
