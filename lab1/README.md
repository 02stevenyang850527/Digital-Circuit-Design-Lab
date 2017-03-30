# Lab 1: Roll Call Machine

## Introduction

A roll call machine which generates a random number range between 0 to 15 every time after pressing the start button.

## Usage

1. Clone from Github
2. Connect DE2-115 FPGA board to your computer by USB
3. Install Quartus II on either Windows or Linux
   1. Open Quartus II，choose project file “DE2_115.qpf”
   2. Compile the project by pressing Ctrl + L
   3. Open Tools ➝ Programmer 
   4. Click on “Hardware Setup”, choose the FPGA board which is connected to your computer by USB
   5. Click on “Add File”, select “DE2_115.sof” under directory “output_files”
   6. To upload codes to FPGA board temporally, select “JTAG” mode, switch FPGA board to “run” mode, and click “Start” button in Programmer to start uploading
   7. To upload codes to FPGA board permanently, select “Active Serial Programming” mode, switch FPGA board to “Program” mode, and select file “DE2_115.pof” to upload
   8. To convert .sof files into .pof files, simply click on File ➝ Convert Programming Files
4. FPGA board
   1. Press reset button KEY1 for initialization purpose
   2. Press start button KEY0 so as to get a random number every time

## Simulation

1. Premise: to run simulation, you should have the permission to access NTU DCLab server
2. Login to DCLab sever
3. Upload codes to server by “scp” command in terminal, or use MobaXterm if your are a Windows user
4. Enable ncsim for simulation purpose and enable nWave to checkout output waveform
5. Change directory to sim/
6. Type "make TEST=LAB1 TOPLEVEL=DE2_115 SV=1" to run GUI simulation

## Notes

By default the simulation runs 1000 cycles Verilog
simulation and sleep 100ms.
