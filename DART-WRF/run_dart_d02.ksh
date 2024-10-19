date

export PRV_DATE=$($BUILD_DIR/da_advance_time.exe $DATE -${WINDOW_START} -f ccyymmddhhnn 2>/dev/null)
export ADV_DATE=$($BUILD_DIR/da_advance_time.exe $DATE  ${WINDOW_END} -f ccyymmddhhnn 2>/dev/null)

# time related
export year=`echo   $DATE | cut -c1-4`
export month=`echo  $DATE | cut -c5-6`
export day=`echo    $DATE | cut -c7-8`
export hour=`echo   $DATE | cut -c9-10` 
export minute=`echo   $DATE | cut -c11-12`

export year1=`echo  $PRV_DATE | cut -c1-4`
export month1=`echo $PRV_DATE | cut -c5-6`
export day1=`echo   $PRV_DATE | cut -c7-8`
export hour1=`echo  $PRV_DATE | cut -c9-10` 
export minute1=`echo  $PRV_DATE | cut -c11-12`

export year2=`echo  $ADV_DATE | cut -c1-4`
export month2=`echo $ADV_DATE | cut -c5-6`
export day2=`echo   $ADV_DATE | cut -c7-8`
export hour2=`echo  $ADV_DATE | cut -c9-10` 
export minute2=`echo  $ADV_DATE | cut -c11-12`


# prepare observations
ln -sf $OBS_D02_DIR/${DATE}/obs_seq.${DATE} ./obs_seq.out

# prepare executable file
ln -sf $DART_DIR/models/wrf/work/filter .
ln -sf $DART_DIR/assimilation_code/programs/gen_sampling_err_table/work/sampling_error_correction_table.nc .

# prepare first guess, ensembles and something related
if [[ ! -d $WORK_DIR/priors ]]; then mkdir -p $WORK_DIR/priors; fi
if [[ ! -d $WORK_DIR/posts ]]; then mkdir -p $WORK_DIR/posts; fi
IMEM=1
while (( IMEM <= ${NUM_MEMBERS} )) ; do

if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi

ln -sf ${ENS_WRF_DIR}/${PREV_DATE}/$CMEM/wrfout_d02_${FILE_DATE} $WORK_DIR/priors/wrfinput_d02.$CMEM
cp ${ENS_WRF_DIR}/${PREV_DATE}/$CMEM/wrfout_d02_${FILE_DATE} $WORK_DIR/posts/wrfvar_output.$CMEM

let IMEM=$IMEM+1
done

ls $WORK_DIR/priors/wrfinput* > input_list_d02.txt
ls $WORK_DIR/posts/wrfvar_output* > output_list_d02.txt

ln -sf ${ENS_WRF_DIR}/$PREV_DATE/e001/wrfout_d02_${FILE_DATE} ./wrfinput_d01

# creat input.nml
rm input.nml

if [[ $RADAR_NUMBER -eq 1 ]]; then 
   export inf_initial_from_restart=".false."
   export inf_sd_initial_from_restart=".false."
else
   export inf_initial_from_restart=".true."
   export inf_sd_initial_from_restart=".true."
   ln -sf $DART_D02_DIR/$PREV_DATE/output_postinf_mean.nc input_priorinf_mean.nc 
   ln -sf $DART_D02_DIR/$PREV_DATE/output_postinf_sd.nc   input_priorinf_sd.nc 
fi

cat > script.sed << EOF
  /ens_size/c\
  ens_size = ${NUM_MEMBERS},
  /num_output_obs_members/c\
      num_output_obs_members = ${NUM_MEMBERS},
  /inf_initial_from_restart/c\
      inf_initial_from_restart = ${inf_initial_from_restart}, .false.,
  /inf_sd_initial_from_restart/c\
      inf_sd_initial_from_restart = ${inf_sd_initial_from_restart}, .false.,
  /layout/c\
      layout = ${lay_out},
  /tasks_per_node/c\
      tasks_per_node = ${tasks_per_node},
  /first_bin_center/c\
      first_bin_center = ${year1},${month1},${day1},${hour1}, 0, 0
  /last_bin_center/c\
      last_bin_center = ${year2},${month2},${day2},${hour2}, 0, 0
EOF

if [ ${ASSIM_RADAR} -eq "TRUE" ]; then
  sed -f script.sed $NML_DIR/input.nml.d02.radar > input.nml
else
  sed -f script.sed $NML_DIR/input.nml.d02.conv  > input.nml
fi 

if [ -e dart_log.out ];then
  rm dart_log.out
fi

# start EAKF analyze
${RUN_CMD} ./filter

# diagnosis on the observatoion space
ln -sf $DART_DIR/models/wrf/work/obs_diag .
./obs_diag

# Check result
if grep -q 'FINISHED filter.' dart_log.out; then
   echo success > SUCCESS
else
   echo fail > FAIL
fi

date

exit 0
