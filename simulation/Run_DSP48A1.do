vlib work
vlog ../src/DSP48A1.v ../tb/DSP48A1_tb.v
vsim -voptargs=+acc work.DSP48A1_tb
add wave *
run -all