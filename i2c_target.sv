module i2c_target #(
  parameter bit [6:0] ADDR
) (
  input logic scl,
  inout wire  sda
);

  bit         sda_out = 1'b1;
  bit         start;
  bit         stop;
  logic [7:0] data;
  bit         rw;
  logic [6:0] addr;

  // start/stop condition detector
  always @(sda) begin
    // start
    if (scl && !sda) begin
      start = 1'b1;
      stop  = 1'b0;
      $display("%0t [I2C target] START condition", $time);
    end
    // stop
    else if (scl && sda)begin
      start = 1'b0;
      stop  = 1'b1;
      $display("%0t [I2C target] STOP condition", $time);
    end
  end

  always @(posedge start) begin
    fork
      process p_tran;
      begin : transaction
        p_tran = process::self();
        // addr + rw bit
        for (int i = 0; i < 7; i++) begin
          @(posedge scl);
          addr[6-i] = sda;
        end
        @(posedge scl);
        rw = sda;
        if (addr == ADDR) begin
          // ACK
          @(negedge scl);
          sda_out = 1'b0;
          $display("%0t [I2C target] ACK (addr = 'h%h, rw = 1'b%b)", $time, addr, rw);
          // Controller reads
          if (rw) begin
            forever begin
              data = $urandom_range(8'h00, 8'hFF);
              $display("%0t [I2C target] Sending 8'b%b ('h%h)", $time, data, data);
              for (int i = 0; i < 8; i++) begin
                // drive sda at negedge of scl
                @(negedge scl);
                sda_out = data[7-i];
              end
              // release sda for controller to acknowledge
              @(negedge scl)
              sda_out = 1'b1;
              @(posedge scl);
              if (!sda)
                $display("%0t [I2C target] Controller ACK", $time);
              else begin
                $display("%0t [I2C target] Controller NACK", $time);
                break;
              end
            end
          end
          // Controller writes
          else begin
            forever begin
              @(negedge scl);
              sda_out = 1'b1;
              for (int i = 0; i < 8; i++) begin
                // sample sda at posedge of scl
                @(posedge scl);
                data[7-i] = sda;
              end
              // ACK
              @(negedge scl);
              sda_out = 1'b0;
              $display("%0t [I2C target] ACK: Received 8'b%b ('h%h)", $time, data, data);
            end
          end
        end
      end : transaction
      begin : stop_condition
        wait(stop);
        p_tran.kill();
      end : stop_condition
    join
  end

  assign sda = (!sda_out) ? 1'b0 : 1'bz;

endmodule : i2c_target

