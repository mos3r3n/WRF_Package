#PBS -N cycle_dart_test
#!/bin/bash

# for hdf5-1.8.9_intel
export PATH=/share/home/zhaokun/yinghui/share/opt/hdf5/hdf5-1.8.9_intel2018u4/bin:$PATH
export LD_LIBRARY_PATH=/share/home/zhaokun/yinghui/share/opt/hdf5/hdf5-1.8.9_intel2018u4/lib:$LD_LIBRARY_PATH
export MANPATH=$MANPATH:/share/home/zhaokun/yinghui/share/opt/hdf5/hdf5-1.8.9_intel2018u4/share

# Set tasks
export lay_out=1
export tasks_per_node=24
export RUN_CMD="mpirun"
export SUMBIT_CMD="bsub"

# CODE direcotory
export  MODEL=/share/home/zhaokun/haiqin/share
export  WRFVAR_DIR=$MODEL/WRFDA-4.5.1
export  BUILD_DIR=$WRFVAR_DIR/var/build
export  WRF_DIR=$MODEL/WRF
export  WPS_DIR=$MODEL/WPS-4.5
export  DART_DIR=$MODEL/DART
export  BLEND_EXE_DIR=$MODEL/BLEND
export  NML_DIR=${SCRIPTS_DIR}/NML

# input data Directories:
export  GEOG_DATA_PATH=/share/home/zhaokun/yinghui/share/WPS_GEOG
export  WPS_INPUT_DIR=/share/home/zhaokun/haiqin/data/fnl
export  GEFS_DIR=/share/home/zhaokun/haiqin/data/GEFS
export  OBS_DIR=/share/home/zhaokun/haiqin/data/conv2
export  RADAR_DIR=/share/home/zhaokun/haiqin/data/radar1hr/202309
export  BE_DIR=/share/home/zhaokun/haiqin/data/be

# output(working) data Directories:
############################################################
export  EXP_DIR=/scratch/zhaokun/haiqin/exp/Haikui/EAKF_CONV
#prepare observations
export  OBS_D01_DIR=${EXP_DIR}/obs_d01
export  OBS_D02_DIR=${EXP_DIR}/obs_d02
#wps & real
export  WPS_RUN_DIR=$EXP_DIR/wps
export  REAL_FC_DIR=$EXP_DIR/real
#related to perturbations (ICBC)
export  WPS_ENS_DIR=$EXP_DIR/ens_wps
export  ICBC_ENS_DIR=$EXP_DIR/ens_icbc
export  RUN_RCV_DIR=$EXP_DIR/ens_rcv
export  RECENTER_DIR=$EXP_DIR/recenter
# wrf-related
export  ENS_WRF_DIR=$EXP_DIR/ens_wrf
# analysis process
export  BLEND_DIR=$EXP_DIR/blending
export  DART_D01_DIR=$EXP_DIR/eakf_d01
export  DART_D02_DIR=$EXP_DIR/eakf_d02
#############################################################

#Time info:                        
export  DE_FCST_RANGE=1
export  SPINUP_TIME=6
export  LBC_FREQ=6      #GFS or FNL inteval 
export  LBC_ENS_FREQ=6
export  OUTPUT_INTERVAL=1
export  IF_BREAK=0
export  SUB_WINDOW1=1h30min 
export  SUB_WINDOW2=30min 
                                      
# Tasks to run: (run if true):        
export WPS_CORE=24
export WPS_WALLTIME=30
export REAL_CORE=24
export REAL_WALLTIME=10
export ENS_WPS_CORE=24
export ENS_WPS_WALLTIME=45
export ENS_REAL_CORE=24
export ENS_REAL_WALLTIME=45
export OBS_CONV_CORE=24
export OBS_CONV_WALLTIME=3
export OBS_RADAR_CORE=24
export OBS_RADAR_WALLTIME=5
export RANDOM_CV_CORE=24
export RANDOM_CV_WALLTIME=45
export RECENTER_CORE=1
export RECENTER_WALLTIME=20
export BLEND_CORE=24
export BLEND_WALLTIME=40
export EAKF_D01_CORE=120
export EAKF_D01_WALLTIME=20
export EAKF_D02_CORE=240
export EAKF_D02_WALLTIME=45
export WRF_CORE=120
export WRF_WALLTIME=15

# Domain:
export  MAP_PROJ=lambert
export  REF_LAT=22.0
export  REF_LON=112.0
export  TRUELAT1=22.0
export  TRUELAT2=22.0
export  STAND_LON=112.0
export  NL_TIME_STEP=45
export  NL_E_VERT=51
export  NL_P_TOP_REQUESTED=5000
export  NL_NUM_METGRID_LEVELS=34
export  FEEDBACK=1

#DOMAIN for NEST
export  MAX_DOM=2
export  PARENT_GRID_RATIO_1=1;     export PARENT_GRID_RATIO_2=3;      export PARENT_GRID_RATIO_3=3
export  NL_E_WE_1=400;             export NL_E_WE_2=601;              export NL_E_WE_3=210
export  NL_E_SN_1=300;             export NL_E_SN_2=502;              export NL_E_SN_3=150  	
export  I_PARENT_START_1=1;        export I_PARENT_START_2=119;       export I_PARENT_START_3=62
export  J_PARENT_START_1=1;        export J_PARENT_START_2=58;       export J_PARENT_START_3=26
export  GEOG_DATA_RES_1=1m;        export GEOG_DATA_RES_2=30s;        export GEOG_DATA_RES_3=30s
export  NL_DXY_1=9000;             export NL_DXY_2=3000;              export NL_DXY_3=1000
export  INPUT_FROM_FILE_1=.true.;  export INPUT_FROM_FILE_2=.true.;  export INPUT_FROM_FILE_3=.false.
export  NL_ETA_LEVELS=${NL_ETA_LEVELS:-1.0000, 0.9980, 0.9940, 0.9870, 0.9750, 0.9590, \
                                 0.9390, 0.9160, 0.8920, 0.8650, 0.8350, 0.8020, 0.7660, \
                                 0.7270, 0.6850, 0.6400, 0.5920, 0.5420, 0.4970, 0.4565, \
                                 0.4205, 0.3877, 0.3582, 0.3317, 0.3078, 0.2863, 0.2670, \
                                 0.2496, 0.2329, 0.2188, 0.2047, 0.1906, 0.1765, 0.1624, \
                                 0.1483, 0.1342, 0.1201, 0.1060, 0.0919, 0.0778, 0.0657, \
                                 0.0568, 0.0486, 0.0409, 0.0337, 0.0271, 0.0209, 0.0151, \
                                 0.0097, 0.0047, 0.0000}

#physics					   
export NL_MP_PHYSICS=8 # 2 for Lin
export NL_RA_LW=4
export NL_RA_SW=4
export NL_RADT1=15; export NL_RADT2=3
export NL_SF_SFCLAY_PHYSICS=2
export NL_SF_SURFACE_PHYSICS=2 # 2 for CWB, 1 for Korea
export NL_BL_PBL_PHYSICS=2
export NL_BLDT=0
export NL_CU_PHYSICS1=1; export NL_CU_PHYSICS2=0
export NL_CUDT1=5; export NL_CUDT2=0
export NL_NUM_SOIL_LAYERS=4
export NL_NUM_LAND_CAT=21

##############################################################################################################################
# For
export SKEB=1
export PERT_BDY=1
# For Ensemble 
export MULTI_NUM=4
#export INI_ENS=31
#export END_ENS=40
export INITIAL_CORRECT=false
export ASSIM_RADAR=TRUE
export USE_GEFS=false
export NUM_MEMBERS=40
export NUM_GEFS=40
export MAX_ERROR=5
export VAR_DART=${VAR_DART:-"U,V,W,PH,T,MU,QVAPOR,U10,V10,T2,Q2,PSFC"}
export VAR_RADAR=${RADAR_DART:-"U,V,W,PH,T,MU,QVAPOR,U10,V10,T2,Q2,PSFC,QCLOUD,QICE,QRAIN,QSNOW,QGRAUP,REFL_10CM,VT_DBZ_WT"}
#export VAR_RADAR=${RADAR_DART:-"U,V,W,PH,T,MU,QVAPOR,U10,V10,T2,Q2,PSFC"}
