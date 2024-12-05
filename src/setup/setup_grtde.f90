!--------------------------------------------------------------------------!
! The Phantom Smoothed Particle Hydrodynamics code, by Daniel Price et al. !
! Copyright (c) 2007-2024 The Authors (see AUTHORS)                        !
! See LICENCE file for usage and distribution conditions                   !
! http://phantomsph.github.io/                                             !
!--------------------------------------------------------------------------!
module setup
!
! Setup for general relativistic tidal disruption event
!
! :References: None
!
! :Owner: David Liptai
!
! :Runtime parameters:
!   - beta          : *penetration factor*
!   - dumpsperorbit : *number of dumps per orbit*
!   - ecc_bh        : *eccentricity (1 for parabolic)*
!   - mhole         : *mass of black hole (solar mass)*
!   - norbits       : *number of orbits*
!   - relax         : *relax star into hydrostatic equilibrium*
!   - theta_bh      : *inclination of orbit (degrees)*
!
! :Dependencies: eos, externalforces, gravwaveutils, infile_utils, io,
!   kernel, metric, mpidomain, options, part, physcon, relaxstar,
!   setbinary, setstar, setup_params, systemutils, timestep, units,
!   vectorutils
!

 use setstar,  only:star_t
 use setorbit, only:orbit_t
 implicit none
 public :: setpart

 real    :: mhole,beta,ecc_bh,norbits,theta_bh
 real    :: a_binary
 real    :: x1,y1,z1,x2,y2,z2
 real    :: vx1,vy1,vz1,vx2,vy2,vz2
 integer :: dumpsperorbit,nstar
 logical :: relax
 logical :: provide_params
 type(star_t)  :: star(2)
 type(orbit_t) :: orbit

 private

contains

!----------------------------------------------------------------
!+
!  setup for sink particle binary simulation (no gas)
!+
!----------------------------------------------------------------
subroutine setpart(id,npart,npartoftype,xyzh,massoftype,vxyzu,polyk,gamma,hfact,time,fileprefix)
 use part,      only:nptmass,xyzmh_ptmass,vxyz_ptmass,ihacc,ihsoft,igas,&
                     gravity,eos_vars,rad,gr,nsinkproperties
 use setbinary, only:set_binary
 use setorbit,   only:set_defaults_orbit,set_orbit
 use setstar,   only:set_star,shift_star,set_defaults_stars,set_defaults_star,set_stars,shift_stars
 use units,     only:set_units,umass,udist,unit_velocity
 use physcon,   only:solarm,pi,solarr
 use io,        only:master,fatal,warning
 use timestep,  only:tmax,dtmax
 use metric,    only:mass1,a
 use eos,       only:ieos,X_in,Z_in
 use kernel,    only:hfact_default
 use mpidomain, only:i_belong
 use externalforces, only:accradius1,accradius1_hard
 use vectorutils,    only:rotatevec
 use gravwaveutils,  only:theta_gw,calc_gravitwaves
 use setup_params,   only:rhozero,npart_total
 use systemutils,    only:get_command_option
 use options,        only:iexternalforce,damp
 integer,           intent(in)    :: id
 integer,           intent(inout) :: npart
 integer,           intent(out)   :: npartoftype(:)
 real,              intent(out)   :: xyzh(:,:)
 real,              intent(out)   :: massoftype(:)
 real,              intent(out)   :: polyk,gamma,hfact
 real,              intent(inout) :: time
 character(len=20), intent(in)    :: fileprefix
 real,              intent(out)   :: vxyzu(:,:)
 character(len=120) :: filename
 character(len=20) :: semi_major_axis
 character(len=20) :: semi_major_axis_str
 integer :: ierr,np_default
 integer :: nptmass_in,iextern_prev
 integer :: i,ios
 logical :: iexist,write_profile,use_var_comp
 real    :: rtidal,rp,semia,period,hacc1,hacc2
 real    :: vxyzstar(3),xyzstar(3)
 real    :: r0,vel,lorentz
 real    :: vhat(3),x0,y0
 real    :: semi_maj_val
 real    :: xyzmh_ptmass_in(nsinkproperties,2),vxyz_ptmass_in(3,2),angle
!
!-- general parameters
!
 hfact = hfact_default
 time  = 0.
 polyk = 1.e-10    ! <== uconst
 gamma = 5./3.
 ieos  = 2
 if (.not.gravity) call fatal('setup','recompile with GRAVITY=yes')
!
!-- space available for injected gas particles
!
 npart          = 0
 npartoftype(:) = 0
 xyzh(:,:)      = 0.
 vxyzu(:,:)     = 0.
 nptmass        = 0
!
!-- Default runtime parameters
!
 mhole           = 1.e6  ! (solar masses)
if (gr) then
    call set_units(mass=mhole*solarm,c=1.d0,G=1.d0) !--Set umass as 1e6*msun 
 else
    call set_units(mass=solarm,dist=solarr,G=1.d0)
 endif
!  star%mstar      = 1.*solarm/umass
!  star%rstar      = 1.*solarr/udist
 np_default      = 1e6
!  star%np         = int(get_command_option('np',default=np_default)) ! can set default value with --np=1e5 flag (mainly for testsuite)
!  star%iprofile   = 2
 beta            = 5.
 ecc_bh          = 0.8
 norbits         = 5.
 dumpsperorbit   = 100
 theta_bh        = 0.
 write_profile   = .false.
 use_var_comp    = .false.
 relax           = .true.

 if (nstar > 1) then 
    call set_defaults_stars(star)
    call set_defaults_orbit(orbit)
 else 
    call set_defaults_star(star(1))
 endif 
!
!-- Read runtime parameters from setup file
!
 if (id==master) print "(/,65('-'),1(/,a),/,65('-'),/)",' Tidal disruption in GR'
 filename = trim(fileprefix)//'.setup'
 inquire(file=filename,exist=iexist)
 if (iexist) call read_setupfile(filename,ieos,polyk,mass1,ierr)
 if (.not. iexist .or. ierr /= 0) then
    if (id==master) then
       call write_setupfile(filename)
       print*,' Edit '//trim(filename)//' and rerun phantomsetup'
    endif
    stop
 endif
 ! 
 !--set nstar/nptmass stars around the BH. This would also relax the star. 
 ! 
 call set_stars(id,master,nstar,star,xyzh,vxyzu,eos_vars,rad,npart,npartoftype,&
                massoftype,hfact,xyzmh_ptmass,vxyz_ptmass,nptmass,ieos,polyk,gamma,&
                X_in,Z_in,relax,use_var_comp,write_profile,&
                rhozero,npart_total,i_belong,ierr)
 
 if (star(1)%iprofile == 0 .and. nstar == 1) then 
    xyzmh_ptmass_in(4,1) = star(1)%mstar 
    xyzmh_ptmass_in(5,1) = star(1)%hacc
    
 endif 

 ! 
 !--set the stars around each other first if nstar > 1 (Assuming binary system)
 !
 if (nstar > 1 .and. (.not. provide_params)) then 
    nptmass_in = 0
    call set_orbit(orbit,star(1)%mstar,star(2)%mstar,star(1)%hacc,star(2)%hacc,&
                   xyzmh_ptmass_in,vxyz_ptmass_in,nptmass_in,(id==master),ierr)

    if (ierr /= 0) call fatal ('setup_binary','error in call to set_orbit')
    if (ierr /= 0) call fatal('setup','errors in set_star')
 endif 
 
 !
 !--place star / stars into orbit
 !
 ! Calculate tidal radius
 if (nstar == 1) then 
    ! for single star around the BH, the tidal radius is given by 
    ! RT = rr * (MM / mm)**(1/3) where rr is rstar, MM is mass of BH and mm is mass of star
    rtidal          = star(1)%rstar * (mass1/star(1)%mstar)**(1./3.)
    rp              = rtidal/beta
 else 
    semi_major_axis_str = orbit%elems%semi_major_axis
    read(semi_major_axis_str, *, iostat=ios) semi_maj_val
    ! for a binary, tidal radius is given by 
    ! orbit.an * (3 * MM / mm)**(1/3) where mm is mass of binary and orbit.an is semi-major axis of binary 
    rtidal          = semi_maj_val * (3.*mass1 / (star(1)%mstar + star(2)%mstar))**(1./3.)
    rp              = rtidal/beta
 endif 

 if (gr) then 
    accradius1_hard = 5.*mass1
    accradius1      = accradius1_hard
 else 
    accradius1_hard = 6.
    accradius1      = accradius1_hard
 endif
 a               = 0.
 theta_bh        = theta_bh*pi/180.
 
 print*, 'umass', umass
 print*, 'udist', udist
 print*, 'uvel', unit_velocity
 print*, 'mass1', mass1
 print*, 'tidal radius', rtidal
 print*, 'beta', beta
 print*, accradius1_hard, "accradius1_hard",mass1,"mass1"

 if (.not. provide_params) then 
   do i = 1, nstar
      print*, 'mstar of star ',i,' is: ', star(i)%mstar
      print*, 'rstar of star ',i,' is: ', star(i)%rstar
   enddo 

   xyzstar  = 0.
   vxyzstar = 0.
   period   = 0.

   if (ecc_bh<1.) then
      !
      !-- Set a binary orbit given the desired orbital parameters to get the position and velocity of the star
      !
      semia    = rp/(1.-ecc_bh)
      period   = 2.*pi*sqrt(semia**3/mass1)
      hacc1    = star(1)%rstar/1.e8    ! Something small so that set_binary doesnt warn about Roche lobe
      hacc2    = hacc1
      ! apocentre = rp*(1.+ecc_bh)/(1.-ecc_bh)
      ! trueanom = acos((rp*(1.+ecc_bh)/r0 - 1.)/ecc_bh)*180./pi
      call set_binary(mass1,star(1)%mstar,semia,ecc_bh,hacc1,hacc2,xyzmh_ptmass,vxyz_ptmass,nptmass,ierr,&
                     posang_ascnode=0.,arg_peri=90.,incl=0.,f=-180.)
      vxyzstar(:) = vxyz_ptmass(1:3,2)
      xyzstar(:)  = xyzmh_ptmass(1:3,2)
      nptmass  = 0

      call rotatevec(xyzstar,(/0.,1.,0./),-theta_bh)
      call rotatevec(vxyzstar,(/0.,1.,0./),-theta_bh)

   elseif (abs(ecc_bh-1.) < tiny(0.)) then
      !
      !-- Setup a parabolic orbit
      !
      r0       = 10.*rtidal              ! A default starting distance from the black hole.
      period   = 2.*pi*sqrt(r0**3/mass1) !period not defined for parabolic orbit, so just need some number
      y0       = -2.*rp + r0
      x0       = sqrt(r0**2 - y0**2)
      xyzstar(:)  = (/-x0,y0,0./)
      vel      = sqrt(2.*mass1/r0)
      vhat     = (/2.*rp,-x0,0./)/sqrt(4.*rp**2 + x0**2)
      vxyzstar(:) = vel*vhat

      call rotatevec(xyzstar,(/0.,1.,0./),theta_bh)
      call rotatevec(vxyzstar,(/0.,1.,0./),theta_bh)

   else
      call fatal('setup','please choose a valid eccentricity (0<ecc_bh<=1)',var='ecc_bh',val=ecc_bh)
   endif

   lorentz = 1./sqrt(1.-dot_product(vxyzstar(:),vxyzstar(:)))
   if (lorentz>1.1) call warning('setup','Lorentz factor of star greater than 1.1, density may not be correct')

   tmax      = norbits*period
   dtmax     = period/dumpsperorbit
 endif 

 if (id==master) then
    print "(/,a)",       ' STAR SETUP:'
    print "(a,3f10.3)"  ,'         Position = ',xyzstar
    print "(a,3f10.3)"  ,'         Velocity = ',vxyzstar
    print "(a,1f10.3)"  ,' Lorentz factor   = ',lorentz
    print "(a,1f10.3)"  ,' Polytropic gamma = ',gamma
    print "(a,3f10.3,/)",'       Pericentre = ',rp
 endif
 !
 !--shift stars / sink particles 
 !
 if (provide_params) then 
    xyzmh_ptmass_in(1:3,1)  = (/x1,y1,z1/)
    xyzmh_ptmass_in(1:3,2)  = (/x2,y2,z2/)
    vxyz_ptmass_in(:,1) = (/vx1, vy1, vz1/)
    vxyz_ptmass_in(:,2) = (/vx2, vy2, vz2/)

    xyzmh_ptmass_in(4,1) = star(1)%mstar 
    xyzmh_ptmass_in(5,1) = star(1)%hacc

    xyzmh_ptmass_in(4,2) = star(2)%mstar
    xyzmh_ptmass_in(5,2) = star(2)%hacc                
 else
    xyzmh_ptmass_in(1:3,1) = xyzmh_ptmass_in(1:3,1) + xyzstar(:)
    vxyz_ptmass_in(1:3,1) = vxyz_ptmass_in(1:3,1) + vxyzstar(:)
 endif

 call shift_stars(nstar,star,xyzmh_ptmass_in,vxyz_ptmass_in,&
                  xyzh,vxyzu,xyzmh_ptmass,vxyz_ptmass,npart,&
                  nptmass)

 if (id==master) print "(/,a,i10,/)",' Number of particles setup = ',npart

 !
 !--set a few options for the input file
 !
 calc_gravitwaves = .true.
 if (abs(ecc_bh-1.) > epsilon(0.)) then
    theta_gw = theta_bh*180./pi
 else
    theta_gw = -theta_bh*180./pi
 endif

 if (.not.gr) iexternalforce = 1
 ! We have ignored the following error message.  
 !if (npart == 0)   call fatal('setup','no particles setup')
 if (ierr /= 0)    call fatal('setup','ERROR during setup')

end subroutine setpart

!
!---Read/write setup file--------------------------------------------------
!
subroutine write_setupfile(filename)
 use infile_utils, only:write_inopt
 use setstar,      only:write_options_star,write_options_stars
 use relaxstar,    only:write_options_relax
 use setorbit,     only:write_options_orbit
 character(len=*), intent(in) :: filename
 integer :: iunit

 print "(a)",' writing setup options file '//trim(filename)
 open(newunit=iunit,file=filename,status='replace',form='formatted')
 write(iunit,"(a)") '# input file for tidal disruption setup'
 call write_inopt(provide_params,'provide_params','initial conditions',iunit)
 call write_inopt(nstar,        'nstar',        'number of stars to set',iunit)

 if (nstar .ne. 0) then 
    if (nstar == 1) then 
       call write_options_star(star(1),iunit)
       call write_inopt(relax,'relax','relax star into hydrostatic equilibrium',iunit)
       if (relax) call write_options_relax(iunit) 
    else 
       call write_options_stars(star,relax,iunit)
    endif 


   write(iunit,"(/,a)") '# options for black hole and orbit'
   call write_inopt(mhole,        'mhole',        'mass of black hole (solar mass)',iunit)
   if (.not. provide_params) then 
      call write_inopt(beta,         'beta',         'penetration factor',             iunit)
      call write_inopt(ecc_bh,       'ecc_bh',       'eccentricity (1 for parabolic)', iunit)
      call write_inopt(norbits,      'norbits',      'number of orbits',               iunit)
      call write_inopt(dumpsperorbit,'dumpsperorbit','number of dumps per orbit',      iunit)
      call write_inopt(theta_bh,     'theta_bh',     'inclination of orbit (degrees)', iunit)
      if (nstar > 1) then 
          call write_options_orbit(orbit,iunit)
      endif 
   else 
      write(iunit,"(/,a)") '# provide inputs for the binary system'
      call write_params(iunit)
   endif 
 endif 
 close(iunit)

end subroutine write_setupfile

subroutine read_setupfile(filename,ieos,polyk,mass1,ierr)
 use infile_utils, only:open_db_from_file,inopts,read_inopt,close_db
 use io,           only:error
 use setstar,      only:read_options_star,read_options_stars
 use relaxstar,    only:read_options_relax
 use physcon,      only:solarm,solarr
 use units,        only:set_units,umass
 use setorbit,     only:read_options_orbit
 character(len=*), intent(in)    :: filename
 integer,          intent(inout) :: ieos
 real,             intent(inout) :: polyk
 integer,          intent(out)   :: ierr
 real,             intent(out)   :: mass1
 integer, parameter :: iunit = 21
 integer :: nerr,need_iso
 type(inopts), allocatable :: db(:)

 print "(a)",'reading setup options from '//trim(filename)
 nerr = 0
 ierr = 0
 call open_db_from_file(db,filename,iunit,ierr)
 !
 !--read black hole mass and use it to define code units
 !
 call read_inopt(provide_params,'provide_params',db,errcount=nerr)
 call read_inopt(mhole,'mhole',db,min=0.,errcount=nerr)
!  call set_units(mass=mhole*solarm,c=1.d0,G=1.d0) !--Set central mass to M=1 in code units
 ! This ensures that we can run simulations with BH's as massive as 1e9 msun. 
 ! A BH of mass 1e9 msun would be 1e3 in code units when umass is 1e6*solar masses. 
 mass1 = mhole*solarm/umass
 call read_inopt(nstar,           'nstar',         db,min=0,errcount=nerr)
 !
 !--read star options and convert to code units
 !
 if (nstar .ne. 0) then 
    if (nstar == 1) then 
       call read_options_star(star(1),need_iso,ieos,polyk,db,nerr)
       call read_inopt(relax,'relax',db,errcount=nerr)
       if (relax) call read_options_relax(db,nerr)
    else 
       call read_options_stars(star,need_iso,ieos,polyk,relax,db,nerr)
    endif 

 if (.not. provide_params) then 
   call read_inopt(beta,           'beta',           db,min=0.,errcount=nerr)
   call read_inopt(ecc_bh,         'ecc_bh',         db,min=0.,max=1.,errcount=nerr)
   call read_inopt(norbits,        'norbits',        db,min=0.,errcount=nerr)
   call read_inopt(dumpsperorbit,  'dumpsperorbit',  db,min=0 ,errcount=nerr)
   call read_inopt(theta_bh,       'theta_bh',       db,       errcount=nerr)
   if (nstar > 1) then 
      call read_options_orbit(orbit,db,nerr)
   endif 
 else 
   call read_params(db,nerr)
 endif 

 endif 
 call close_db(db)
 if (nerr > 0) then
    print "(1x,i2,a)",nerr,' error(s) during read of setup file: re-writing...'
    ierr = nerr
 endif

end subroutine read_setupfile

subroutine write_params(iunit)
 use infile_utils, only:write_inopt
 integer, intent(in) :: iunit
 
 call write_inopt(x1,         'x1',         'pos x star 1',             iunit)
 call write_inopt(y1,         'y1',         'pos y star 1',             iunit)
 call write_inopt(z1,         'z1',         'pos z star 1',             iunit)
 call write_inopt(x2,         'x2',         'pos x star 2',             iunit)
 call write_inopt(y2,         'y2',         'pos y star 2',             iunit)
 call write_inopt(z2,         'z2',         'pos z star 2',             iunit)
 call write_inopt(vx1,        'vx1',        'vel x star 1',             iunit)
 call write_inopt(vy1,        'vy1',        'vel y star 1',             iunit)
 call write_inopt(vz1,        'vz1',        'vel z star 1',             iunit)
 call write_inopt(vx2,        'vx2',        'vel x star 2',             iunit)
 call write_inopt(vy2,        'vy2',        'vel y star 2',             iunit)
 call write_inopt(vz2,        'vz2',        'vel z star 2',             iunit)

end subroutine write_params

subroutine read_params(db,nerr)
 use infile_utils, only:inopts,read_inopt
 type(inopts), allocatable, intent(inout) :: db(:)
 integer,      intent(inout) :: nerr

 call read_inopt(x1,         'x1',         db,errcount=nerr)
 call read_inopt(y1,         'y1',         db,errcount=nerr)
 call read_inopt(z1,         'z1',         db,errcount=nerr)
 call read_inopt(x2,         'x2',         db,errcount=nerr)
 call read_inopt(y2,         'y2',         db,errcount=nerr)
 call read_inopt(z2,         'z2',         db,errcount=nerr)
 call read_inopt(vx1,        'vx1',        db,errcount=nerr)
 call read_inopt(vy1,        'vy1',        db,errcount=nerr)
 call read_inopt(vz1,        'vz1',        db,errcount=nerr)
 call read_inopt(vx2,        'vx2',        db,errcount=nerr)
 call read_inopt(vy2,        'vy2',        db,errcount=nerr)
 call read_inopt(vz2,        'vz2',        db,errcount=nerr)

end subroutine read_params

end module setup
