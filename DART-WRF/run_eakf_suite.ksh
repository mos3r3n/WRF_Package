#!/bin/ksh -x

set echo

echo $(date) "Start"

export DATE=$INITIAL_DATE

RC=0

while [[ $DATE -le $FINAL_DATE ]]; do 

# Decide whether to assimilate RADAR
if [ $DATE -ge $RADAR_START_DATE  ]; then
   let RADAR_NUMBER=$RADAR_NUMBER+1
fi
  
echo ${RADAR_NUMBER}

# Decide on length of forecast to run
if [ "${CYCLE_NUMBER}" -eq "0" ]; then
    export FCST_RANGE=${SPINUP_TIME}
    export FCST_MINUTE=0
elif [ "${CYCLE_NUMBER}" -gt "0" ] && [ "${RADAR_NUMBER}" -eq "0" ]; then
    export FCST_RANGE=${CYCLE_PERIOD} 
    export FCST_MINUTE=0
elif [ "${RADAR_NUMBER}" -gt "0" ] && [ $DATE -lt $FINAL_DATE ]; then
    export FCST_RANGE=0
    export FCST_MINUTE=${CYCLE_RADAR}
fi
if [ "${IF_BREAK}" -eq "0" ] && [ $DATE -eq $FINAL_DATE ]; then  # LAST CYCLE
    export FCST_RANGE=${DE_FCST_RANGE}
    export FCST_MINUTE=0
fi

echo "FCST_RANGE = "$FCST_RANGE
echo "FCST_MINUTE = "$FCST_MINUTE

if [ "${CYCLE_NUMBER}" -eq "1" ]; then
   export PREV_DATE=$($BUILD_DIR/da_advance_time.exe $DATE -${SPINUP_TIME}h -f ccyymmddhhnn 2>/dev/null)
elif [ ${CYCLE_NUMBER} -gt 1 ] && [ ${RADAR_NUMBER} -le 1 ]; then
   export PREV_DATE=$($BUILD_DIR/da_advance_time.exe $DATE -${CYCLE_PERIOD}h -f ccyymmddhhnn 2>/dev/null)
elif [ ${RADAR_NUMBER} -gt 1 ]; then
   export PREV_DATE=$($BUILD_DIR/da_advance_time.exe $DATE -${CYCLE_RADAR}m -f ccyymmddhhnn 2>/dev/null)
fi

export FWD_DATE=$($BUILD_DIR/da_advance_time.exe $DATE ${FCST_RANGE}h${FCST_MINUTE}m -f ccyymmddhhnn 2>/dev/null)
 
echo "============"
echo    $PREV_DATE
echo     $DATE
echo    $FWD_DATE
echo "============"
  
export YYYY=$(echo $DATE | cut -c1-4)
export MM=$(echo $DATE | cut -c5-6)
export DD=$(echo $DATE | cut -c7-8)
export HH=$(echo $DATE | cut -c9-10)
export MN=$(echo $DATE | cut -c11-12)
export YYYY1=$(echo $FWD_DATE | cut -c1-4)
export MM1=$(echo $FWD_DATE | cut -c5-6)
export DD1=$(echo $FWD_DATE | cut -c7-8)
export HH1=$(echo $FWD_DATE | cut -c9-10)
export MN1=$(echo $FWD_DATE | cut -c11-12)
export FILE_DATE=${YYYY}-${MM}-${DD}_${HH}:${MN}:00

#--------------------------------------------------------------------------------
# [1] Run WPS
#--------------------------------------------------------------------------------

if  $RUN_WPS && [ "$CYCLE_NUMBER" -eq "0" ]; then

     export WORK_DIR=${WPS_RUN_DIR}
     if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
     cd $WORK_DIR

     $SCRIPTS_DIR/run_wps.ksh > wps_run.log 2>&1

     RC=$?
     if [[ $RC != 0 ]]; then
         echo $(date) "${ERR}wps failed with error $RC$END"
         echo wps > FAIL
         break
     fi

fi

if  $RUN_ENS_WPS && [ "$CYCLE_NUMBER" -eq "0" ]; then

     export WORK_DIR=${WPS_ENS_DIR}
     if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
     cd $WORK_DIR

     $SCRIPTS_DIR/run_wps_ens.ksh > wps_ens_run.log 2>&1

     RC=$?
     if [[ $RC != 0 ]]; then
         echo $(date) "${ERR}wps failed with error $RC$END"
         echo wps > FAIL
         break
     fi

fi

 
#--------------------------------------------------------------------------------
# [2] REAL-FC 
#--------------------------------------------------------------------------------
   
if  $RUN_REAL_FC && [ "$CYCLE_NUMBER" -ge "0" ] && [ "${MN}" -eq "00" ]; then  
   
     export WORK_DIR=$REAL_FC_DIR/${DATE}
     if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
     cd $WORK_DIR

     $SCRIPTS_DIR/run_real.ksh > real_fc.log 2>&1 

     RC=$?
     if [[ $RC != 0 ]]; then
         echo $(date) "${ERR}real failed with error $RC$END"
         echo wrf > FAIL
         break 
     fi	    

fi  
 
if  $RUN_ENS_ICBC && [ "$CYCLE_NUMBER" -eq "0" ]; then

     export WORK_DIR=${ICBC_ENS_DIR}/${DATE}
     if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
     cd $WORK_DIR

     $SCRIPTS_DIR/run_icbc_ens.ksh > icbc_ens_run.log 2>&1

     RC=$?
     if [[ $RC != 0 ]]; then
         echo $(date) "${ERR}wps failed with error $RC$END"
         echo wps > FAIL
         break
     fi

fi
#-----------------------------------------------------------------------
# [3] OBSPROC
#-----------------------------------------------------------------------
 
if $RUN_OBS_D01 && [ $CYCLE_NUMBER -ge 1 ] && [ "${MN}" -eq "00" ]; then
   
   export WORK_DIR=${OBS_D01_DIR}/${DATE}
   if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
   cd $WORK_DIR
   
   $SCRIPTS_DIR/run_obs_d01.ksh > obs_d01.log 2>&1 
   
      RC=$?
      if [[ $RC != 0 ]]; then
           echo `date` "${ERR}obsproc Failed with error $RC$END"
           echo hybrid > FAIL
           exit 1	   
      fi

fi 

if $RUN_OBS_D02 && [ ${RADAR_NUMBER} -ge 1 ]; then
   
   export WORK_DIR=${OBS_D02_DIR}/${DATE}
   if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
   cd $WORK_DIR
   
   $SCRIPTS_DIR/run_obs_d02.ksh > obs_d02.log 2>&1 
   
      RC=$?
      if [[ $RC != 0 ]]; then
           echo `date` "${ERR}obsproc Failed with error $RC$END"
           echo hybrid > FAIL
           exit 1	   
      fi

fi 

#--------------------------------------------------------------------------------
# [4] RANDOM-CV: Generate Initial Ensembles
#--------------------------------------------------------------------------------
if $RUN_RCV && [ "$CYCLE_NUMBER" -eq "0" ]; then

      export WORK_DIR=${RUN_RCV_DIR}/$DATE
      if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
      cd $WORK_DIR

      $SCRIPTS_DIR/run_var_rcv.ksh > ens_rcv.log 2>&1

      RC=$?
      if [[ $? != 0 ]]; then
            echo $(date) "${ERR}run_rcv failed with error $RC$END"
            echo etkf > FAIL
            break
      fi

fi

#-----------------------------------------------------------------------
# [5] Run BLENDING
#-----------------------------------------------------------------------

if $RUN_BLEND && [ "$CYCLE_NUMBER" -ge "1" ] && [ "${MN}" -eq "00" ] && [ `expr ${HH} % ${CYCLE_PERIOD}` == 0 ]; then

   export WORK_DIR=${BLEND_DIR}/${DATE}
   if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
   cd $WORK_DIR

   $SCRIPTS_DIR/run_blend.ksh > blend.log 2>&1
   RC=$?

      if [[ $? != 0 ]]; then
            echo $(date) "${ERR}run_blend failed with error $RC$END"
            echo blend > FAIL
            break 2
      fi

fi

#-----------------------------------------------------------------------
# [6] Run DART (Ensemble Adaptive Kalman Filter):
#-----------------------------------------------------------------------

if $RUN_DART_D01 && [ "$CYCLE_NUMBER" -ge "1" ] && [ "${MN}" -eq "00" ] && [ `expr ${HH} % ${CYCLE_PERIOD}` == 0 ]; then

   export WORK_DIR=${DART_D01_DIR}/${DATE}
   if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
   cd $WORK_DIR

   $SCRIPTS_DIR/run_dart_d01.ksh > dart_d01.log 2>&1
   RC=$?
   
      if [[ $? != 0 ]]; then
            echo $(date) "${ERR}run_etkf failed with error $RC$END"
            echo etkf > FAIL
            break 2
      fi 

fi

if $RUN_DART_D02 && [ "$RADAR_NUMBER" -ge "1" ]; then

   export WORK_DIR=${DART_D02_DIR}/${DATE}
   if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
   cd $WORK_DIR

   $SCRIPTS_DIR/run_dart_d02.ksh > dart_d02.log 2>&1
   RC=$?

      if [[ $? != 0 ]]; then
            echo $(date) "${ERR}run_etkf failed with error $RC$END"
            echo etkf > FAIL
            break 2
      fi

fi

#--------------------------------------------------------------------------------
# [7] Cycling-mode: Short Range (upto next cycle hour) Ensembles WRF
#--------------------------------------------------------------------------------

if  $RUN_ENS_WRF; then  
   
     export WORK_DIR=${ENS_WRF_DIR}/${DATE}
     if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
     cd $WORK_DIR
	 
     $SCRIPTS_DIR/run_wrf_ens.ksh > wrf_ens.log 2>&1 

     RC=$?
     if [[ $RC != 0 ]]; then
         echo $(date) "${ERR}wrf failed with error $RC$END"
         echo wrf > FAIL
         break 
     fi	    

fi  

#--------------------------------------------------------------------------------
#  Next cycle....
#--------------------------------------------------------------------------------  
   export DATE=${FWD_DATE}
    
   let CYCLE_NUMBER=$CYCLE_NUMBER+1   

done

echo $(date) "Finished"

if [[ $RC == 0 ]]; then
      touch SUCCESS
fi

exit $RC 
