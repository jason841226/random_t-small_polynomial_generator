/*
 * This file is the testbench for the merge_sort module.
 *
 * Copyright (C) 2018
 * Authors: Wen Wang <wen.wang.ww349@yale.edu>
 *          Ruben Niederhagen <ruben@polycephaly.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
*/

`timescale 1ns/1ps

module merge_sort_tb;
  
  // inputs
  reg clk = 1'b0;
  reg start = 1'b0;
  
  // outputs
  wire done;
  
  merge_sort #(.INT_WIDTH(`INT_WIDTH), .INDEX_WIDTH(`INDEX_WIDTH), .LIST_LEN(`LIST_LEN), .FILE("test_data/data.in")) DUT (
    .clk(clk),
    .start(start),
    .wr_en(1'b0),
    .wr_addr(0),
    .data_in(0),
    .rd_en(1'b0),
    .rd_addr(0),
    .data_out(),
    .done(done)
  );
  
  initial
    begin
      $dumpfile("merge_sort_tb.vcd");
      $dumpvars(0, merge_sort_tb);
    end
  
  integer start_time;
  
  initial
    begin
      start <= 0;
      # 45;
      start_time = $time;
      start <= 1;
      # 10;
      start <= 0;
      @(posedge DUT.done);
      $display("\nruntime for random t-small gernerating: %0d cycles\n", ($time-start_time)/10);
      $fflush();
      # 10000;
      $finish;
    end
  
  always 
    begin
      @(posedge DUT.mem_A_valid);
      $writememb("out/verilog.out", DUT.mem_dual_A.mem);
      $fflush();
    end
  
  always 
    begin
      @(posedge DUT.mem_B_valid);
      $writememb("out/verilog.out", DUT.mem_dual_B.mem);
      $fflush();
    end
    
  
always 
  # 5 clk = !clk;
  
  
endmodule