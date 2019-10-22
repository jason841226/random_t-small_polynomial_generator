all:
	iverilog src/clog2.v src/merge_sort_4x_pipeline.v src/merge_sort_tb.v src/mem_dual.v src/compare_half.v -o bin/small_t