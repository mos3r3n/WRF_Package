date

export LBC_FREQ_SECOND=`expr 3600 \* ${CYCLE_PERIOD}` 

export START_DATE=`${BUILD_DIR}/da_advance_time.exe $INITIAL_DATE 0 -w`
export END_DATE=`${BUILD_DIR}/da_advance_time.exe $INITIAL_DATE $SPINUP_TIME -w`

export ccyy_s=`echo $START_DATE | cut -c1-4`
export mm_s=`echo $START_DATE | cut -c6-7`
export dd_s=`echo $START_DATE | cut -c9-10`
export hh_s=`echo $START_DATE | cut -c12-13`
export ccyy_e=`echo $END_DATE | cut -c1-4`
export mm_e=`echo $END_DATE | cut -c6-7`
export dd_e=`echo $END_DATE | cut -c9-10`
export hh_e=`echo $END_DATE | cut -c12-13`

export EDATE=${ccyy_e}${mm_e}${dd_e}${hh_e}00
echo ${EDATE}

if [ $NUM_GEFS -le $NUM_MEMBERS ]; then
   export NUM_WPS=$NUM_GEFS
else
   export NUM_WPS=$NUM_MEMBERS
fi

IMEM=1
while [[ $IMEM -le $NUM_WPS ]]; do
CMEM=e`printf %3.3i $IMEM`
CMEM2=`printf %2.2i $IMEM`

if [[ ! -d $WORK_DIR/$CMEM ]]; then mkdir -p $WORK_DIR/$CMEM; fi
cd $WORK_DIR/$CMEM

ln -sf $WPS_DIR/* .
rm namelist.wps

# create namelist.wps
cat > namelist.wps << EOF
&share
 wrf_core = 'ARW',
 max_dom = 1,
 start_date = '${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00','${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00','${ccyy_s}-${mm_s}-${dd_s}_${hh_s}:00:00',
 end_date   = '${ccyy_e}-${mm_e}-${dd_e}_${hh_e}:00:00','${ccyy_e}-${mm_e}-${dd_e}_${hh_e}:00:00','${ccyy_e}-${mm_e}-${dd_e}_${hh_e}:00:00',
 interval_seconds = ${LBC_FREQ_SECOND},
 io_form_geogrid = 2,
/

&geogrid
 parent_id         =   0,1,2
 parent_grid_ratio =   1,${PARENT_GRID_RATIO_2},${PARENT_GRID_RATIO_3},
 i_parent_start    =   1,${I_PARENT_START_2},${I_PARENT_START_3},
 j_parent_start    =   1,${J_PARENT_START_2},${J_PARENT_START_3},
 e_we              =   ${NL_E_WE_1}, ${NL_E_WE_2}, ${NL_E_WE_3},
 e_sn              =   ${NL_E_SN_1}, ${NL_E_SN_2}, ${NL_E_SN_3},
 geog_data_res     = '${GEOG_DATA_RES_1}','${GEOG_DATA_RES_2}','${GEOG_DATA_RES_3}',
 dx = ${NL_DXY_1},
 dy = ${NL_DXY_1},
 map_proj = '${MAP_PROJ}',
 ref_lat   =  ${REF_LAT},
 ref_lon   =  ${REF_LON},
 truelat1  =  ${TRUELAT1},
 truelat2  =  ${TRUELAT2},
 stand_lon =  ${STAND_LON},
 geog_data_path = '${GEOG_DATA_PATH}'
/

&ungrib
 out_format = 'WPS',
 prefix = 'UPPER',
/

&metgrid
 fg_name = 'UPPER','SFC'
 io_form_metgrid = 2, 
/

EOF

# Run geogrid

if [ ${IMEM} -eq 1 ]; then
   ${RUN_CMD}  ./geogrid.exe
else
   ln -sf ${WPS_ENS_DIR}/e001/geo_em.d0?.nc .
fi
	  
# Run ungrib:
   ln -fs ./ungrib/Variable_Tables/Vtable.GEFS Vtable

   LOCAL_DATE=$INITIAL_DATE
   LAST_DATE=$($BUILD_DIR/da_advance_time.exe ${LOCAL_DATE} -${LBC_ENS_FREQ} -f ccyymmddhhnn 3>/dev/null)
   FILES=''
   FILES1=''
   while [[ $LOCAL_DATE -le $EDATE ]]; do
      export year=`echo  $LOCAL_DATE | cut -c1-4`
      export month=`echo $LOCAL_DATE | cut -c5-6`
      export day=`echo   $LOCAL_DATE | cut -c7-8`
      export hour=`echo  $LOCAL_DATE | cut -c9-10`
      export year1=`echo  $LAST_DATE | cut -c1-4`
      export month1=`echo $LAST_DATE | cut -c5-6`
      export day1=`echo   $LAST_DATE | cut -c7-8`
      export hour1=`echo  $LAST_DATE | cut -c9-10`

      FILES="$FILES $GEFS_DIR/${year}${month}${day}${hour}/gefs.${year}${month}${day}${hour}.${CMEM}"
      if [[ `expr $hour % 6` == 0 ]]; then
         FILES="$FILES $WPS_INPUT_DIR/gdas1.fnl0p25.${year}${month}${day}${hour}.f00.grib2"
      elif [[ `expr $hour % 3` == 0 ]]; then
         FILES="$FILES $WPS_INPUT_DIR/gdas1.fnl0p25.${year1}${month1}${day1}${hour1}.f03.grib2"
      fi
      LAST_DATE=$LOCAL_DATE
      LOCAL_DATE=$($BUILD_DIR/da_advance_time.exe ${LOCAL_DATE} ${LBC_ENS_FREQ} -f ccyymmddhhnn 3>/dev/null)
   done
   # dealing with the common variables from GSFS
   ./link_grib.csh $FILES
   ./ungrib.exe > ungrib.log 2>&1
   
   # dealing with the rest variables in GFS analysis 
   sed -i "s/prefix = 'UPPER'/prefix = 'SFC'/" namelist.wps
   if [ $IMEM -eq 1 ]; then
      ./link_grib.csh $FILES1
       ln -sf ./ungrib/Variable_Tables/Vtable.SFC Vtable
      ./ungrib.exe
   else
      ln -sf ${WPS_ENS_DIR}/e001/SFC* .
   fi
     
# Run metgrid:
   ${RUN_CMD}   ./metgrid.exe
   
if grep -q 'Successful completion of program metgrid.exe' metgrid.log.0000; then
  echo success > SUCCESS
else
  echo fail > FAIL
fi

(( IMEM=IMEM+1 ))

done

date	

exit 0  
