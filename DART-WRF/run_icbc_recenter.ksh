date

# copy wrfinput_d01 and wrfbdy_d01 for update
IMEM=1
while (( IMEM <= ${NUM_MEMBERS} )) ; do
  if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi
  if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi

  if [[ ! -d $WORK_DIR/${CMEM} ]]; then mkdir -p $WORK_DIR/${CMEM}; fi
  cp ${REAL_FC_DIR}/${DATE}/wrfinput_d01 $WORK_DIR/${CMEM}/wrfvar_output
  cp ${REAL_FC_DIR}/${DATE}/wrfbdy_d01   $WORK_DIR/${CMEM}/wrfbdy_d01

  ln -sf ${ICBC_ENS_DIR}/${CMEM}/wrfinput_d01 ./wrfinput_d01.${CMEM}

  let IMEM=$IMEM+1
done
ln -sf ${REAL_FC_DIR}/${DATE}/wrfinput_d01 ./wrfinput_d01

# Recenter to GFS
cp ${SCRIPTS_DIR}/recenter.ncl .

ncl recenter.ncl > recenter.log 2>&1

# Update boundary
IMEM=1
while (( $IMEM <= $NUM_MEMBERS )); do

export CMEM=e$MEM
if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM; fi
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi

cat > parame.in << EOF
&control_param
 da_file            = './${CMEM}/wrfvar_output'
 wrf_bdy_file       = './${CMEM}/wrfbdy_d01'
 update_lateral_bdy = .true.
 update_low_bdy     = .false.
 update_lsm         = .false.
 iswater            = 17
 /
EOF
ln -sf ${BUILD_DIR}/da_update_bc.exe .
./da_update_bc.exe > update_lbc.out.$CMEM 2>&1

(( IMEM=$IMEM+1 ))
done

if grep -q 'Successfully recentering all members!' recenter.log; then
  echo success > SUCCESS
else 
  echo fail > FAIL
fi

date

exit 0
