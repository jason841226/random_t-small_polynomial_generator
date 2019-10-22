/*
 * 
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
// compare the values of two inputs and do conditional swapping

module compare 
  #(
    parameter WIDTH = 32
  )
  (
    input wire [WIDTH-1:0] dinL,
    input wire [WIDTH-1:0] dinR,
    
    output wire L_smaller,
    output wire equal
     
  );
  
  wire [WIDTH/2:0] dinL_part_0_processed;
  wire [WIDTH/2:0] dinL_part_1_processed;
  wire [WIDTH/2:0] dinR_part_0_processed;
  wire [WIDTH/2:0] dinR_part_1_processed;
  
  wire [WIDTH/2:0] part_0_res;
  wire [WIDTH/2:0] part_1_res;
  wire part_0_equal;
  
  assign dinL_part_0_processed = {1'b0, dinL[WIDTH-1:WIDTH/2]};
  assign dinL_part_1_processed = {1'b0, dinL[WIDTH/2-1:0]};
  assign dinR_part_0_processed = {1'b0, dinR[WIDTH-1:WIDTH/2]};
  assign dinR_part_1_processed = {1'b0, dinR[WIDTH/2-1:0]};
  
  assign part_0_res = (dinL_part_0_processed-dinR_part_0_processed);
  assign part_1_res = (dinL_part_1_processed-dinR_part_1_processed);
  
  assign part_0_equal = (dinL_part_0_processed == dinR_part_0_processed);
  
  assign L_smaller = part_0_res[WIDTH/2] || (part_0_equal & part_1_res[WIDTH/2]);
  
  assign equal = (dinL == dinR);
  
endmodule

  