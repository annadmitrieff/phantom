!--------------------------------------------------------------------------!
! The Phantom Smoothed Particle Hydrodynamics code, by Daniel Price et al. !
! Copyright (c) 2007-2024 The Authors (see AUTHORS)                        !
! See LICENCE file for usage and distribution conditions                   !
! http://phantomsph.github.io/                                             !
!--------------------------------------------------------------------------!
module kernel
!
! This module implements the M_6 quintic kernel
!   DO NOT EDIT - auto-generated by kernels.py
!
! :References: None
!
! :Owner: Daniel Price
!
! :Runtime parameters: None
!
! :Dependencies: physcon
!
 use physcon, only:pi
 implicit none
 character(len=11), public :: kernelname = 'M_6 quintic'
 real, parameter, public  :: radkern  = 3.
 real, parameter, public  :: radkern2 = 9.
 real, parameter, public  :: cnormk = 1./(120.*pi)
 real, parameter, public  :: wab0 = 66., gradh0 = -3.*wab0
 real, parameter, public  :: dphidh0 = 239./210.
 real, parameter, public  :: cnormk_drag = 1./(168.*pi)
 real, parameter, public  :: hfact_default = 1.0
 real, parameter, public  :: av_factor = 2771./1890.

contains

pure subroutine get_kernel(q2,q,wkern,grkern)
 real, intent(in)  :: q2,q
 real, intent(out) :: wkern,grkern
 real :: q4

 !--M_6 quintic
 if (q < 1.) then
    q4 = q2*q2
    wkern  = -10.*q4*q + 30.*q4 - 60.*q2 + 66.
    grkern = q*(-50.*q2*q + 120.*q2 - 120.)
 elseif (q < 2.) then
    wkern  = -(q - 3.)**5 + 6.*(q - 2.)**5
    grkern = -5.*(q - 3.)**4 + 30.*(q - 2.)**4
 elseif (q < 3.) then
    wkern  = -(q - 3.)**5
    grkern = -5.*(q - 3.)**4
 else
    wkern  = 0.
    grkern = 0.
 endif

end subroutine get_kernel

pure elemental real function wkern(q2,q)
 real, intent(in) :: q2,q
 real :: q4

 if (q < 1.) then
    q4 = q2*q2
    wkern = -10.*q4*q + 30.*q4 - 60.*q2 + 66.
 elseif (q < 2.) then
    wkern = -(q - 3.)**5 + 6.*(q - 2.)**5
 elseif (q < 3.) then
    wkern = -(q - 3.)**5
 else
    wkern = 0.
 endif

end function wkern

pure elemental real function grkern(q2,q)
 real, intent(in) :: q2,q

 if (q < 1.) then
    grkern = q*(-50.*q2*q + 120.*q2 - 120.)
 elseif (q < 2.) then
    grkern = -5.*(q - 3.)**4 + 30.*(q - 2.)**4
 elseif (q < 3.) then
    grkern = -5.*(q - 3.)**4
 else
    grkern = 0.
 endif

end function grkern

pure subroutine get_kernel_grav1(q2,q,wkern,grkern,dphidh)
 real, intent(in)  :: q2,q
 real, intent(out) :: wkern,grkern,dphidh
 real :: q4, q6

 if (q < 1.) then
    q4 = q2*q2
    q6 = q4*q2
    wkern  = -10.*q4*q + 30.*q4 - 60.*q2 + 66.
    grkern = q*(-50.*q2*q + 120.*q2 - 120.)
    dphidh = q6*q/21. - q6/6. + q4/2. - 11.*q2/10. + 239./210.
 elseif (q < 2.) then
    q4 = q2*q2
    q6 = q4*q2
    wkern  = -(q - 3.)**5 + 6.*(q - 2.)**5
    grkern = -5.*(q - 3.)**4 + 30.*(q - 2.)**4
    dphidh = -q6*q/42. + q6/4. - q4*q + 7.*q4/4. - 5.*q2*q/6. - 17.*q2/20. + &
                 473./420.
 elseif (q < 3.) then
    q4 = q2*q2
    q6 = q4*q2
    wkern  = -(q - 3.)**5
    grkern = -5.*(q - 3.)**4
    dphidh = q6*q/210. - q6/12. + 3.*q4*q/5. - 9.*q4/4. + 9.*q2*q/2. - 81.*q2/20. + &
                 243./140.
 else
    wkern  = 0.
    grkern = 0.
    dphidh = 0.
 endif

end subroutine get_kernel_grav1

pure subroutine kernel_softening(q2,q,potensoft,fsoft)
 real, intent(in)  :: q2,q
 real, intent(out) :: potensoft,fsoft
 real :: q4, q6, q8

 if (q < 1.) then
    q4 = q2*q2
    q6 = q4*q2
    potensoft = -q6*q/168. + q6/42. - q4/10. + 11.*q2/30. - 239./210.
    fsoft     = q*(-35.*q4*q + 120.*q4 - 336.*q2 + 616.)/840.
 elseif (q < 2.) then
    q4 = q2*q2
    q6 = q4*q2
    q8 = q6*q2
    potensoft = (q*(5.*q6*q - 60.*q6 + 280.*q4*q - 588.*q4 + 350.*q2*q + 476.*q2 - &
                 1892.) - 5.)/(1680.*q)
    fsoft     = (35.*q8 - 360.*q6*q + 1400.*q6 - 2352.*q4*q + 1050.*q4 + 952.*q2*q + &
                 5.)/(1680.*q2)
 elseif (q < 3.) then
    q4 = q2*q2
    q6 = q4*q2
    q8 = q6*q2
    potensoft = (q*(-q6*q + 20.*q6 - 168.*q4*q + 756.*q4 - 1890.*q2*q + 2268.*q2 - &
                 2916.) + 507.)/(1680.*q)
    fsoft     = (-7.*q8 + 120.*q6*q - 840.*q6 + 3024.*q4*q - 5670.*q4 + 4536.*q2*q - &
                 507.)/(1680.*q2)
 else
    potensoft = -1./q
    fsoft     = 1./q2
 endif

end subroutine kernel_softening

!------------------------------------------
! gradient acceleration kernel needed for
! use in Forward symplectic integrator
!------------------------------------------
pure subroutine kernel_grad_soft(q2,q,gsoft)
 real, intent(in)  :: q2,q
 real, intent(out) :: gsoft
 real :: q4, q6, q8

 if (q < 1.) then
    gsoft = q2*q*(-175.*q2*q + 480.*q2 - 672.)/840.
 elseif (q < 2.) then
    q4 = q2*q2
    q6 = q4*q2
    q8 = q6*q2
    gsoft = (175.*q8 - 1440.*q6*q + 4200.*q6 - 4704.*q4*q + 1050.*q4 - &
                 15.)/(1680.*q2)
 elseif (q < 3.) then
    q4 = q2*q2
    q6 = q4*q2
    q8 = q6*q2
    gsoft = (-35.*q8 + 480.*q6*q - 2520.*q6 + 6048.*q4*q - 5670.*q4 + &
                 1521.)/(1680.*q2)
 else
    gsoft = -3./q2
 endif

end subroutine kernel_grad_soft

!------------------------------------------
! double-humped version of the kernel for
! use in drag force calculations
!------------------------------------------
pure elemental real function wkern_drag(q2,q)
 real, intent(in) :: q2,q
 real :: q4

 !--double hump M_6 quintic kernel
 if (q < 1.) then
    q4 = q2*q2
    wkern_drag = q2*(-10.*q4*q + 30.*q4 - 60.*q2 + 66.)
 elseif (q < 2.) then
    wkern_drag = q2*(-(q - 3.)**5 + 6.*(q - 2.)**5)
 elseif (q < 3.) then
    wkern_drag = -q2*(q - 3.)**5
 else
    wkern_drag = 0.
 endif

end function wkern_drag

end module kernel
