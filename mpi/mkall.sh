#!/bin/sh
# Use this file to make on Prince cluster

module purge
module load gcc/6.3.0
module load fftw/openmpi/intel/3.3.5
export MARCH="-march=core-avx2 -mtune=core-avx2"
export CXXFLAGS="-I/share/apps/fftw/3.3.5/openmpi/intel/include/"
export LDFLAGS=-L/share/apps/fftw/3.3.5/openmpi/intel/lib/
make fftw-mpi

module purge
module load gcc/9.1.0
module load openmpi/gnu/3.1.4
export MARCH="-march=broadwell -mtune=broadwell"
#export MARCH="-march=haswell -mtune=haswell"
export CXXFLAGS=
export LDFLAGS=
make all
