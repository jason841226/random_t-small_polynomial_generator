/*
 * merge sort module.
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

module merge_sort
  #(
    parameter INT_WIDTH = 32,
    parameter INDEX_WIDTH = 0,
    parameter LIST_LEN = 1024,// total number of elements to be sorted
    parameter FILE = "",
    parameter k = `CLOG2(LIST_LEN),
    parameter t = 100
  )
  (
    //
    input wire clk,
    input wire start,

    // all the outside wr_en and rd_en have priorities over inner wr_en/rd_en signals
    input wire wr_en,
    input wire [k-1:0] wr_addr,
    input wire [INT_WIDTH+INDEX_WIDTH-1:0] data_in,

    input wire rd_en,
    input wire [k-1:0] rd_addr,
    output wire [INT_WIDTH+INDEX_WIDTH-1:0] data_out,
    output wire done
  );


  // even round: read from mem A, write to mem B
  // odd round: read from mem B, write to mem A

  // memory A interface
  reg mem_A_wren_0 = 1'b0;
  wire [k-1:0] mem_A_addr_0;
  wire [k-1:0] mem_A_addr_1;
  wire [INT_WIDTH+INDEX_WIDTH-1:0] mem_A_dout_0;
  wire [INT_WIDTH+INDEX_WIDTH-1:0] mem_A_dout_1;
  reg [INT_WIDTH+INDEX_WIDTH-1:0] mem_A_dout_0_buf = {(INT_WIDTH+INDEX_WIDTH){1'b0}};
  reg [INT_WIDTH+INDEX_WIDTH-1:0] mem_A_dout_1_buf = {(INT_WIDTH+INDEX_WIDTH){1'b0}};

  // memory B interface
  reg mem_B_wren_0 = 1'b0;
  wire [k-1:0] mem_B_addr_0;
  wire [k-1:0] mem_B_addr_1;
  wire [INT_WIDTH+INDEX_WIDTH-1:0] mem_B_dout_0;
  wire [INT_WIDTH+INDEX_WIDTH-1:0] mem_B_dout_1;
  reg [INT_WIDTH+INDEX_WIDTH-1:0] mem_B_dout_0_buf = {(INT_WIDTH+INDEX_WIDTH){1'b0}};
  reg [INT_WIDTH+INDEX_WIDTH-1:0] mem_B_dout_1_buf = {(INT_WIDTH+INDEX_WIDTH){1'b0}};

  wire mem_wr_en_0;
  assign mem_wr_en_0 = mem_A_wren_0 || mem_B_wren_0;

  reg running = 1'b0;
  reg [`CLOG2(k)-1:0] round_counter = {(`CLOG2(k)){1'b0}}; // counter for counting the rounds

  reg section_done = 1'b0;
  reg section_done_start = 1'b0;
  reg wr_section_done = 1'b0;
  reg wr_section_done_start = 1'b0;
  reg [k-1:0] mem_wr_addr_0 [0:3];
  reg [k-1:0] mem_rd_addr_0 [0:3];
  reg [k-1:0] mem_rd_addr_1 [0:3];

  reg round_start_buf = 1'b0;

  wire [INT_WIDTH+INDEX_WIDTH-1:0] comp_in_L_tmp;
  wire [INT_WIDTH+INDEX_WIDTH-1:0] comp_in_R_tmp;
  wire L_smaller_valid;
  wire L_smaller_out;
  wire comp_collision;
   
   assign L_smaller_valid = (L_smaller_out || (comp_collision && comp_in_L_tmp[INDEX_WIDTH]));

  // begin pipeline state
  reg [k-1:0] block_counter_L [0:3]; // pointer for the left half of the compared data in one data block
  reg [k-1:0] block_counter_R [0:3]; // pointer for the right half of the compared data in one data block

  reg [1:2] empty_L;
  reg [1:2] empty_R;

  reg [3:3] left_smaller;
  reg [3:3] right_smaller;
  reg [2:2] comparison_valid;
  reg [3:3] L_smaller;

  reg [INT_WIDTH+INDEX_WIDTH-1:0] smaller_data [4:4];

  reg [INT_WIDTH+INDEX_WIDTH-1:0] comp_in_L [3:3];
  reg [INT_WIDTH+INDEX_WIDTH-1:0] comp_in_R [3:3];

  initial
    begin
      left_smaller[3] = 1'b0;

      right_smaller[3] = 1'b0;

      comparison_valid[2] = 1'b0;

      smaller_data[4] = {(INT_WIDTH+INDEX_WIDTH){1'b0}};

      L_smaller[3] = 1'b0;

      comp_in_L[3] = {(INT_WIDTH+INDEX_WIDTH){1'b0}};
      comp_in_R[3] = {(INT_WIDTH+INDEX_WIDTH){1'b0}};

      empty_L[1] = 1'b0;
      empty_L[2] = 1'b0;

      empty_R[1] = 1'b0;
      empty_R[2] = 1'b0;
    end
  // end pipeline state

  reg [k+1:0] rd_counter = {(k+2){1'b0}};
  reg [k-1:0] block_limit = {k{1'b0}};

  reg round_done = 1'b0;

  reg done_buffer = 1'b0;
  assign done = done_buffer;

  reg mem_A_valid = 1'b0;
  reg mem_B_valid = 1'b0;


  reg wr_addr_inc_trigger = 1'b0;
  reg write_start = 1'b0;

  // initialize 2d arrays
  integer i;
  initial
    for (i=0; i<4; i=i+1)
      begin
        block_counter_L[i] = {k{1'b0}};
        block_counter_R[i] = {k{1'b0}};
        mem_wr_addr_0[i] = {k{1'b0}};
        mem_rd_addr_0[i] = {k{1'b0}};
        mem_rd_addr_1[i] = {k{1'b0}};
      end


  always @(posedge clk)
    begin
      mem_A_dout_0_buf <= (round_counter != 0) ? mem_A_dout_0 :
                          (mem_rd_addr_0[1] < 2*t) ? {mem_A_dout_0[INT_WIDTH+INDEX_WIDTH-1:1],1'b1} : 
                          {mem_A_dout_0[INT_WIDTH+INDEX_WIDTH-1:2],2'b0};
      mem_A_dout_1_buf <= (round_counter != 0) ? mem_A_dout_1 :
                          (mem_rd_addr_1[1] < 2*t) ? {mem_A_dout_1[INT_WIDTH+INDEX_WIDTH-1:1],1'b1} : 
                          {mem_A_dout_1[INT_WIDTH+INDEX_WIDTH-1:2],2'b0};

      mem_B_dout_0_buf <= mem_B_dout_0;
      mem_B_dout_1_buf <= mem_B_dout_1;

      comp_in_L[3] <= comp_in_L_tmp;
      comp_in_R[3] <= comp_in_R_tmp;
    end


  always @(posedge clk)
    begin
      block_limit <= ((1 << round_counter)-1);

      round_start_buf <= start | round_done | (rd_counter[k:1] == 0);

      section_done       <= (((rd_counter+2) & (((1 << (round_counter+3))-1)^2'b11)) == 0);
      section_done_start <= (((rd_counter+2) & ((1 << (round_counter+3))-1)) == 0);

      wr_section_done       <= (((rd_counter+2-4) & (((1 << (round_counter+3))-1)^2'b11)) == 0);
      wr_section_done_start <= (((rd_counter+2-4) & ((1 << (round_counter+3))-1)) == 0);
    end


  // pipeline logic
  always @(posedge clk)
    begin
      comparison_valid[2] <=
             (round_counter <  (k-2)) ? (rd_counter >= 1) && (rd_counter <= LIST_LEN) :
             (round_counter == (k-2)) ? (rd_counter >= 1) && (rd_counter <= (LIST_LEN << 1)-2) :
             (round_counter == (k-1)) ? (rd_counter >= 1) && (rd_counter <= (LIST_LEN << 2)-3) :
             1'b0;

      left_smaller[3]  <= comparison_valid[2] && (empty_R[2] ||  L_smaller_valid);
      right_smaller[3] <= comparison_valid[2] && (empty_L[2] || !L_smaller_valid);

      L_smaller[3] <= empty_L[2] ? 1'b0 :
                      empty_R[2] ? 1'b1 :
                      L_smaller_valid;

      smaller_data[4] <= L_smaller[3] ? comp_in_L[3][INT_WIDTH+INDEX_WIDTH-1:0] :
                                        comp_in_R[3][INT_WIDTH+INDEX_WIDTH-1:0];

      empty_L[1] <= (block_counter_L[0] > block_limit) ? 1'b1 : 1'b0;
      empty_L[2] <= empty_L[1];

      empty_R[1] <= (block_counter_R[0] > block_limit) ? 1'b1 : 1'b0;
      empty_R[2] <= empty_R[1];

      block_counter_L[0] <= (start | section_done | round_done) ? {k{1'b0}} :
                            left_smaller[3] ? block_counter_L[3] + 1 :
                            block_counter_L[3];
      block_counter_L[1] <= block_counter_L[0];
      block_counter_L[2] <= block_counter_L[1];
      block_counter_L[3] <= block_counter_L[2];

      block_counter_R[0] <= (start | section_done | round_done) ? {k{1'b0}} :
                            right_smaller[3] ? block_counter_R[3] + 1 :
                            block_counter_R[3];
      block_counter_R[1] <= block_counter_R[0];
      block_counter_R[2] <= block_counter_R[1];
      block_counter_R[3] <= block_counter_R[2];
    end


  always @(posedge clk)
    begin
      running <= start ? 1'b1 :
                  done ? 1'b0 :
                  running;

      round_done <= (round_counter < (k-2)) ? (rd_counter == (LIST_LEN+2)) :
                    (round_counter == (k-2)) ? (rd_counter == (LIST_LEN << 1)) :
                    (round_counter == (k-1)) ? (rd_counter == ((LIST_LEN << 2)-1)) :
                    1'b0;

      round_counter <= (start | done) ? {(`CLOG2(k)){1'b0}} :
                        round_done ? round_counter + 1 :
                        round_counter;

      rd_counter <= (start | round_done | done) ? {(k+2){1'b0}} :
                    running ? rd_counter + 1 :
                    rd_counter;

      done_buffer <= start ? 1'b0 :
                     ((round_counter == (k-1)) && (round_done)) ? 1'b1 :
                      1'b0;

      mem_A_valid <= start ? 1'b0 :
                      ((round_counter == (k-1)) && (round_done) && (round_counter[0] == 1)) ? 1'b1 :
                      mem_A_valid;

      mem_B_valid <= start ? 1'b0 :
                      ((round_counter == (k-1)) && (round_done) && (round_counter[0] == 0)) ? 1'b1 :
                      mem_B_valid;
    end


  always @(posedge clk)
    begin
      mem_A_wren_0 <= (round_counter[0] == 0) ? 1'b0 :
                      (round_counter <  (k-2)) ? (rd_counter >= 3) && (rd_counter <= (LIST_LEN+2)) :
                      (round_counter == (k-2)) ? (rd_counter >= 3) && (rd_counter <= (LIST_LEN << 1)) :
                      (round_counter == (k-1)) ? (rd_counter >= 3) && (rd_counter <= ((LIST_LEN << 2)-1)) :
                      1'b0;

      mem_B_wren_0 <= (round_counter[0] == 1) ? 1'b0 :
                      (round_counter <  (k-2)) ? (rd_counter >= 3) && (rd_counter <= (LIST_LEN+2)) :
                      (round_counter == (k-2)) ? (rd_counter >= 3) && (rd_counter <= (LIST_LEN << 1)) :
                      (round_counter == (k-1)) ? (rd_counter >= 3) && (rd_counter <= ((LIST_LEN << 2)-1)) :
                      1'b0;

      wr_addr_inc_trigger <= (rd_counter >= 3) && (rd_counter <= 5);
      write_start <= (rd_counter == 2);

      mem_wr_addr_0[0] <= write_start ? {k{1'b0}} :
                        ((round_counter < (k-2)) && wr_section_done_start) ? mem_wr_addr_0[0] + 1 :
                        (wr_addr_inc_trigger || wr_section_done) ? mem_wr_addr_0[0]+(1 << (round_counter+1)) :
                        mem_wr_en_0 ? mem_wr_addr_0[3] + 1 :
                        mem_wr_addr_0[0];
      mem_wr_addr_0[1] <= mem_wr_addr_0[0];
      mem_wr_addr_0[2] <= mem_wr_addr_0[1];
      mem_wr_addr_0[3] <= mem_wr_addr_0[2];

      mem_rd_addr_0[0] <= (start | round_done) ? {k{1'b0}} :
                          section_done_start ? mem_rd_addr_1[0] + 1 :
                          (round_start_buf || section_done) ? mem_rd_addr_0[0] + (1 << (round_counter+1)) :
                          left_smaller[3] && (block_counter_L[3] < block_limit) ? mem_rd_addr_0[3] + 1 :
                          mem_rd_addr_0[3];
      mem_rd_addr_0[1] <= mem_rd_addr_0[0];
      mem_rd_addr_0[2] <= mem_rd_addr_0[1];
      mem_rd_addr_0[3] <= mem_rd_addr_0[2];

      mem_rd_addr_1[0] <= start ? 1 :
                          round_done ? (1 << (round_counter + 1)) :
                          section_done_start ? mem_rd_addr_1[0] + 1 + (1 << round_counter) :
                          (round_start_buf || section_done) ? mem_rd_addr_1[0] + (1 << (round_counter+1)) :
                          right_smaller[3] && (block_counter_R[3] < block_limit) ? mem_rd_addr_1[3] + 1 :
                          mem_rd_addr_1[3];
      mem_rd_addr_1[1] <= mem_rd_addr_1[0];
      mem_rd_addr_1[2] <= mem_rd_addr_1[1];
      mem_rd_addr_1[3] <= mem_rd_addr_1[2];

    end


  // comparator

  // add first round logic

  assign comp_in_L_tmp = (round_counter[0] == 0) ? mem_A_dout_0_buf : mem_B_dout_0_buf;
  assign comp_in_R_tmp = (round_counter[0] == 0) ? mem_A_dout_1_buf : mem_B_dout_1_buf;

  compare #(.WIDTH(INT_WIDTH)) compare_inst (
    .dinL(comp_in_L_tmp[INT_WIDTH+INDEX_WIDTH-1:INDEX_WIDTH]),
    .dinR(comp_in_R_tmp[INT_WIDTH+INDEX_WIDTH-1:INDEX_WIDTH]),
    .L_smaller(L_smaller_out),
    .equal(comp_collision)
  );


  // memory for sorting
  // higher b bits: random integers
  // lower m bits: corresponding indices

  assign mem_A_addr_0 = (round_counter[0] == 1) ? mem_wr_addr_0[0] : mem_rd_addr_0[0];
  assign mem_A_addr_1 = mem_rd_addr_1[0];

  assign mem_B_addr_0 = (round_counter[0] == 0) ? mem_wr_addr_0[0] : mem_rd_addr_0[0];
  assign mem_B_addr_1 = mem_rd_addr_1[0];

  mem_dual #(.WIDTH(INT_WIDTH+INDEX_WIDTH), .DEPTH(LIST_LEN), .FILE(FILE)) mem_dual_A (
    .clock(clk),
    .data_0(smaller_data[4]),
    .data_1(data_in),
    .address_0((rd_en & mem_A_valid) ? rd_addr : mem_A_addr_0),
    .address_1(wr_en ? wr_addr : mem_A_addr_1),
    .wren_0(mem_A_wren_0),
    .wren_1(wr_en),
    .q_0(mem_A_dout_0),
    .q_1(mem_A_dout_1)
  );

  mem_dual #(.WIDTH(INT_WIDTH+INDEX_WIDTH), .DEPTH(LIST_LEN)) mem_dual_B (
    .clock(clk),
    .data_0(smaller_data[4]),
    .data_1({(INT_WIDTH+INDEX_WIDTH){1'b0}}),
    .address_0((rd_en & mem_B_valid) ? rd_addr : mem_B_addr_0),
    .address_1(mem_B_addr_1),
    .wren_0(mem_B_wren_0),
    .wren_1(1'b0),
    .q_0(mem_B_dout_0),
    .q_1(mem_B_dout_1)
  );

  assign data_out = mem_A_valid ? mem_A_dout_0 : mem_B_dout_0;

endmodule

