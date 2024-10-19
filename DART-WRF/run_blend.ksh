#!/bin/ksh

date

IMEM=1
while (( IMEM <= ${NUM_MEMBERS} )) ; do

if [[ $IMEM -lt 100 ]]; then export CMEM=e0$IMEM;  fi
if [[ $IMEM -lt 10  ]]; then export CMEM=e00$IMEM; fi

if [[ ! -d $WORK_DIR/$CMEM ]]; then mkdir -p $WORK_DIR/$CMEM; fi
cd $WORK_DIR/$CMEM

ln -sf ${REAL_FC_DIR}/${DATE}/wrfinput_d01 gm_t0.nc
ln -sf ${REAL_FC_DIR}/${DATE}/wrfinput_d01 gm_t1.nc
ln -sf ${ENS_WRF_DIR}/${PREV_DATE}/$CMEM/wrfout_d01_${FILE_DATE} lam.nc
ln -sf ${BLEND_EXE_DIR}/code/warm.exe .
cp ${BLEND_EXE_DIR}/output/gm_bias.GFS.15kmMIDUS.asc ./gm_bias.GFS.asc

if [ `expr ${HH} % 6` == "0" ]; then
   export ISAUTOKCLC=.True.
elif [ `expr ${HH} % 3` == "0" ] ; then
   export BLD_PREV_DATE=$($BUILD_DIR/da_advance_time.exe $DATE -3h -f ccyymmddhhnn 2>/dev/null)
   if [ -e ${BLEND_DIR}/${BLD_PREV_DATE}/$CMEM/FIXED.asc ]; then
      ln -sf ${BLEND_DIR}/${BLD_PREV_DATE}/$CMEM/FIXED.asc FIXED.asc
      export ISAUTOKCLC=.False.
   else
      export ISAUTOKCLC=.True.
   fi
fi

cat > warm.nml << EOF
&warm_domain
  Nx  = ${NL_E_WE_1} 
  Ny  = ${NL_E_SN_1},
  Nl  = ${NL_E_VERT},
  dx  = ${NL_DXY_1},
  dy  = ${NL_DXY_1},
  dbp = 20,
/
&warm_wavenumber
  gmbiaspath    = 'gm_bias.GFS.asc',
  kclcpath      = 'FIXED.asc',
  isAutoKclc    = ${ISAUTOKCLC},
  radioScale    = 388000.,
  isHardAcc     = .False.,
  isAdptiveKm   = .False.,
  biasM         = 7.0,
  biasC         = 7.0,
  isVertSmooth  = .True.
  update_kc_min = 180.,
  gmRes_x       = 21296.,
  gmRes_y       = 27800.,
  gmEffDelta    = 6,
/
&warm_blending
  gm0path       = 'gm_t0.nc',
  gm1path       = 'gm_t1.nc',
  lampath       = 'lam.nc',
  bldpath       = 'wrfinput_d01',
  cvName        = 'U','V','T','PH','P','QVAPOR','W','U10','V10','T2','TH2','MU','Q2','PSFC',
  Ncv           = 7,
  isHardCut     = .False.,
  gm_int_min    = 180.,
  blend_int_min = 180.,
  run_pass_min  = 0.,
/
&warm_gmbias
  gm_ana_dir    = './gm_ana',
  gm_fcs_dir    = './gm_fcs',
  isSmoothBiasm = .False.,
  isHardBiasm   = .False.,
/
&warm_debug
  isDoLS_gm  = .True.,
  isDoLS_lm  = .False.,
  isDoLS_bld = .False.,
  dbg_Lx     = 1000000.,
  dbg_Ly     = 1000000.,
  ls_gmpath  = 'ls_gm0.nc',
  ls_lmpath  = 'ls_lam.nc',
  ls_bldpath = 'ls_bld.nc',
/
EOF

# run blending 
./warm.exe

let IMEM=$IMEM+1

done

exit 0


