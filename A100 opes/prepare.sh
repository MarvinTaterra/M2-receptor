#!/bin/bash

# Number of walkers
N_WALKERS=10

# Create directories and prepare input files
for i in $(seq 0 $((N_WALKERS-1))); do
  mkdir -p walker$i
  cp prod_1.tpr walker$i/prod.tpr
  cat > walker$i/plumed.dat << EOF
# Define distances between relevant atom pairs
term1: DISTANCE ATOMS=A,B  # 1.53 - 7.55
term2: DISTANCE ATOMS=A,B  # 2.50 - 3.37
term3: DISTANCE ATOMS=A,B # 3.42 - 4.42
term4: DISTANCE ATOMS=A,B # 5.66 - 6.34
term5: DISTANCE ATOMS=A,B # 6.58 - 7.35

# Compute the initial combined value using the given coefficients
comb: COMBINE ARG=term1,term2,term3,term4,term5 COEFFICIENTS=-144.3,-76.2,91.1,-63.2,-52.2 POWERS=1,1,1,1,1 PERIODIC=NO

# Add the constant 278.88 to obtain A100
A100: MATHEVAL ARG=comb FUNC=x+278.88 PERIODIC=NO

# Apply OPES metadynamics bias with multiple walkers
opes: OPES_METAD ARG=A100 TEMP=303.15 PACE=500 BARRIER=50 FILE=KERNELS WALKERS_MPI

# Print values every 500 steps
PRINT FILE=COLVAR STRIDE=500 ARG=A100,opes.bias,opes.rct,opes.zed
EOF
done

# Create a submission script 
cat > run_multi_walker.sh << EOF
#!/bin/bash

# Set number of MPI processes per walker
CORES_PER_WALKER=1
TOTAL_CORES=\$((CORES_PER_WALKER * $N_WALKERS))

# Create the walker directory string
WALKER_DIRS=""
for i in \$(seq 0 \$(($N_WALKERS-1))); do
  WALKER_DIRS="\$WALKER_DIRS walker\$i"
done

# Run with multiple walkers, one GPU per walker if available
mpirun -np \$TOTAL_CORES \\
  gmx_mpi mdrun -v \\
  -deffnm prod \\
  -plumed plumed.dat \\
  -bonded gpu \\
  -nb gpu \\
  -pme gpu \\
  -npme 0 \\
  -ntomp 1 \\
  -pin on \\
  -multidir \$WALKER_DIRS \\
  -nsteps 50000000


chmod +x run_multi_walker.sh

echo "Setup complete. Run ./run_multi_walker.sh to start the simulation with $N_WALKERS walkers."
