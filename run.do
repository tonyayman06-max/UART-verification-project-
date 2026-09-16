vlib work
vlog -f Try.list +cover -covercells
vsim -voptargs=+acc work.testbench -cover
do wave.do
coverage save testbench.ucdb -onexit
run -all
vcover report testbench.ucdb -details -annotate -all -output ALU_cover_report.txt