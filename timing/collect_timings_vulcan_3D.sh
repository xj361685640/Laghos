#!/usr/bin/env bash

options=( 'pa' 'fa' )

parallel_refs=0
minL2dof=200
maxL2dof=1000000

# To get Cartesian mesh partitions, use 4/32/256 ... nodes.
nodes=4
nproc=$(( 16 * nodes))

outfile=timings_3d
mesh_file=../data/cube01_hex.mesh

calc() { awk "BEGIN{print $*}"; }

run_case()
{
    # Pass command as all inputs
    # Outputs: order refs h1_dofs l2_dofs h1_cg_rate l2_cg_rate forces_rate update_quad_rate

    "$@" | tee run.log | awk '
BEGIN { ref = 0 }
/--refine-serial/ { ref += $2 }
/--refine-parallel/ { ref += $2 }
/--order/ { order = $2 }
/Number of kinematic/ { h1_dofs = $7 }
/Number of specific internal energy/ { l2_dofs = $7 }
/CG \(H1\) rate/ { h1_cg_rate = $9 }
/CG \(L2\) rate/ { l2_cg_rate = $9 }
/Forces rate/ { forces_rate = $8 }
/UpdateQuadData rate/ { update_quad_rate = $8 }
/Major kernels total rate/ { total_time = $11 }
END { printf("%d %d %d %d %.8f %.8f %.8f %.8f %.8f\n", order, ref, h1_dofs, l2_dofs, h1_cg_rate, l2_cg_rate, forces_rate, update_quad_rate, total_time) }'
}

for method in "${options[@]}"; do
  echo "# order refs h1_dofs l2_dofs h1_cg_rate l2_cg_rate forces_rate update_quad_rate total_time" > $outfile"_"$method
  for torder in {0..4}; do
    for sref in {0..10}; do
       nzones=$(( 8**(sref+1) ))
       nL2dof=$(( nzones*(torder+1)**3 ))
       if (( nproc <= nzones )) && (( nL2dof > minL2dof )) && (( nL2dof < maxL2dof )) ; then
         echo "np"$nproc "Q"$((torder+1))"Q"$torder $sref"ref" $method $outfile"_"$method
         echo $(run_case srun -n $nproc ../laghos -$method -p 1 -tf 0.8 \
                       --cg-tol 0 --cg-max-steps 50 \
                       --max-steps 10 \
                       --mesh $mesh_file \
                       --refine-serial $sref \
                       --refine-parallel $parallel_refs \
                       --order-thermo $torder \
                       --order-kinematic $((torder+1))) >> $outfile"_"$method
      fi
    done
  done
done
