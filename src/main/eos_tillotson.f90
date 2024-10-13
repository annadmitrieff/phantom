!--------------------------------------------------------------------------!
! The Phantom Smoothed Particle Hydrodynamics code, by Daniel Price et al. !
! Copyright (c) 2007-2024 The Authors (see AUTHORS)                        !
! See LICENCE file for usage and distribution conditions                   !
! http://phantomsph.github.io/                                             !
!--------------------------------------------------------------------------!
module eos_tillotson
!
! EoS from Tillotson et al. (1962)
!
! :References: https://apps.dtic.mil/sti/pdfs/AD0486711.pdf
!
! Implementation from Benz and Asphaug (1999)
!
! :Owner:
!
! :Runtime parameters: None
!
! :Dependencies: 
!
 implicit none
 real :: rho0 = 2.7 ! g/cm^3 zero-pressure density (Basalt) from Benz & Asphaug 1999
! aparam, bparam, A, B, energy0 material-dependent Tillotson parameters (Basalt)
 real :: pressure = 0. ! THIS COULD WORK [P] = erg/cm^3 = 1E-5 Pa (1 microbar)
 real :: aparam = 0.5 , bparam = 1.5 , alpha = 5. , beta = 5. 
 real :: A = 2.67e11 , B = 2.67e11 ! erg/cm^3
 real :: u0 = 4.87e12 ! erg/g
 real :: u_iv = 4.72e10 ! erg/g
 real :: u_cv = 1.82e11 ! erg/g
 real :: rho_iv = 2.57 ! g/cm^3 incipient vaporisation density of gabbroic anorthosite lpp from Ahrens and Okeefe (1977) table 1
 real :: rho_cv = 8.47 ! g/cm^3 complete vaporisation density of gabbroic anorthosite lpp from Ahrens and Okeefe (1977) table 2
 private :: rho0, aparam, bparam, A, B, alpha, beta, u0, rho_iv, u_iv, u_cv
!  private :: spsoundmin, spsound2, spsound3, pressure2, pressure3
!  private :: expterm, expterm2, sqrtterm, sqrtterm1, sqrtterm2

contains
!-----------------------------------------------------------------------
!+
!  EoS from Tillotson et al. (1962) ; Implementation from Benz and Asphaug (1999) and Brundage (2013)
!+
!-----------------------------------------------------------------------
subroutine init_eos_tillotson(ierr)
 integer, intent(out) :: ierr

 ierr = 0

end subroutine init_eos_tillotson

subroutine equationofstate_tillotson(rho,u,pressure,spsound,gamma)
 use units, only: unit_density, unit_pressure, unit_ergg
 real, intent(inout) :: rho,u
 real, intent(out) :: pressure, spsound, gamma
 real :: eta, mu_t, neu, omega, spsoundmin, spsound2, spsoundh, spsound2h, spsound3, pressure2, pressure3
 
!  rho = rho*unit_density
!  u = u*unit_ergg

 eta = rho/ rho0
 mu_t = eta - 1.
 neu = (1. / eta) - 1.  ! Kegerreis et al. 2020
 omega = (u / (u0*(eta**2))) + 1.
 spsoundmin = sqrt(A / rho0) ! wave speed estimate Benz and Asphaug
!  gamma = 2./3.

! Brundage 2013 eq (2) cold expanded and compressed states
 pressure2 = (( aparam + ( bparam / omega ) ) * rho*u) + (A*mu_t) + (B*(mu_t**2))
 if (pressure2 <= 0.) then
  pressure2 = 0.
 endif

! Brundage 2013 eq (3) completely vaporised
 pressure3 = (aparam*rho*u) + ( ((bparam*rho*u)/omega) + &
              A*mu_t*exp((-1.*beta)*neu)) * exp((-1.*alpha)*(neu**2))
 if (pressure3 <= 0.) then
  pressure3 = 0.
 endif

! sound speed from Kegereis et al. 2020
 spsound2 = sqrt( ((pressure2 / rho) * (1. + aparam + (bparam / omega ))) + &
            (((bparam*(omega - 1.)) / (omega**2)) * ((2.*u) - (pressure2/rho))) + &
            ((1./rho)*(A + (B*((eta**2) - 1.)))))
 if (spsound2 < spsoundmin) then
  spsound2 = spsoundmin
 endif

 spsound3 = sqrt( ((pressure3/rho)*( 1. + aparam + ((bparam / omega )*exp((-1.*alpha)*(neu**2))))) + &
            (( (((bparam*rho*u)/((omega**2)*(eta**2))) * ((1. /(u0*rho)) * ((2.*u) - (pressure3/rho)) &
            + ((2.*alpha*neu*omega)/rho0))) + ((A/rho0)*(1. + ((mu_t/(eta**2))*((beta+(2.*alpha*neu) - eta))) &
            * exp((-1.*beta)*neu) )))*exp((-1.*alpha)*(neu**2)) ))
 if (spsound3 < spsoundmin) then
  spsound3 = spsoundmin
 endif

 spsound2h = sqrt( ((pressure2 / rho) * (1. + aparam + (bparam / omega ))) + &
            (((bparam*(omega - 1.)) / (omega**2)) * ((2.*u) - (pressure2/rho))) + &
            (A/rho))
 if (spsound2h < spsoundmin) then
    spsound2h = spsoundmin
 endif

 spsoundh = sqrt(( ((u-u_iv)*(spsound3)**2) + ((u_cv-u)*(spsound2)**2) ) / (u_cv - u_iv))
 if (spsoundh < spsoundmin) then
    spsoundh = spsoundmin
 endif
             
 if (rho < rho_iv) then !                low energy expanded = [ISSUES!!]
    pressure = 1.0 ! 1.E-16 GPa [10^7 erg = 1Pa ; Giga = 10^9]
    spsound = spsoundmin
!     pressure = pressure2 - (B*(mu_t**2))
!     print*,' in eos - calc pres from rho and u'
!     print*,' rho in = ',rho,' u in = ',u
!     print*,'in low energy state, p = ',pressure,' pres in code units = ',pressure/unit_pressure
 else ! (rho >= rho_iv)
    if (rho >= rho0) then !              compressed and cold expanded
        pressure = pressure2
        spsound = spsound2
        ! print*,' in eos - calc pres from rho and u'
        ! print*,' rho in = ',rho,' u in = ',u
        ! print*,' spsound = ',spsound
        ! print*,'in compressed state, p = ',pressure,' pres in code units = ',pressure/unit_pressure
    else ! (rho_iv <= rho < rho0)
        if (u < u_cv) then ! (u > u_iv)            hybrid
            pressure = ( (u - u_iv)*pressure3 + (u_cv - u)*pressure2 ) / (u_cv - u_iv)
            spsound = spsoundh
            ! print*,' in eos - calc pres from rho and u'
            ! print*,' rho in = ',rho,' u in = ',u
            ! print*,'in hybrid state, p = ',pressure,' pres in code units = ',pressure/unit_pressure
        else ! if (u >= u_cv) then !            hot / vapourised expanded
            pressure = pressure3
            spsound = spsound3
            ! print*,' in eos - calc pres from rho and u'
            ! print*,' rho in = ',rho,' u in = ',u
            ! print*,' spsound = ',spsound
            ! print*,'in hot expanded state, p = ',pressure,' pres in code units = ',pressure/unit_pressure
        endif
    endif
endif
!  print*,'leaving eos (pres calc) '

end subroutine equationofstate_tillotson

!----------------------------------------------------------------
!+
!  print eos information
!+
!----------------------------------------------------------------
subroutine eos_info_tillotson(iprint)
 integer, intent(in) :: iprint

 write(iprint,"(/,a)") ' Tillotson EoS',pressure

end subroutine eos_info_tillotson

!-----------------------------------------------------------------------
!+
!  calc internal energy from pressure and density
!+
!-----------------------------------------------------------------------
subroutine calc_uT_from_rhoP_tillotson(rho,pres,temp,u,ierr)
 use cubic, only:cubicsolve
 use units, only:unit_density,unit_pressure,unit_ergg
 real, intent(in) :: rho,pres
 real, intent(out) :: temp,u
 integer, intent(out) :: ierr
 real :: eta, mu_t, neu, omega, expterm, expterm2, X, quada, quadb, quadc, pres_iv
 real :: usol(3)
 integer :: nsol
 
!  rho = rho*unit_density
!  pres = pres*unit_pressure

 eta = rho / rho0
 mu_t = eta - 1.
 neu = (1. / eta) - 1.  ! Kegerreis et al. 2020
 omega = (u / (u0*(eta**2)) + 1.)
 expterm2 = exp(-alpha*(neu**2))
 expterm = exp(-beta*neu)

 
 if (rho < rho_iv) then !                low energy expanded = [ISSUES!!]
    quada = 1.          ! min pressure = 1. -> min u
    X = 1. - (A*mu_t)
    quadb = (((u0*(eta**2)*rho)*(aparam + bparam)) - X)/(aparam*rho)
    quadc = -1.*((X*u0*(eta**2))/(rho*aparam))
    call cubicsolve(0.,quada,quadb,quadc,usol,nsol)
    u = maxval(usol(1:nsol))
!     print*,' in eos - calc u from rho and pres'
!     print*,' rho in = ',rho,' pres in = ',pres
!     print*,'in low energy state, u = ',u,' u in code units = ',u/unit_ergg
 else
    if (rho >= rho0) then !              compressed and cold expanded
        quada = 1.
        X = pres - (A*mu_t) - (B*(mu_t**2))
        quadb = (((u0*(eta**2)*rho)*(aparam + bparam)) - X)/(aparam*rho)
        quadc = -1.*((X*u0*(eta**2))/(rho*aparam))
        call cubicsolve(0.,quada,quadb,quadc,usol,nsol)
        u = maxval(usol(1:nsol))
        ! print*,' in eos - calc u from rho and pres'
        ! print*,' rho in = ',rho,' pres in = ',pres
        ! print*,'in compressed state, u = ',u,' u in code units = ',u/unit_ergg
    else ! (rho_iv <= rho < rho0)
    !         if (pres >= pres_cv) then !      hot / vapourised expanded
        quada = 1.
        X = (pres - (A*mu_t*expterm*expterm2))
        quadb = ((aparam*rho*u0*(eta**2)) + (bparam*rho*u0*(eta**2)*expterm2) -X)/(rho*aparam) ! (u0*(eta**2))+((bparam*u0*(eta**2)*expterm2)/aparam) - (X/aparam)
        quadc = -1.*(X*u0*(eta**2))/(aparam*rho) ! -1.*((X*u0*(eta**2))/aparam)
        call cubicsolve(0.,quada,quadb,quadc,usol,nsol)
        u = maxval(usol(1:nsol))
        ! print*,' in eos - calc u from rho and pres'
        ! print*,' rho in = ',rho,' pres in = ',pres
        ! print*,'in hot expanded state, u = ',u,' u in code units = ',u/unit_ergg
    endif
endif
!  print*,'leaving eos (u calc) '
!         else ! (pres < pres_cv)
!             if (pres <= pres_iv) then !      cold expanded
!                 quada = 1.
!                 X = (pres - (A*mu_t) - (B*(mu_t**2)))/rho
!                 quadb = ((-X/aparam)+(u0*(eta**2))+((bparam*u0*(eta**2))/aparam))
!                 quadc = -((u0*(eta**2)*X)/aparam)
!                 call cubicsolve(0.,quada,quadb,quadc,usol,nsol)
!                 u = maxval(usol(1:nsol))    
!                 print*,' in eos - calc u from rho and pres'
!                 print*,' rho in = ',rho,' pres in = ',pres 
!                 print*,'in cold expanded state, u = ',u,' u in code units = ',u/unit_ergg
!             else ! (u > u_iv)            hybrid
!                 ! pressure = ( (u - u_iv)*pressure3 + (u_cv - u)*pressure2 ) / (u_cv - u_iv)
!                 ! spsoundh = sqrt(( ((u-u_iv)*(spsound3)**2) + ((u_cv-u)*(spsound2)**2) ) / (u_cv - u_iv))
!                 ! print*,' in eos - calc u from rho and pres'
!                 ! print*,' rho in = ',rho,' pres in = ',pres 
!                 ! print*,'in hybrid state, u = ',u,' u in code units = ',u/unit_ergg
!             endif
!         endif
!     endif

 temp = 300.
 ierr = 0
 if (u <= 0.) then
    u = 0.
    ierr = 1
 endif
!  print*,' INSIDE EOS: rho ',rho,' pres ',pres,' OUT u ',u

end subroutine calc_uT_from_rhoP_tillotson  

!-----------------------------------------------------------------------
!+
!  reads equation of state options from the input file
!+
!-----------------------------------------------------------------------
 subroutine read_options_eos_tillotson(name,valstring,imatch,igotall,ierr)
  use io, only:fatal
  character(len=*),  intent(in)  :: name,valstring
  logical,           intent(out) :: imatch,igotall
  integer,           intent(out) :: ierr
  integer,           save        :: ngot  = 0
  character(len=30), parameter   :: label = 'eos_tillotson'
 
  imatch  = .true.
  select case(trim(name))
  case('rho0')
      read(valstring,*,iostat=ierr) rho0
      if ((rho0 < 0.)) call fatal(label,'rho0 < 0')
      ngot = ngot + 1
  case('aparam')
      read(valstring,*,iostat=ierr) aparam
      if ((aparam < 0.)) call fatal(label,'aparam < 0')
      ngot = ngot + 1
  case('bparam')
      read(valstring,*,iostat=ierr) bparam
      if ((bparam < 0.)) call fatal(label,'bparam < 0')
      ngot = ngot + 1
  case('A')
      read(valstring,*,iostat=ierr) A
      if ((A < 0.)) call fatal(label,'A < 0')
      ngot = ngot + 1
  case('B')
      read(valstring,*,iostat=ierr) B
      if ((B < 0.)) call fatal(label,'B < 0')
      ngot = ngot + 1
  case('alpha_t')
      read(valstring,*,iostat=ierr) alpha
      if ((alpha < 0.)) call fatal(label,'alpha < 0')
      ngot = ngot + 1
  case('beta_t')
      read(valstring,*,iostat=ierr) beta
      if ((beta < 0.)) call fatal(label,'beta < 0')
      ngot = ngot + 1
  case('u0')
      read(valstring,*,iostat=ierr) u0
      if ((u0 < 0.)) call fatal(label,'u0 < 0')
      ngot = ngot + 1
  case default
     imatch = .false.
  end select
 
  igotall = (ngot >= 8)
 
 end subroutine read_options_eos_tillotson

!-----------------------------------------------------------------------
!+
!  writes equation of state options to the input file
!+
!-----------------------------------------------------------------------
subroutine write_options_eos_tillotson(iunit)
 use infile_utils, only:write_inopt
 integer, intent(in) :: iunit
 
 call write_inopt(rho0,'rho0','reference density g/cm^3',iunit)
 call write_inopt(aparam,'aparam','material-dependent Tillotson parameter, unitless',iunit)
 call write_inopt(bparam,'bparam','material-dependent Tillotson parameter, unitless',iunit)
 call write_inopt(A,'A','material-dependent Tillotson parameter, erg/cm^3',iunit)
 call write_inopt(B,'B','material-dependent Tillotson parameter, erg/cm^3',iunit)
 call write_inopt(alpha,'alpha_t','material-dependent Tillotson parameter, unitless',iunit)
 call write_inopt(beta,'beta_t','material-dependent Tillotson parameter, unitless',iunit)
 call write_inopt(u0,'u0','material-dependent Tillotson parameter, erg/g',iunit)

end subroutine write_options_eos_tillotson

end module eos_tillotson