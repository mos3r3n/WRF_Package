date

export DATE0=`${BUILD_DIR}/da_advance_time.exe ${DATE} +0h00min -wrf`
export DATE1=`${BUILD_DIR}/da_advance_time.exe ${DATE} -${SUB_WINDOW1} -wrf`
export DATE2=`${BUILD_DIR}/da_advance_time.exe ${DATE} +${SUB_WINDOW1} -wrf`

export START_DATE=`${BUILD_DIR}/da_advance_time.exe $DATE 0 -w`
export ccyy_s=`echo $START_DATE | cut -c1-4`
export mm_s=`echo $START_DATE | cut -c6-7`
export dd_s=`echo $START_DATE | cut -c9-10`
export hh_s=`echo $START_DATE | cut -c12-13`

IMEM=${INI_ENS:-1}
while (( IMEM <= ${NUM_MEMBERS} )) ; do

if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi

if [[ ! -d $WORK_DIR/$CMEM ]]; then mkdir -p $WORK_DIR/$CMEM; fi
cd $WORK_DIR/$CMEM

let SEED1=${ccyy_s} ##$IMEM
		   
ln -sf ${WRFVAR_DIR}/run/LANDUSE.TBL  ./  
ln -sf ${WRFVAR_DIR}/var/run/be.dat.cv3 ./be.dat

if $USE_GEFS; then
  export I_ICBC=`expr $IMEM % $NUM_GEFS`
  if [[ $I_ICBC -ge 10 ]]; then export ICMEM=e0$I_ICBC;  fi
  if [[ $I_ICBC -lt 10 ]]; then export ICMEM=e00$I_ICBC; fi  
  if [[ $I_ICBC -eq 0  ]]; then export ICMEM=e0$NUM_GEFS; fi
  ln -sf $ICBC_ENS_DIR/${DATE}/$ICMEM/wrfinput_d01 ./fg
  cp $ICBC_ENS_DIR/${DATE}/$ICMEM/wrfbdy_d01 ./wrfbdy_d01
  export N_RANDOMCV=1
else
  ln -sf $REAL_FC_DIR/$DATE/wrfinput_d01 ./fg	 
  cp $REAL_FC_DIR/$DATE/wrfbdy_d01 ./wrfbdy_d01	
  export N_RANDOMCV=${NUM_MEMBERS}
fi

# create WRFVAR namelist
export SEED2=$((${SEED1}*100))

rm -f ./namelist.input
cat > namelist.input << EOF 
&wrfvar1
/
&wrfvar2
/
&wrfvar3
 ob_format=1
/
&wrfvar4
 use_synopobs=T,
 use_shipsobs=T,
 use_metarobs=T,
 use_soundobs=T,
 use_pilotobs=T,
 use_airepobs=T,
 use_geoamvobs=T,
 use_polaramvobs=T,
 use_bogusobs=F,
 use_buoyobs=T,
 use_profilerobs=T,
 use_satemobs=F,
 use_gpspwobs=T,
 use_gpsrefobs=T,
 use_ssmiretrievalobs=F,
 use_ssmitbobs=F,
 use_ssmt1obs=F,
 use_ssmt2obs=F,
 use_qscatobs=T,
 use_radarobs=F,
 use_radar_rv=F,
 use_radar_rhv=F,
 use_radar_rqv=F,
/
&wrfvar5
 max_error_rv=5.0,
 max_error_rf=5.0,
 put_rand_seed=T,
 check_max_iv=T,
/
&wrfvar6
 max_ext_its=1
 ntmax=500,
/
&wrfvar7
rf_passes=6,
cv_options=3,
as1=0.063, 0.75, 1.50,
as2=0.063, 0.75, 1.50,
as3=0.22, 1.00, 1.50,
as4=0.05, 0.30, 0.70,
as5=0.27, 0.50, 1.50,
var_scaling1=1.0,
var_scaling2=1.0,
var_scaling3=1.0,
var_scaling4=1.0,
var_scaling5=1.0,
len_scaling1=1.0,
len_scaling2=1.0,
len_scaling3=1.0,
len_scaling4=1.0,
len_scaling5=1.0,
&wrfvar8
/
&wrfvar9
/
&wrfvar10
/
&wrfvar11
cv_options_hum                      = 1,
check_rh                            = 1,
seed_array1                         = ${SEED1},
seed_array2                         = ${SEED2},
/
&wrfvar12
/
&wrfvar13
/
&wrfvar14
/
&wrfvar15
/
&wrfvar16
/
&wrfvar17
analysis_type                       = 'RANDOMCV',
n_randomcv = ${N_RANDOMCV}
/
&wrfvar18
analysis_date="${DATE0}.0000",
/
&wrfvar19
/
&wrfvar20
/
&wrfvar21
time_window_min="${DATE1}.0000",
/
&wrfvar22
time_window_max="${DATE2}.0000",
/
&wrfvar23
/
&time_control
/
&fdda
/
&domains
e_we                                = ${NL_E_WE_1}
e_sn                                = ${NL_E_SN_1}
e_vert                              = ${NL_E_VERT}
dx                                  = ${NL_DXY_1}
dy                                  = ${NL_DXY_1}
/
&physics
mp_physics                          = ${NL_MP_PHYSICS},
sf_sfclay_physics                   = ${NL_SF_SFCLAY_PHYSICS},
sf_surface_physics                  = ${NL_SF_SURFACE_PHYSICS},
num_soil_layers                     = ${NL_NUM_SOIL_LAYERS},
/
&dynamics
use_theta_m=1,
hybrid_opt=2,
/
&dfi_control
/
&namelist_quilt
/
EOF

ln -sf ${BUILD_DIR}/da_wrfvar.exe ./

if $USE_GEFS || [ $IMEM -eq 1 ]; then
  ${RUN_CMD} ./da_wrfvar.exe  > run_rcv.out 2>&1
  mv wrfvar_output_randomcv.e001 wrfvar_output
  mv rsl.out.0000 rsl.out.rcv
  mv rsl.error.0000 rsl.err.rcv
  rm *.0*
else
  mv $WORK_DIR/e001/wrfvar_output_randomcv.${CMEM} wrfvar_output
fi

mv 

# update lateral boundary
ln -sf ${BUILD_DIR}/da_update_bc.exe .

cat > parame.in << EOF
&control_param
 da_file            = 'wrfvar_output'
 wrf_bdy_file       = 'wrfbdy_d01'
 update_lateral_bdy = .true.
 update_low_bdy     = .false.
 update_lsm         = .false.
 iswater            = 17 /
EOF

./da_update_bc.exe
###############################
				
(( IMEM=IMEM+1 ))
done

date	

exit 0
