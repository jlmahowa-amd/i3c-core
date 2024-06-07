class i3c_driver extends uvm_driver#(.REQ(i3c_item), .RSP(i3c_item));
  `uvm_component_utils(i3c_driver)

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  bit   under_reset;
  i3c_agent_cfg cfg;

  int scl_spinwait_timeout_ns = 1_000_000; // 1ms
  bit scl_i3c_mode = 0;
  bit host_scl_start;
  bit host_scl_stop;
  i3c_drv_phase_e bus_state;

  virtual task reset_signals();
    forever begin
      @(negedge cfg.vif.rst_ni);
      `uvm_info(get_full_name(), "\ndriver in reset progress", UVM_DEBUG)
      release_bus();
      @(posedge cfg.vif.rst_ni);
      `uvm_info(get_full_name(), "\ndriver out of reset", UVM_DEBUG)
      bus_state = DrvIdle;
    end
  endtask : reset_signals

  virtual task run_phase(uvm_phase phase);
    fork
      reset_signals();
      get_and_drive();
      begin
        if (cfg.if_mode == Host) drive_scl();
      end
    join_none
  endtask

  virtual task get_and_drive();
    i3c_seq_item req;
    @(posedge cfg.vif.rst_ni);
    forever begin
//      if (cfg.if_mode == Device) release_bus();
      // driver drives bus per mode
      seq_item_port.get_next_item(req);
      fork
        begin: iso_fork
          fork
            begin
//              if (cfg.if_mode == Device) drive_device_item(req);
//              else 
              drive_host_item(req);
            end
            // handle on-the-fly reset
            begin
              process_reset();
              req.clear_all();
            end
            begin
              // Agent hot reset. It only resets I3C agent.
              // The DUT functions normally without reset.
              // This event only happens in directed test case so cannot set the timeout.
              // It will be killed by disable fork when 'drive_*_item' is finished.
              wait(cfg.driver_rst);
              `uvm_info(get_full_name(), "drvdbg agent reset", UVM_MEDIUM)
              req.clear_all();
            end
          join_any
          disable fork;
        end: iso_fork
      join
      seq_item_port.item_done();
      // When agent reset happens, flush all sequence items from sequencer request queue,
      // before it starts a new sequence.
      if (cfg.driver_rst) begin
        i3c_item dummy;
        do begin
          seq_item_port.try_next_item(dummy);
          if (dummy != null) seq_item_port.item_done();
        end while (dummy != null);
      end
    end
  endtask : get_and_drive

  // Task to drive bits on SDA from TB to DUT while DUT is operating in Target mode
  virtual task drive_host_data_bits(ref i3c_item req);
    int num_bits = $bits(req.wdata);
    `uvm_info(get_full_name(), $sformatf("Driving host item 0x%x", req.wdata), UVM_MEDIUM)
    for (int i = num_bits - 1; i >= num_bits; i--) begin
      cfg.vif.host_i2c_data(cfg.tc.i2c_tc, req.wdata[i]);
    end
  endtask

  virtual task drive_host_item(i3c_seq_item req);
    i3c_seq_item rsp;
    forever begin
      case (bus_state)
        DrvIdle: begin
          if (req.IBI && !IBI_START) begin
            bus_state = Drv_Start;
            host_i2c_start(cfg.tc.i2c_tc);
          end else if (req.IBI) begin
            wait_for_host_start();
          end else begin
            bus_state = Drv_Start;
            host_i2c_start(cfg.tc.i2c_tc);
          end
        end
        HostStart: begin
          cfg.vif.drv_phase = DrvAddr;
          cfg.vif.host_i2c_start(cfg.tc.i2c_tc);
          cfg.host_scl_start = 1;
        end
        HostRStart: begin
          cfg.vif.host_i2c_rstart(cfg.tc.i2c_tc);
        end
        HostData: begin
          drive_host_data_bits(req);
          cfg.vif.wait_scl(.iter(1));
        end
        HostDataNoWaitForACK: begin
          drive_host_data_bits(req);
        end
        HostAck: begin
          // Wait for read data and send ack
          cfg.vif.wait_scl(.iter(8));
          cfg.vif.host_i2c_data(cfg.tc.i2c_tc, 0);
        end
        HostNAck: begin
          // Wait for read data and send nack
          cfg.vif.wait_scl(.iter(8));
          cfg.vif.host_i2c_data(cfg.tc.i2c_tc, 1);
        end
        HostWait: begin
        end
        HostStop: begin
          cfg.vif.drv_phase = DrvStop;
          // If SCL is paused high, wait for it to fall.
          `DV_WAIT(cfg.vif.scl_i === 1'b0,, scl_spinwait_timeout_ns, "drive_host_item HostStop")
          // Now disable the SCL drive thread.
          cfg.host_scl_stop = 1;
          cfg.vif.host_i2c_stop(cfg.tc.i2c_tc);
          if (cfg.allow_bad_addr & !(
              cfg.valid_i2c_addr || cfg.valid_i3c_addr || cfg.valid_i3c_broadcast)) begin
            cfg.got_stop = 1;
          end
        end
        default: begin
          `uvm_fatal(get_full_name(), $sformatf("\n  host_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_host_item

//  virtual task drive_device_item(i3c_item req);
//    bit [7:0] rd_data_cnt = 8'd0;
//    bit [7:0] rdata;
//
//    case (req.drv_type)
//      DevAck: begin
//        `uvm_info(get_full_name(), $sformatf("sending an ack"), UVM_MEDIUM)
//        cfg.vif.device_send_ack(cfg.tc.i2c_tc);
//      end
//      DevNack: begin
//        cfg.vif.device_send_nack(cfg.tc.i2c_tc);
//      end
//      RdData: begin
//        `uvm_info(get_full_name(), $sformatf("Send readback data %0x", req.rdata), UVM_MEDIUM)
//        for (int i = 7; i >= 0; i--) begin
//          bit can_stretch = (i == 0) && cfg.stretch_after_ack;
//          cfg.vif.device_send_bit(cfg.tc.i2c_tc, req.rdata[i]);
//        end
//        `uvm_info(get_full_name(), $sformatf("\n  device_driver, trans %0d, byte %0d  %0x",
//            req.tran_id, req.num_data+1, rd_data[rd_data_cnt]), UVM_DEBUG)
//        // rd_data_cnt is rollled back (no overflow) after reading 256 bytes
//        rd_data_cnt++;
//      end
//      WrData: begin
//        // nothing to do
//      end
//      default: begin
//        `uvm_fatal(get_full_name(), $sformatf("\n  device_driver, received invalid request"))
//      end
//    endcase
//  endtask : drive_device_item

  virtual task process_reset();
    @(negedge cfg.vif.rst_ni);
    host_scl_stop = 1'b1;
    wait(host_scl_start == 1'b0);
    release_bus();
    `uvm_info(get_full_name(), "\n  driver is reset", UVM_DEBUG)
  endtask : process_reset

  virtual task release_bus();
    `uvm_info(get_full_name(), "Driver released the bus", UVM_HIGH)
    cfg.vif.scl_pp_en = 1'b0;
    cfg.vif.scl_o = 1'b1;
    cfg.vif.sda_pp_en = 1'b0;
    cfg.vif.sda_o = 1'b1;
  endtask : release_bus

  task drive_scl();
    // I3C SCL is only driven by the controller and can't be stretch by
    // I2C/I3C target devices.
    forever begin
      @(cfg.vif.cb);
      wait(host_scl_start);
      fork begin
        fork
          // Original scl driver thread
          while(!host_scl_stop) begin
            if (scl_i3c_mode) begin
              if (!scl_i3c_OD) cfg.vif.scl_pp_en <= 1'b1;
              cfg.vif.scl_o <= 1'b0;
              if (scl_i3c_OD) #(cfg.tc.i3c_tc.tClockLowOD * 1ns);
              else #(cfg.tc.i3c_tc.tClockLowPP * 1ns);
              if (cfg.host_scl_stop) break;
              cfg.vif.scl_o <= 1'b1;
              #(cfg.tc.i3c_tc.tClockPulse * 1ns);
            end else begin
              cfg.vif.scl_o <= 1'b0;
              #(cfg.tc.i2c_tc.tClockLow * 1ns);
              if (cfg.host_scl_stop) break;
              cfg.vif.scl_o <= 1'b1;
              #(cfg.tc.i2c_tc.tClockPulse * 1ns);
            end
            if (!cfg.host_scl_stop) cfg.vif.scl_o = 1'b0;
          end
          // Force quit thread
          begin
            wait(cfg.host_scl_force_high | cfg.host_scl_force_low);
            cfg.host_scl_stop = 1;
            if (cfg.host_scl_force_high) begin
              cfg.vif.scl_o <= 1'b1;
              cfg.vif.sda_o <= 1'b1;
            end else begin
              cfg.vif.scl_o <= 1'b0;
              cfg.vif.sda_o <= 1'b0;
            end
          end
        join_any
        disable fork;
      end join
      host_scl_stop = 0;
      host_scl_start = 0;
    end
  endtask

endclass : i3c_driver
