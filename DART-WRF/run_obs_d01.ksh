date

export DATE0=`${BUILD_DIR}/da_advance_time.exe ${DATE} +0h00min -wrf`
export DATE1=`${BUILD_DIR}/da_advance_time.exe ${DATE} -${SUB_WINDOW1} -wrf`
export DATE2=`${BUILD_DIR}/da_advance_time.exe ${DATE} +${SUB_WINDOW1} -wrf`
export DIS=`expr $NL_DXY_1 / 1000`

ln -sf $WRFVAR_DIR/var/obsproc/* .

if [[ $MAP_PROJ == lambert ]]; then
   export PROJ=1
elif [[ $MAP_PROJ == polar ]];  then
   export PROJ=2
elif [[ $MAP_PROJ == mercator ]]; then
   export PROJ=3
else
   echo "   Unknown MAP_PROJ = $MAP_PROJ."
   exit 1
fi

cat > namelist.obsproc << EOF
&record1
 obs_gts_filename = '$OBS_DIR/obs_r.${YYYY}${MM}${DD}${HH}',
 fg_format        = 'WRF',
 obs_err_filename = 'obserr.txt',
/

&record2
 time_window_min  = '${DATE1}',
 time_analysis    = '${DATE0}',
 time_window_max  = '${DATE2}',
/

&record3
 max_number_of_obs        = 4000000,
 fatal_if_exceed_max_obs  = .TRUE.,
/

&record4
 qc_test_vert_consistency = .TRUE.,
 qc_test_convective_adj   = .TRUE.,
 qc_test_above_lid        = .TRUE.,
 remove_above_lid         = .TRUE.,
 domain_check_h           = .true.,
 Thining_SATOB            = .true.,
 Thining_SSMI             = .true.,
 Thining_QSCAT            = .true.,
/

&record5
 print_gts_read           = .TRUE.,
 print_gpspw_read         = .TRUE.,
 print_recoverp           = .TRUE.,
 print_duplicate_loc      = .TRUE.,
 print_duplicate_time     = .TRUE.,
 print_recoverh           = .TRUE.,
 print_qc_vert            = .TRUE.,
 print_qc_conv            = .TRUE.,
 print_qc_lid             = .TRUE.,
 print_uncomplete         = .TRUE.,
/

&record6
 ptop =  ${NL_P_TOP_REQUESTED},
 base_pres       = 100000.0,
 base_temp       = 290.0,
 base_lapse      = 50.0,
 base_strat_temp = 215.0,
 base_tropo_pres = 20000.0
/

&record7
 IPROJ = ${PROJ},
 PHIC  = ${REF_LAT},
 XLONC = ${REF_LON},
 TRUELAT1= ${TRUELAT1},
 TRUELAT2= ${TRUELAT2},
 MOAD_CEN_LAT = ${REF_LAT},
 STANDARD_LON = ${STAND_LON},
/

&record8
 IDD    =   1,
 MAXNES =   1,
 NESTIX =  ${NL_E_SN_1}, 
 NESTJX =  ${NL_E_WE_1}, 
 DIS    =  ${DIS}, 
 NUMC   =    1,  
 NESTI  =    1, 
 NESTJ  =    1,  
 / 

&record9
 PREPBUFR_OUTPUT_FILENAME = 'prepbufr_output_filename',
 PREPBUFR_TABLE_FILENAME = 'prepbufr_table_filename',
 OUTPUT_OB_FORMAT = 2
 use_for          = '3DVAR',
 num_slots_past   = 3,
 num_slots_ahead  = 3,
 write_synop = .true., 
 write_ship  = .true.,
 write_metar = .true.,
 write_buoy  = .true., 
 write_pilot = .true.,
 write_sound = .true.,
 write_amdar = .true.,
 write_satem = .true.,
 write_satob = .true.,
 write_airep = .true.,
 write_gpspw = .true.,
 write_gpsztd= .true.,
 write_gpsref= .true.,
 write_gpseph= .true.,
 write_ssmt1 = .true.,
 write_ssmt2 = .true.,
 write_ssmi  = .true.,
 write_tovs  = .true.,
 write_qscat = .true.,
 write_profl = .true.,
 write_bogus = .true.,
 write_airs  = .true.,
 /
EOF

 ./obsproc.exe

###############################################################################
rm input.nml
cp $NML_DIR/input.nml.obs.d01 ./input.nml

cp obs_gts_${DATE0}.3DVAR ob.ascii
ln -sf ${DART_DIR}/observations/obs_converters/var/work/gts_to_dart .
if [ -e dart_log.out ]; then
  rm dart_log.out
fi
./gts_to_dart
mv input.nml input.nml.d01
mv obs_seq.out obs_seq.${DATE}

# Check result
if grep -q 'gts_to_dart Finished successfully' dart_log.out; then
   echo success > SUCCESS
else
   echo fail > FAIL
fi

date	

exit 0
