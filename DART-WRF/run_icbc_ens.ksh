date

export OUTPUT_FREQ_MINUTE=`expr 60 \* ${OUTPUT_INTERVAL}`
export LBC_FREQ_SECOND=`expr 3600 \* ${LBC_FREQ}` # for REAL interpolation

export START_DATE=`${BUILD_DIR}/da_advance_time.exe $DATE 0 -w`
export END_DATE=`${BUILD_DIR}/da_advance_time.exe $DATE $SPINUP_TIME -w`
export ccyy_s=`echo $START_DATE | cut -c1-4`
export mm_s=`echo $START_DATE | cut -c6-7`
export dd_s=`echo $START_DATE | cut -c9-10`
export hh_s=`echo $START_DATE | cut -c12-13`
export ccyy_e=`echo $END_DATE | cut -c1-4`
export mm_e=`echo $END_DATE | cut -c6-7`
export dd_e=`echo $END_DATE | cut -c9-10`
export hh_e=`echo $END_DATE | cut -c12-13`

IMEM=1
while (( IMEM <= ${NUM_GEFS} )) ; do

if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi

if [[ ! -d $WORK_DIR/$CMEM ]]; then mkdir -p $WORK_DIR/$CMEM; fi
cd $WORK_DIR/$CMEM

ln -sf $WRF_DIR/run/* .
rm namelist.input    

ln -sf ${WPS_ENS_DIR}/$CMEM/met_em* .

# create namelist.input
cat > namelist.input << EOF
 &time_control
 run_days                            = 0,
 run_hours                           = ${SPINUP_TIME},
 run_minutes                         = 0,
 run_seconds                         = 0,
 start_year                          = ${ccyy_s},${ccyy_s},
 start_month                         = ${mm_s},${mm_s} 
 start_day                           = ${dd_s},${dd_s} 
 start_hour                          = ${hh_s},${hh_s}
 start_minute                        = 00,00, 
 start_second                        = 00,00,  
 end_year                            = ${ccyy_e},${ccyy_e} 
 end_month                           = ${mm_e},${mm_e} 
 end_day                             = ${dd_e},${dd_e}  
 end_hour                            = ${hh_e},${hh_e} 
 end_minute                          = 00,00, 
 end_second                          = 00,00,  
 interval_seconds                    = ${LBC_FREQ_SECOND},
 input_from_file                     = .true.,.true.,
 history_interval                    = ${OUTPUT_FREQ_MINUTE},${OUTPUT_FREQ_MINUTE}, 
 frames_per_outfile                  = 1,1,
 restart                             = .false.,
 restart_interval                    = 2161,
 debug_level                         = 0,
 write_input                         = .false.,
 /

 &domains
 time_step                           = ${NL_TIME_STEP},  
 time_step_fract_num                 = 0,
 time_step_fract_den                 = 1,
 max_dom                             = 1,
 e_we                                = ${NL_E_WE_1},${NL_E_WE_2} 
 e_sn                                = ${NL_E_SN_1},${NL_E_SN_2}
 e_vert                              = ${NL_E_VERT},${NL_E_VERT}
 dx                                  = ${NL_DXY_1},${NL_DXY_2} 
 dy                                  = ${NL_DXY_1},${NL_DXY_2}
 grid_id                             = 1, 2, 
 parent_id                           = 0, 1,
 i_parent_start                      = 1, ${I_PARENT_START_2}
 j_parent_start                      = 1, ${J_PARENT_START_2}
 parent_grid_ratio                   = 1, ${PARENT_GRID_RATIO_2}
 parent_time_step_ratio              = 1, ${PARENT_GRID_RATIO_2} 
 feedback                            = ${FEEDBACK},
 p_top_requested                     = ${NL_P_TOP_REQUESTED},
 num_metgrid_levels                  = 13
 num_metgrid_soil_levels             = 4,
 hypsometric_opt                     = 2,
 smooth_option                       = 0,
 eta_levels                          = ${NL_ETA_LEVELS}
 /

 &physics
 mp_physics                          = ${NL_MP_PHYSICS},${NL_MP_PHYSICS},
 ra_lw_physics                       = ${NL_RA_LW}, ${NL_RA_LW},  
 ra_sw_physics                       = ${NL_RA_SW}, ${NL_RA_SW},
 radt                                = ${NL_RADT1}, ${NL_RADT2}, 
 sf_sfclay_physics                   = ${NL_SF_SFCLAY_PHYSICS}, ${NL_SF_SFCLAY_PHYSICS},
 sf_surface_physics                  = ${NL_SF_SURFACE_PHYSICS}, ${NL_SF_SURFACE_PHYSICS}, 
 bl_pbl_physics                      = ${NL_BL_PBL_PHYSICS},  ${NL_BL_PBL_PHYSICS},
 bldt                                = ${NL_BLDT}, 
 cu_physics                          = ${NL_CU_PHYSICS1},${NL_CU_PHYSICS2},   
 cudt                                = ${NL_CUDT1},${NL_CUDT2},  
 DO_RADAR_REF                        = 1,
 isfflx                              = 1,
 ifsnow                              = 1,
 icloud                              = 1,
 surface_input_source                = 1,
 num_soil_layers                     = 4,
 /
 
 &stoch
 stoch_force_opt                     =$SKEB,
 stoch_vertstruc_opt                 =1,
 tot_backscat_psi                    =1.0E-5
 tot_backscat_t                      =1.0E-6
 nens                                =$NUM_MEMBERS
 perturb_bdy                         =$PERT_BDY
 /
 
 &fdda
 /

 &dynamics
 w_damping                           = 1,
 diff_opt                            = 1,
 gwd_opt                             = 0,
 km_opt                              = 4,
 diff_6th_opt                        = 0,
 diff_6th_factor                     = 0.12,
 base_temp                           = 290.,
 damp_opt                            = 0,
 zdamp                               = 5000., 5000.,
 dampcoef                            = 0.15, 0.15, 
 khdif                               = 0, 0,  
 kvdif                               = 0, 0,
 non_hydrostatic                     = .true., .true.,
 moist_adv_opt                       = 1, 1,
 scalar_adv_opt                      = 0, 0,
 /
 &bdy_control
 spec_bdy_width                      = 5,
 spec_zone                           = 1,
 relax_zone                          = 4,
 specified                           = .true., .false., 
 nested                              = .false., .true.,
 /
 &grib2
 /
 &namelist_quilt
 nio_tasks_per_group = 0,
 nio_groups = 1,
 /
 &dfi_control
 /
EOF

${RUN_CMD}  ./real.exe

if grep -q 'SUCCESS COMPLETE REAL_EM INIT' rsl.out.0000; then
  echo success > SUCCESS
else
  echo fail > FAIL
fi

(( IMEM=IMEM+1 ))
done

date

exit 0

