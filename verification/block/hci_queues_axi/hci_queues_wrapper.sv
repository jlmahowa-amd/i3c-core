// SPDX-License-Identifier: Apache-2.0

module hci_queues_wrapper
  import i3c_pkg::*;
  import I3CCSR_pkg::I3CCSR_DATA_WIDTH;
  import I3CCSR_pkg::I3CCSR_MIN_ADDR_WIDTH;
#(
    localparam int unsigned CsrAddrWidth = I3CCSR_MIN_ADDR_WIDTH,
    localparam int unsigned CsrDataWidth = I3CCSR_DATA_WIDTH,

    parameter int unsigned AxiAddrWidth = 12,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiUserWidth = 32,
    parameter int unsigned AxiIdWidth   = 2,

    parameter int unsigned RespFifoDepth = 64,
    parameter int unsigned CmdFifoDepth  = 64,
    parameter int unsigned RxFifoDepth   = 64,
    parameter int unsigned TxFifoDepth   = 64,

    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth  = 8,
    parameter int unsigned HciRxThldWidth   = 3,
    parameter int unsigned HciTxThldWidth   = 3,

    parameter int unsigned TtiRxDescDataWidth = 32,
    parameter int unsigned TtiTxDescDataWidth = 32,
    parameter int unsigned TtiRxDataWidth = 32,
    parameter int unsigned TtiTxDataWidth = 32,

    parameter int unsigned TtiRxDescThldWidth = 8,
    parameter int unsigned TtiTxDescThldWidth = 8,
    parameter int unsigned TtiRxThldWidth = 3,
    parameter int unsigned TtiTxThldWidth = 3
) (
    input aclk,  // clock
    input areset_n,  // active low reset

    // AXI4 Interface
    // AXI Read Channels
    input  logic [AxiAddrWidth-1:0] araddr,
    input        [             1:0] arburst,
    input  logic [             2:0] arsize,
    input        [             7:0] arlen,
    input        [AxiUserWidth-1:0] aruser,
    input  logic [  AxiIdWidth-1:0] arid,
    input  logic                    arlock,
    input  logic                    arvalid,
    output logic                    arready,

    output logic [AxiDataWidth-1:0] rdata,
    output logic [             1:0] rresp,
    output logic [  AxiIdWidth-1:0] rid,
    output logic                    rlast,
    output logic                    rvalid,
    input  logic                    rready,

    // AXI Write Channels
    input  logic [AxiAddrWidth-1:0] awaddr,
    input        [             1:0] awburst,
    input  logic [             2:0] awsize,
    input        [             7:0] awlen,
    input        [AxiUserWidth-1:0] awuser,
    input  logic [  AxiIdWidth-1:0] awid,
    input  logic                    awlock,
    input  logic                    awvalid,
    output logic                    awready,

    input  logic [AxiDataWidth-1:0] wdata,
    input  logic [             3:0] wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    output logic [           1:0] bresp,
    output logic [AxiIdWidth-1:0] bid,
    output logic                  bvalid,
    input  logic                  bready,

    // HCI queues (FSM side)
    // Response queue
    output logic [HciRespThldWidth-1:0] resp_queue_ready_thld_o,
    output logic resp_queue_full_o,
    output logic resp_queue_ready_thld_trig_o,
    output logic resp_queue_empty_o,
    input logic resp_queue_wvalid_i,
    output logic resp_queue_wready_o,
    input logic [HciRespDataWidth-1:0] resp_queue_wdata_i,

    // Command queue
    output logic [HciCmdThldWidth-1:0] cmd_queue_ready_thld_o,
    output logic cmd_queue_full_o,
    output logic cmd_queue_ready_thld_trig_o,
    output logic cmd_queue_empty_o,
    output logic cmd_queue_rvalid_o,
    input logic cmd_queue_rready_i,
    output logic [HciCmdDataWidth-1:0] cmd_queue_rdata_o,

    // RX queue
    output logic [HciRxThldWidth-1:0] rx_queue_start_thld_o,
    output logic [HciRxThldWidth-1:0] rx_queue_ready_thld_o,
    output logic rx_queue_full_o,
    output logic rx_queue_start_thld_trig_o,
    output logic rx_queue_ready_thld_trig_o,
    output logic rx_queue_empty_o,
    input logic rx_queue_wvalid_i,
    output logic rx_queue_wready_o,
    input logic [HciRxDataWidth-1:0] rx_queue_wdata_i,

    // TX queue
    output logic [HciTxThldWidth-1:0] tx_queue_start_thld_o,
    output logic [HciTxThldWidth-1:0] tx_queue_ready_thld_o,
    output logic tx_queue_full_o,
    output logic tx_queue_start_thld_trig_o,
    output logic tx_queue_ready_thld_trig_o,
    output logic tx_queue_empty_o,
    output logic tx_queue_rvalid_o,
    input logic tx_queue_rready_i,
    output logic [HciTxDataWidth-1:0] tx_queue_rdata_o,

    // Target Transaction Interface
    // RX descriptors queue
    output logic tti_rx_desc_queue_full_o,
    output logic [TtiRxDescThldWidth-1:0] tti_rx_desc_queue_ready_thld_o,
    output logic tti_rx_desc_queue_ready_thld_trig_o,
    output logic tti_rx_desc_queue_empty_o,
    input logic tti_rx_desc_queue_wvalid_i,
    output logic tti_rx_desc_queue_wready_o,
    input logic [TtiRxDescDataWidth-1:0] tti_rx_desc_queue_wdata_i,

    // TX descriptors queue
    output logic tti_tx_desc_queue_full_o,
    output logic [TtiTxDescThldWidth-1:0] tti_tx_desc_queue_ready_thld_o,
    output logic tti_tx_desc_queue_ready_thld_trig_o,
    output logic tti_tx_desc_queue_empty_o,
    output logic tti_tx_desc_queue_rvalid_o,
    input logic tti_tx_desc_queue_rready_i,
    output logic [TtiRxDescDataWidth-1:0] tti_tx_desc_queue_rdata_o,

    // RX queue
    output logic tti_rx_queue_full_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_start_thld_o,
    output logic [TtiRxThldWidth-1:0] tti_rx_queue_ready_thld_o,
    output logic tti_rx_queue_start_thld_trig_o,
    output logic tti_rx_queue_ready_thld_trig_o,
    output logic tti_rx_queue_empty_o,
    input logic tti_rx_queue_wvalid_i,
    output logic tti_rx_queue_wready_o,
    input logic [TtiRxDataWidth-1:0] tti_rx_queue_wdata_i,

    // TX queue
    output logic tti_tx_queue_full_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_start_thld_o,
    output logic [TtiTxThldWidth-1:0] tti_tx_queue_ready_thld_o,
    output logic tti_tx_queue_start_thld_trig_o,
    output logic tti_tx_queue_ready_thld_trig_o,
    output logic tti_tx_queue_empty_o,
    output logic tti_tx_queue_rvalid_o,
    input logic tti_tx_queue_rready_i,
    output logic [TtiTxDataWidth-1:0] tti_tx_queue_rdata_o
);

  // I3C SW CSR IF
  logic s_cpuif_req;
  logic s_cpuif_req_is_wr;
  logic [CsrAddrWidth-1:0] s_cpuif_addr;
  logic [CsrDataWidth-1:0] s_cpuif_wr_data;
  logic [CsrDataWidth-1:0] s_cpuif_wr_biten;
  logic s_cpuif_req_stall_wr;
  logic s_cpuif_req_stall_rd;
  logic s_cpuif_rd_ack;
  logic s_cpuif_rd_err;
  logic [CsrDataWidth-1:0] s_cpuif_rd_data;
  logic s_cpuif_wr_ack;
  logic s_cpuif_wr_err;

  axi_adapter #(
      .AxiDataWidth,
      .AxiAddrWidth,
      .AxiUserWidth,
      .AxiIdWidth
  ) i3c_axi_if (
      .clk_i (aclk),
      .rst_ni(areset_n),

      // AXI Read Channels
      .araddr_i(araddr),
      .arburst_i(arburst),
      .arsize_i(arsize),
      .arlen_i(arlen),
      .aruser_i(aruser),
      .arid_i(arid),
      .arlock_i(arlock),
      .arvalid_i(arvalid),
      .arready_o(arready),

      .rdata_o(rdata),
      .rresp_o(rresp),
      .rid_o(rid),
      .rlast_o(rlast),
      .rvalid_o(rvalid),
      .rready_i(rready),

      // AXI Write Channels
      .awaddr_i(awaddr),
      .awburst_i(awburst),
      .awsize_i(awsize),
      .awlen_i(awlen),
      .awuser_i(awuser),
      .awid_i(awid),
      .awlock_i(awlock),
      .awvalid_i(awvalid),
      .awready_o(awready),

      .wdata_i (wdata),
      .wstrb_i (wstrb),
      .wlast_i (wlast),
      .wvalid_i(wvalid),
      .wready_o(wready),

      .bresp_o(bresp),
      .bid_o(bid),
      .bvalid_o(bvalid),
      .bready_i(bready),

      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err)
  );

  logic [63:0] unused_dat_rdata_hw;
  logic [127:0] unused_dct_rdata_hw;
  dat_mem_sink_t unused_dat_mem_sink;
  dct_mem_sink_t unused_dct_mem_sink;
  i3c_config_t unused_core_config;

  hci #(
      .RespFifoDepth,
      .CmdFifoDepth,
      .RxFifoDepth,
      .TxFifoDepth,
      .HciRespDataWidth,
      .HciCmdDataWidth,
      .HciRxDataWidth,
      .HciTxDataWidth,
      .HciRespThldWidth,
      .HciCmdThldWidth,
      .HciRxThldWidth,
      .HciTxThldWidth,
      .TtiRxDescDataWidth,
      .TtiTxDescDataWidth,
      .TtiRxDataWidth,
      .TtiTxDataWidth,
      .TtiRxDescThldWidth,
      .TtiTxDescThldWidth,
      .TtiRxThldWidth,
      .TtiTxThldWidth
  ) hci (
      .clk_i(aclk),
      .rst_ni(areset_n),
      .s_cpuif_req(s_cpuif_req),
      .s_cpuif_req_is_wr(s_cpuif_req_is_wr),
      .s_cpuif_addr(s_cpuif_addr),
      .s_cpuif_wr_data(s_cpuif_wr_data),
      .s_cpuif_wr_biten(s_cpuif_wr_biten),
      .s_cpuif_req_stall_wr(s_cpuif_req_stall_wr),
      .s_cpuif_req_stall_rd(s_cpuif_req_stall_rd),
      .s_cpuif_rd_ack(s_cpuif_rd_ack),
      .s_cpuif_rd_err(s_cpuif_rd_err),
      .s_cpuif_rd_data(s_cpuif_rd_data),
      .s_cpuif_wr_ack(s_cpuif_wr_ack),
      .s_cpuif_wr_err(s_cpuif_wr_err),

      // HCI Response queue
      .hci_resp_full_o(resp_queue_full_o),
      .hci_resp_ready_thld_o(resp_queue_ready_thld_o),
      .hci_resp_ready_thld_trig_o(resp_queue_ready_thld_trig_o),
      .hci_resp_empty_o(resp_queue_empty_o),
      .hci_resp_wvalid_i(resp_queue_wvalid_i),
      .hci_resp_wready_o(resp_queue_wready_o),
      .hci_resp_wdata_i(resp_queue_wdata_i),

      // HCI Command queue
      .hci_cmd_full_o(cmd_queue_full_o),
      .hci_cmd_ready_thld_o(cmd_queue_ready_thld_o),
      .hci_cmd_ready_thld_trig_o(cmd_queue_ready_thld_trig_o),
      .hci_cmd_empty_o(cmd_queue_empty_o),
      .hci_cmd_rvalid_o(cmd_queue_rvalid_o),
      .hci_cmd_rready_i(cmd_queue_rready_i),
      .hci_cmd_rdata_o(cmd_queue_rdata_o),

      // HCI RX queue
      .hci_rx_full_o(rx_queue_full_o),
      .hci_rx_start_thld_o(rx_queue_start_thld_o),
      .hci_rx_ready_thld_o(rx_queue_ready_thld_o),
      .hci_rx_start_thld_trig_o(rx_queue_start_thld_trig_o),
      .hci_rx_ready_thld_trig_o(rx_queue_ready_thld_trig_o),
      .hci_rx_empty_o(rx_queue_empty_o),
      .hci_rx_wvalid_i(rx_queue_wvalid_i),
      .hci_rx_wready_o(rx_queue_wready_o),
      .hci_rx_wdata_i(rx_queue_wdata_i),

      // HCI TX queue
      .hci_tx_full_o(tx_queue_full_o),
      .hci_tx_start_thld_o(tx_queue_start_thld_o),
      .hci_tx_ready_thld_o(tx_queue_ready_thld_o),
      .hci_tx_start_thld_trig_o(tx_queue_start_thld_trig_o),
      .hci_tx_ready_thld_trig_o(tx_queue_ready_thld_trig_o),
      .hci_tx_empty_o(tx_queue_empty_o),
      .hci_tx_rvalid_o(tx_queue_rvalid_o),
      .hci_tx_rready_i(tx_queue_rready_i),
      .hci_tx_rdata_o(tx_queue_rdata_o),

      // TTI RX descriptors queue
      .tti_rx_desc_queue_full_o(tti_rx_desc_queue_full_o),
      .tti_rx_desc_queue_ready_thld_o(tti_rx_desc_queue_ready_thld_o),
      .tti_rx_desc_queue_ready_thld_trig_o(tti_rx_desc_queue_ready_thld_trig_o),
      .tti_rx_desc_queue_empty_o(tti_rx_desc_queue_empty_o),
      .tti_rx_desc_queue_wvalid_i(tti_rx_desc_queue_wvalid_i),
      .tti_rx_desc_queue_wready_o(tti_rx_desc_queue_wready_o),
      .tti_rx_desc_queue_wdata_i(tti_rx_desc_queue_wdata_i),

      // TTI TX descriptors queue
      .tti_tx_desc_queue_full_o(tti_tx_desc_queue_full_o),
      .tti_tx_desc_queue_ready_thld_o(tti_tx_desc_queue_ready_thld_o),
      .tti_tx_desc_queue_ready_thld_trig_o(tti_tx_desc_queue_ready_thld_trig_o),
      .tti_tx_desc_queue_empty_o(tti_tx_desc_queue_empty_o),
      .tti_tx_desc_queue_rvalid_o(tti_tx_desc_queue_rvalid_o),
      .tti_tx_desc_queue_rready_i(tti_tx_desc_queue_rready_i),
      .tti_tx_desc_queue_rdata_o(tti_tx_desc_queue_rdata_o),

      // TTI RX queue
      .tti_rx_queue_full_o(tti_rx_queue_full_o),
      .tti_rx_queue_start_thld_o(tti_rx_queue_start_thld_o),
      .tti_rx_queue_ready_thld_o(tti_rx_queue_ready_thld_o),
      .tti_rx_queue_start_thld_trig_o(tti_rx_queue_start_thld_trig_o),
      .tti_rx_queue_ready_thld_trig_o(tti_rx_queue_ready_thld_trig_o),
      .tti_rx_queue_empty_o(tti_rx_queue_empty_o),
      .tti_rx_queue_wvalid_i(tti_rx_queue_wvalid_i),
      .tti_rx_queue_wready_o(tti_rx_queue_wready_o),
      .tti_rx_queue_wdata_i(tti_rx_queue_wdata_i),

      // TTI TX queue
      .tti_tx_queue_full_o(tti_tx_queue_full_o),
      .tti_tx_queue_start_thld_o(tti_tx_queue_start_thld_o),
      .tti_tx_queue_ready_thld_o(tti_tx_queue_ready_thld_o),
      .tti_tx_queue_start_thld_trig_o(tti_tx_queue_start_thld_trig_o),
      .tti_tx_queue_ready_thld_trig_o(tti_tx_queue_ready_thld_trig_o),
      .tti_tx_queue_empty_o(tti_tx_queue_empty_o),
      .tti_tx_queue_rvalid_o(tti_tx_queue_rvalid_o),
      .tti_tx_queue_rready_i(tti_tx_queue_rready_i),
      .tti_tx_queue_rdata_o(tti_tx_queue_rdata_o),

      .dat_read_valid_hw_i('0),
      .dat_index_hw_i('0),
      .dat_rdata_hw_o(unused_dat_rdata_hw),

      .dct_write_valid_hw_i('0),
      .dct_read_valid_hw_i('0),
      .dct_index_hw_i('0),
      .dct_wdata_hw_i('0),
      .dct_rdata_hw_o(unused_dct_rdata_hw),

      .dat_mem_src_i ('0),
      .dat_mem_sink_o(unused_dat_mem_sink),

      .dct_mem_src_i ('0),
      .dct_mem_sink_o(unused_dct_mem_sink),

      .core_config(unused_core_config)
  );
endmodule
