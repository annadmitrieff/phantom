module extern_gr
 implicit none

 public :: get_grforce, update_grforce_leapfrog

 private

contains

!---------------------------------------------------------------
!+
!  Wrapper subroutine for computing the force due to spacetime curvature
!  (This may be useful in the future if there is something that indicates
!   whether a particle is gas or test particle.)
!+
!---------------------------------------------------------------
subroutine get_grforce(xyzi,veli,densi,ui,pi,fexti,dtf)
 real, intent(in)  :: xyzi(3),veli(3),densi,ui,pi
 real, intent(out) :: fexti(3),dtf
 real :: x,y,z,r2,r

 call forcegr(xyzi,veli,densi,ui,pi,fexti)

 x = xyzi(1)
 y = xyzi(2)
 z = xyzi(3)

 r2 = x*x + y*y + z*z
 r  = sqrt(r2)

 dtf = 0.25*sqrt(r*r2)*1.e-2

end subroutine get_grforce

!----------------------------------------------------------------
!+
!  Compute the source terms required on the right hand side of
!  the relativistic momentum equation. These are of the form:
!   T^\mu\nu dg_\mu\nu/dx^i
!+
!----------------------------------------------------------------
subroutine forcegr(x,v,dens,u,p,fterm)
 use metric_tools, only: get_metric, get_metric_derivs
 use utils_gr,     only: get_u0
 real,    intent(in)  :: x(3),v(3),dens,u,p
 real,    intent(out) :: fterm(3)
 real    :: gcov(0:3,0:3), gcon(0:3,0:3)
 real    :: sqrtg
 real    :: dgcovdx1(0:3,0:3), dgcovdx2(0:3,0:3), dgcovdx3(0:3,0:3)
 real    :: v4(0:3), term(0:3,0:3)
 real    :: enth, uzero
 integer :: i,j

 call get_metric(x,gcov,gcon,sqrtg)
 call get_metric_derivs(x,dgcovdx1, dgcovdx2, dgcovdx3)
 enth = 1. + u + p/dens

 ! lower-case 4-velocity
 v4(0) = 1.
 v4(1:3) = v(:)

 ! first component of the upper-case 4-velocity
 call get_u0(x,v,uzero)

 ! energy-momentum tensor times sqrtg on 2rho*
 do j=0,3
    do i=0,3
       term(i,j) = 0.5*(enth*uzero*v4(i)*v4(j) + P*gcon(i,j)/(dens*uzero))
    enddo
 enddo

 ! source term
 fterm(1) = 0.
 fterm(2) = 0.
 fterm(3) = 0.
 do j=0,3
    do i=0,3
       fterm(1) = fterm(1) + term(i,j)*dgcovdx1(i,j)
       fterm(2) = fterm(2) + term(i,j)*dgcovdx2(i,j)
       fterm(3) = fterm(3) + term(i,j)*dgcovdx3(i,j)
    enddo
 enddo

end subroutine forcegr


!-------- I don't think this is actually being used at the moment....
subroutine update_grforce_leapfrog(vhalfx,vhalfy,vhalfz,fxi,fyi,fzi,fexti,dt,xi,yi,zi,densi,ui,pi)
 use io,             only:fatal
 real, intent(in)    :: dt,xi,yi,zi
 real, intent(in)    :: vhalfx,vhalfy,vhalfz
 real, intent(inout) :: fxi,fyi,fzi
 real, intent(inout) :: fexti(3)
 real, intent(in)    :: densi,ui,pi
 real                :: fextv(3)
 real                :: v1x, v1y, v1z, v1xold, v1yold, v1zold, vhalf2, erri, dton2
 logical             :: converged
 integer             :: its, itsmax
 integer, parameter  :: maxitsext = 50 ! maximum number of iterations on external force
 real, parameter :: tolv = 1.e-2
 real, parameter :: tolv2 = tolv*tolv
 real,dimension(3) :: pos,vel
 real :: dtf

 itsmax = maxitsext
 its = 0
 converged = .false.
 dton2 = 0.5*dt

 v1x = vhalfx
 v1y = vhalfy
 v1z = vhalfz
 vhalf2 = vhalfx*vhalfx + vhalfy*vhalfy + vhalfz*vhalfz
 fextv = 0. ! to avoid compiler warning

 iterations : do while (its < itsmax .and. .not.converged)
    its = its + 1
    erri = 0.
    v1xold = v1x
    v1yold = v1y
    v1zold = v1z
    pos = (/xi,yi,zi/)
    vel = (/v1x,v1y,v1z/)
    call get_grforce(pos,vel,densi,ui,pi,fextv,dtf)
!    xi = pos(1)
!    yi = pos(2)
!    zi = pos(3)
    v1x = vel(1)
    v1y = vel(2)
    v1z = vel(3)

    v1x = vhalfx + dton2*(fxi + fextv(1))
    v1y = vhalfy + dton2*(fyi + fextv(2))
    v1z = vhalfz + dton2*(fzi + fextv(3))

    erri = (v1x - v1xold)**2 + (v1y - v1yold)**2 + (v1z - v1zold)**2
    erri = erri / vhalf2
    converged = (erri < tolv2)

 enddo iterations

 if (its >= maxitsext) call fatal('update_grforce_leapfrog','VELOCITY ITERATIONS ON EXTERNAL FORCE NOT CONVERGED!!')

 fexti(1) = fextv(1)
 fexti(2) = fextv(2)
 fexti(3) = fextv(3)

 fxi = fxi + fexti(1)
 fyi = fyi + fexti(2)
 fzi = fzi + fexti(3)

end subroutine update_grforce_leapfrog

end module extern_gr
