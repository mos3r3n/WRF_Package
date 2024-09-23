#!/bin/ksh -x

# Experimental configuration
export SCRIPTS_DIR=/share/home/zhaokun/haiqin/scripts/CYCLE_EAKF/Parallel
export WRAPPER_FILE='wrapper_conv_haikui.ksh' 
source ${SCRIPTS_DIR}/${WRAPPER_FILE}

# Set time
export  INITIAL_DATE=202309061600
export  FINAL_DATE=202309070000
export  RADAR_START_DATE=202309060600
export  CYCLE_PERIOD=3  #forecaast range in cycle/en-forecast
export  CYCLE_RADAR=60  #frequency of radar assimilation (min) 
export  CYCLE_NUMBER=3
export  RADAR_NUMBER=1

# Set job (run if true)
export  RUN_WPS=false
export  RUN_ENS_WPS=false
export  RUN_REAL_FC=false
export  RUN_ENS_ICBC=false
export  RUN_OBS_D01=false
export  RUN_OBS_D02=false
export  RUN_RCV=false
export  RUN_RECENTER=false
export  RUN_BLEND=false
export  RUN_DART_D01=true
export  RUN_DART_D02=true
export  RUN_ENS_WRF=true

################################################################################
## DON'T CHANGE THE FOLLOWING FLOWS UNLESS YOU ARE VERY FAMILAR WITH THEM !!! ##
################################################################################

echo $(date) "Start"

export DATE=$($BUILD_DIR/da_advance_time.exe $INITIAL_DATE +0h -f ccyymmddhhnn 2>/dev/null)

while [[ $DATE -le $FINAL_DATE ]]; do 

# Decide whether to assimilate RADAR
if [ $DATE -ge $RADAR_START_DATE  ]; then
   let RADAR_NUMBER=$RADAR_NUMBER+1
fi

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

if [ $DATE -eq $FINAL_DATE ]; then  # LAST CYCLE
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

echo "Run WPS at ${DATE}"
export WORK_DIR=${WPS_RUN_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J wps_${DATE}
#BSUB -n ${WPS_CORE}
#BSUB -o ${WORK_DIR}/wps_${DATE}.out
#BSUB -e ${WORK_DIR}/wps_${DATE}.err
#BSUB -W ${WPS_WALLTIME}

cd $WORK_DIR
source ${SCRIPTS_DIR}/${WRAPPER_FILE}

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_wps.ksh > run_wps_${DATE}.ksh
chmod 744 run_wps_${DATE}.ksh
${SUMBIT_CMD} < run_wps_${DATE}.ksh 

# Check result
for i in {1..40}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60  
done

fi

#--------------------------------------------------------------------------------
# [2] Run Ensemble WPS
#--------------------------------------------------------------------------------
if  $RUN_ENS_WPS && [ "$CYCLE_NUMBER" -eq "0" ]; then

echo "Run Ensemble WPS for ${DATE}"
export WORK_DIR=${WPS_ENS_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J wps_${DATE}
#BSUB -n ${ENS_WPS_CORE}
#BSUB -o ${WORK_DIR}/wps_ens_${DATE}.out
#BSUB -e ${WORK_DIR}/wps_ens_${DATE}.err
#BSUB -W ${ENS_WPS_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_wps_ens.ksh > run_wps_ens_${DATE}.ksh
chmod 744 run_wps_ens_${DATE}.ksh
${SUMBIT_CMD} < run_wps_ens_${DATE}.ksh

# Check result
for i in {1..40}; do
   i_num=0
   for IMEM in {1..${NUM_MEMBERS}}; do
      CMEM=e`printf %3.3i $IMEM`
      if [ -e ${WORK_DIR}/${CMEM}/SUCCESS ]; then
         let i_num=$i_num+1
      fi
      if [ -e ${WORK_DIR}/${CMEM}/FAIL ]; then
         exit
      fi
   done
   if [ ${i_num} -eq ${NUM_MEMBERS} ]; then
     break
   fi
   sleep 180
   if [ i -eq 120 ]; then exit; fi
done

fi

 
#--------------------------------------------------------------------------------
# [3] REAL-FC 
#--------------------------------------------------------------------------------
   
if  $RUN_REAL_FC && [ "$CYCLE_NUMBER" -ge "0" ] && [ "${MN}" -eq "00" ] && [ `expr ${HH} % ${CYCLE_PERIOD}` == 0 ]; then  

echo "Run REAL for ${DATE}"
export WORK_DIR=${REAL_FC_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J real_${DATE}
#BSUB -n ${REAL_CORE}
#BSUB -o ${WORK_DIR}/real_${DATE}.out
#BSUB -e ${WORK_DIR}/wps_ens_${DATE}.err
#BSUB -W ${REAL_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_real.ksh > run_real_${DATE}.ksh
chmod 744 run_real_${DATE}.ksh
${SUMBIT_CMD} < run_real_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60  
done

fi

#--------------------------------------------------------------------------------
# [4] Enemble IC & BC 
#--------------------------------------------------------------------------------
 
if  $RUN_ENS_ICBC && [ "$CYCLE_NUMBER" -eq "0" ]; then

echo "Run Ensemble REAL for ${DATE}"
export WORK_DIR=${ICBC_ENS_DIR}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm */SUCESS */FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J ens_real_${DATE}
#BSUB -n ${ENS_REAL_CORE}
#BSUB -o ${WORK_DIR}/ens_real_${DATE}.out
#BSUB -e ${WORK_DIR}/ens_real_${DATE}.err
#BSUB -W ${ENS_REAL_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_icbc_ens.ksh > run_icbc_ens_${DATE}.ksh
chmod 744 run_icbc_ens_${DATE}.ksh
${SUMBIT_CMD} < run_icbc_ens_${DATE}.ksh

# Check result
for i in {1..40}; do
   i_num=0
   for IMEM in {1..${NUM_MEMBERS}}; do
      CMEM=e`printf %3.3i $IMEM`
      if [ -e ${WORK_DIR}/${CMEM}/SUCCESS ]; then
         let i_num=$i_num+1
      fi
      if [ -e ${WORK_DIR}/${CMEM}/FAIL ]; then
         exit
      fi
   done
   if [ ${i_num} -eq ${NUM_MEMBERS} ]; then
     break
   fi
   sleep 180
   if [ i -eq 120 ]; then exit; fi
done

fi

#--------------------------------------------------------------------------------
# [7] RANDOM-CV: Generate Initial Ensembles
#--------------------------------------------------------------------------------
if $RUN_RCV && [ "$CYCLE_NUMBER" -eq "0" ]; then

echo "Run random cv for ${DATE}"
export WORK_DIR=${RUN_RCV_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J random_cv_${DATE}
#BSUB -n ${RANDOM_CV_CORE}
#BSUB -o ${WORK_DIR}/random_cv_${DATE}.out
#BSUB -e ${WORK_DIR}/random_cv_${DATE}.err
#BSUB -W ${RANDOM_CV_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_var_rcv.ksh > run_var_rcv_${DATE}.ksh
chmod 744 run_var_rcv_${DATE}.ksh
${SUMBIT_CMD} < run_var_rcv_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60
   if [ i -eq 120 ]; then exit; fi   
done

fi

#--------------------------------------------------------------------------------
# [7] Recenter: Generate Initial Ensembles
#--------------------------------------------------------------------------------
if $RUN_RECENTER && [ "$CYCLE_NUMBER" -eq "0" ]; then

echo "Run icbc recenter for ${DATE}"
export WORK_DIR=${RECENTER_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q serial
#BSUB -J random_cv_${DATE}
#BSUB -n ${RECENTER_CORE}
#BSUB -o ${WORK_DIR}/random_cv_${DATE}.out
#BSUB -e ${WORK_DIR}/random_cv_${DATE}.err
#BSUB -W ${RECENTER_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_icbc_recenter.ksh > run_icbc_recenter_${DATE}.ksh
chmod 744 run_icbc_recenter_${DATE}.ksh
${SUMBIT_CMD} < run_icbc_recenter_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60
   if [ i -eq 120 ]; then exit; fi   
done

fi

#-----------------------------------------------------------------------
# [5] OBSPROC D01
#-----------------------------------------------------------------------
 
if $RUN_OBS_D01 && [ $CYCLE_NUMBER -ge 1 ] && [ "${MN}" -eq "00" ] && [ `expr ${HH} % ${CYCLE_PERIOD}` == 0 ]; then
   
echo "Run obsproc in D01 for ${DATE}"
export WORK_DIR=${OBS_D01_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J obs_d01_${DATE}
#BSUB -n ${OBS_CONV_CORE}
#BSUB -o ${WORK_DIR}/obs_d01_${DATE}.out
#BSUB -e ${WORK_DIR}/obs_d01_${DATE}.err
#BSUB -W ${OBS_CONV_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_obs_d01.ksh > run_obs_d01_${DATE}.ksh
chmod 744 run_obs_d01_${DATE}.ksh
${SUMBIT_CMD} < run_obs_d01_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60  
done

fi

#-----------------------------------------------------------------------
# [6] OBSPROC D02
#----------------------------------------------------------------------- 

if $RUN_OBS_D02 && [ ${RADAR_NUMBER} -ge 1 ]; then
   
echo "Run obsproc in D02 for ${DATE}"
export WORK_DIR=${OBS_D02_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J obs_d02_${DATE}
#BSUB -n ${OBS_RADAR_CORE}
#BSUB -o ${WORK_DIR}/obs_d02_${DATE}.out
#BSUB -e ${WORK_DIR}/obs_d02_${DATE}.err
#BSUB -W ${OBS_RADAR_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_obs_d02.ksh > run_obs_d02_${DATE}.ksh
chmod 744 run_obs_d02_${DATE}.ksh
${SUMBIT_CMD} < run_obs_d02_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60  
   if [ i -eq 120 ]; then exit; fi
done

fi 

#-----------------------------------------------------------------------
# [5] Run BLENDING
#-----------------------------------------------------------------------

if $RUN_BLEND && [ "$CYCLE_NUMBER" -ge "1" ] && [ "${MN}" -eq "00" ] && [ `expr ${HH} % ${CYCLE_PERIOD}` == 0 ]; then

echo "Run blending for ${DATE}"
export WORK_DIR=${BLEND_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J blending_${DATE}
#BSUB -n ${BLEND_CORE}
#BSUB -o ${WORK_DIR}/blending_${DATE}.out
#BSUB -e ${WORK_DIR}/blending_${DATE}.err
#BSUB -W ${BLEND_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_blend.ksh > run_blend_${DATE}.ksh
chmod 744 run_blend_${DATE}.ksh
${SUMBIT_CMD} < run_blend_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60
   if [ i -eq 120 ]; then exit; fi   
done

fi

#-----------------------------------------------------------------------
# [6] Run DART (Ensemble Adaptive Kalman Filter):
#-----------------------------------------------------------------------

if $RUN_DART_D01 && [ "$CYCLE_NUMBER" -ge "1" ] && [ "${MN}" -eq "00" ] && [ `expr ${HH} % ${CYCLE_PERIOD}` == 0 ]; then

echo "Run EAKF in D01 for ${DATE}"
export WORK_DIR=${DART_D01_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J eakf_d01_${DATE}
#BSUB -n ${EAKF_D01_CORE}
#BSUB -o ${WORK_DIR}/eakf_d01_${DATE}.out
#BSUB -e ${WORK_DIR}/eakf_d01_${DATE}.err
#BSUB -W ${EAKF_D01_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_dart_d01.ksh > run_dart_d01_${DATE}.ksh
chmod 744 run_dart_d01_${DATE}.ksh
${SUMBIT_CMD} < run_dart_d01_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60
   if [ i -eq 120 ]; then exit; fi   
done
   
fi

if $RUN_DART_D02 && [ "$RADAR_NUMBER" -ge "1" ]; then

echo "Run EAKF in D02 for ${DATE}"
export WORK_DIR=${DART_D02_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm SUCESS FAIL job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J eakf_d02_${DATE}
#BSUB -n ${EAKF_D02_CORE}
#BSUB -o ${WORK_DIR}/eakf_d02_${DATE}.out
#BSUB -e ${WORK_DIR}/eakf_d02_${DATE}.err
#BSUB -W ${EAKF_D02_WALLTIME}

cd $WORK_DIR

EOF

# Sumbit job
cat job.head $SCRIPTS_DIR/run_dart_d02.ksh > run_dart_d02_${DATE}.ksh
chmod 744 run_dart_d02_${DATE}.ksh
${SUMBIT_CMD} < run_dart_d02_${DATE}.ksh

# Check result
for i in {1..120}; do
   if [ -e $WORK_DIR/SUCCESS ]; then
     break
   elif [ -e $WORK_DIR/FAIL ]; then
     exit
   fi
   sleep 60
   if [ i -eq 120 ]; then exit; fi   
done

fi

#--------------------------------------------------------------------------------
# [7] Cycling-mode: Short Range (upto next cycle hour) Ensembles WRF
#--------------------------------------------------------------------------------

if  $RUN_ENS_WRF; then

if [ ${FCST_RANGE} -gt 0 ]; then
  export ENS_WRF_WALLTIME=`expr ${WRF_WALLTIME} \* ${FCST_RANGE} \* ${MULTI_NUM}`
else
  export ENS_WRF_WALLTIME=`expr ${WRF_WALLTIME} \* ${MULTI_NUM}`
fi
# Calculate how many jobs are needed
export NUM_JOBS=`expr ${NUM_MEMBERS} / ${MULTI_NUM}`
if [ `expr ${NUM_MEMBERS} % ${MULTI_MEMBER}` -ne 0 ]; then
  let NUM_JOBS=${NUM_JOBS}+1
fi

echo "Run Ensemble forecast for ${DATE}"
export WORK_DIR=${ENS_WRF_DIR}/${DATE}
if [[ ! -d $WORK_DIR ]]; then mkdir -p $WORK_DIR; fi
cd $WORK_DIR
rm */SUCCESS */FAIL 

# Sumbit multiple jobs for ensemble forecast
I_JOB=1
while [ $I_JOB -le ${NUM_JOBS} ]; do
   
export END_ENS=`expr $MULTI_NUM \* ${I_JOB}`
export INI_ENS=`expr $END_ENS - $MULTI_NUM + 1`
if [ ${END_ENS} -gt ${NUM_MEMBERS} ] ; then 
   export END_ENS=${NUM_MEMBERS}
fi
rm job.head

# Job header
cat > job.head << EOF
#!/bin/ksh
#BSUB -q mpi
#BSUB -J ens_wrf_${DATE}_${INI_ENS}to${END_ENS}
#BSUB -n ${WRF_CORE}
#BSUB -o ${WORK_DIR}/ens_wrf_${DATE}_${INI_ENS}to${END_ENS}.out
#BSUB -e ${WORK_DIR}/ens_wrf_${DATE}_${INI_ENS}to${END_ENS}.err
#BSUB -W ${ENS_WRF_WALLTIME}

cd $WORK_DIR

EOF
# Sumbit job
cat job.head $SCRIPTS_DIR/run_wrf_ens.ksh > run_wrf_ens_${DATE}_${INI_ENS}to${END_ENS}.ksh
chmod 744 run_wrf_ens_${DATE}_${INI_ENS}to${END_ENS}.ksh
${SUMBIT_CMD} < run_wrf_ens_${DATE}_${INI_ENS}to${END_ENS}.ksh    

let I_JOB=${I_JOB}+1

done
## Check wrfout results
for i in {1..120}; do
   i_num=0
   for IMEM in {1..${NUM_MEMBERS}}; do
      CMEM=e`printf %3.3i $IMEM`
      if [ -e ${WORK_DIR}/${CMEM}/SUCCESS ]; then
         let i_num=$i_num+1
      fi
      if [ -e ${WORK_DIR}/${CMEM}/FAIL ]; then
         exit # chq: need a better solution. like subimt a new run_wrf_ens_${DATE}_${INI_ENS}to${END_ENS}.ksh
      fi	  
   done
   if [ ${i_num} -eq ${NUM_MEMBERS} ]; then
	   break
   fi
   sleep 180
   if [ i -eq 120 ]; then exit; fi   
done   

fi  

#--------------------------------------------------------------------------------
#  Next cycle....
#--------------------------------------------------------------------------------  
   export DATE=${FWD_DATE}
    
   let CYCLE_NUMBER=$CYCLE_NUMBER+1   

done

echo $(date) "Finished"

exit 0
