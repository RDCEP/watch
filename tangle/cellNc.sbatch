#!/bin/bash -l

#SBATCH --account=pi-joshuaelliott
#SBATCH --qos=normal
# #SBATCH --partition=bigmem
#SBATCH --partition=westmere,sandyb
# #SBATCH --partition=sandyb
#SBATCH --time=60  # max minutes per run, will help the scheduler to get your job to run faster
#SBATCH --exclusive

START=$(date)
tangle/cellNc.r ${stripe}
END=$(date)
echo "started at $START"
echo "ended at $END"
