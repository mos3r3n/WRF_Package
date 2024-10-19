; variables
num_ens = 40
nvar = 5
variables = (/"U","V","PH","T","QVAPOR"/)

do ivar=1, nvar
  variable=variables(ivar-1)
  ; GFS
  f=addfile("wrfinput_d01","r")
  var=f->$variable$
  dim=dimsizes(var)

  ; GEFS ensemble
  var_ens=new((/dim(0),dim(1),dim(2),dim(3),num_ens/),"float")
  do iens=1, num_ens
     if (iens .lt. 10) then
       imem = "e00"+iens
     else
       imem = "e0"+iens
     end if
     ff=addfile("wrfinput_d01."+imem,"r")
     var_ens(:,:,:,:,iens-1) = ff->$variable$
  end do

  ; GEFS ensemble mean
  var_mean=dim_avg_n_Wrap(var_ens,4)

  ; recenter
  do iens=1, num_ens
     var_ens(:,:,:,:,iens-1) = var_ens(:,:,:,:,iens-1) - var_mean + var
     if (iens .lt. 10) then
       imem = "e00"+iens
     else
       imem = "e0"+iens
     end if
     ff=addfile(imem+"/wrfvar_output","w")
     ff->$variable$ = var_ens(:,:,:,:,iens-1)
  end do

  delete(var)
  delete(var_mean)
  delete(var_ens)
  print("Finish variable: "+variable)
  
end do

print("Successfully recentering all members!")
