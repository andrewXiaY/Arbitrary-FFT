#!/bin/bash
#
#SBATCH --job-name=n10000000-np4
#SBATCH --nodes=1
#SBATCH --tasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --time=1:00:00
#SBATCH --mem=8GB
#SBATCH --partition=c18_25
#SBATCH --output=n10000000-np4.out
#SBATCH --error=n10000000-np4.err

module purge
module load openmpi/gnu/4.0.2
echo vvvvvvvvvvvvvvvv n10000000-np4-mpih-s0 vvvvvvvvvvvvvvvv
mpiexec ../mpi-h 0 10000000 n10000000-in.dat n10000000-np4-mpih-s0.dat
echo ^^^^^^^^^^^^^^^^ n10000000-np4-mpih-s0 ^^^^^^^^^^^^^^^^
echo

module purge
module load fftw/openmpi/intel/3.3.5
echo vvvvvvvvvvvvvvvv n10000000-np4-fftw-s0 vvvvvvvvvvvvvvvv
mpiexec ../fftw-mpi 0 10000000 n10000000-in.dat n10000000-np4-fftw-s0.dat
echo ^^^^^^^^^^^^^^^^ n10000000-np4-fftw-s0 ^^^^^^^^^^^^^^^^
echo

echo ======== CMP n10000000-np4-mpih-s0.dat n10000000-np4-fftw-s0.dat ========
../cmp 10000000 n10000000-np4-mpih-s0.dat n10000000-np4-fftw-s0.dat
echo

rm -f n10000000-np4-mpih-s0.dat
rm -f n10000000-np4-fftw-s0.dat

module purge
module load openmpi/gnu/4.0.2
echo vvvvvvvvvvvvvvvv n10000000-np4-mpih-s1 vvvvvvvvvvvvvvvv
mpiexec ../mpi-h 1 10000000 n10000000-in.dat n10000000-np4-mpih-s1.dat
echo ^^^^^^^^^^^^^^^^ n10000000-np4-mpih-s1 ^^^^^^^^^^^^^^^^
echo

module purge
module load fftw/openmpi/intel/3.3.5
echo vvvvvvvvvvvvvvvv n10000000-np4-fftw-s1 vvvvvvvvvvvvvvvv
mpiexec ../fftw-mpi 1 10000000 n10000000-in.dat n10000000-np4-fftw-s1.dat
echo ^^^^^^^^^^^^^^^^ n10000000-np4-fftw-s1 ^^^^^^^^^^^^^^^^
echo

echo ======== CMP n10000000-np4-mpih-s1.dat n10000000-np4-fftw-s1.dat ========
../cmp 10000000 n10000000-np4-mpih-s1.dat n10000000-np4-fftw-s1.dat
echo

rm -f n10000000-np4-mpih-s1.dat
rm -f n10000000-np4-fftw-s1.dat
