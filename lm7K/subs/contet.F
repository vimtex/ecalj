      subroutine contet(mode,nbmx,nsp,nspx,nevmx,nchan,n1,n2,n3,ntet,
     .idtet,qp,ipq0,igstar,iblst,eband,cvec,doswt,npts,emin,
     .emax,lidos,wk,zos)
C- Conductivity or DOS-related quantity by tetrahedron integration
C ----------------------------------------------------------------------
Ci Inputs
Ci   mode  :selects what function is to be integrated (see mkcond.f)
Ci         :1s digit:
Ci         :0 => dos
Ci         :1 => 1/2 | grad_k E(k) . cvec | (ballistic conductivity)
Ci         :2 => grad_1 E(k) . grad_2 E(k) where _1 and _2 are
Ci         :     direction vectors specified by cvec
Ci   nbmx  :dimensions eband,doswt
Ci   nsp   :2 for spin-polarized case, otherwise 1
Ci   nspx  :number of independent spin channels
Ci          (1 unless nsp=2, and independent spins)
Ci   nevmx :number of bands to sum over
Ci   nchan :number of DOS channels
Ci   n1..n3:no. divisions for the 3 recip. lattice. vectors
Ci   ntet  :no. of different tetrahedra
Ci   idtet :idtet(0,i) =no of tetrahedra of the i'th kind
Ci         :idtet(1-4,i) marks the 4 irreducible qp of i'th tetrahedron
Ci   qp    :list of irreducible k-points: qp(1..3,i) is i'th qp
Ci   ipq0  :ipq as generated by bzmesh for qp of the irr. BZ.
Ci   igstar:table of inverse mapping of ipq for the BZ of reduced
Ci          symmetry; generated by call to bzmesh with igstar(0)=2
Ci          and with no symmetry operations.
Ci   iblst :(iblst(1)>0)  => iblst = a prescribed list of energy bands
Ci         :In this mode sum is bands iblst(1)..iblst(nevmx).
Ci         :(iblst(1)<=0) => sum over bands 1..nevmx
Ci   eband :energy bands
Ci   cvec  :direction in which to calc. conductivity
Ci   doswt :number of states, for each of nchan channels, at each energy
Ci         :and irr. qp of whatever to be integrated by the tetrahedron
Ci         :method.
Ci   npts  :number of tabulation points in energy range (emin,emax)
Ci   emin  :lower bound to energy window
Ci   emax  :upper bound to energy window
Ci   lidos :F zos = conductivity or dos-related quantity
Ci         :T zos = energy integral of this quantity
Ci   wk    :work array of size npts
Co Outputs:
Co   zos   :conductivity or other dos-related quantity on uniform
Co         :mesh in energy window (emin,emax); or energy integral
Co         :of the same (lidos=T); see Remarks
Cr Remarks
Cr   This routine uses the tetrahedron method to integrate quantities
Cr       zos_n(E) = int d^3k delta(E-E(k)) doswt_n (k) f(E,k)
Cr   foreach n = 1..nchan.  doswt_n is the number of states in channel
Cr   n; thus if f(k)=1 contet returns the density of states for each
Cr   channel.  The caller chooses what function f is to be integrated
Cr   by input mode (see mkcond.f)
Cu Updates
Cu   03 Feb 01  several revisions: different modes for mkcond
Cu              integrate over subset of bands
C ----------------------------------------------------------------------
C     implicit none
C ... Passed parameters
      integer mode,nchan,nsp,nspx,nbmx,npts,ntet,idtet(0:4,*),n1,n2,
     .n3,nevmx,igstar(0:*),ipq0(n1,n2,n3),iblst(nevmx)
      double precision eband(nbmx,nspx,*),emin,emax,wk(npts),
     .zos(npts,nsp,nchan),doswt(nchan,nbmx,nsp,*),qp(3,1),cvec(3,2)
      logical lidos
C ... Local parameters
      integer isp,ib,i,itet,ichan,iq(4),jq(4),nspc,jsp,ksp,ndmx,mxxyz,
     .getdig,i1,i2,i3,ibp
      double precision bin,eigen(4),v,wt,ebot,dmin1,wc
C ... External calls
      external dcopy,dpzero,mkcond,slinz

      if (npts .le. 1 .or. npts .le. 2 .and. .not. lidos) call rx1(
     .'contet: npts(=%i) too small for DOS : require npts>2',npts)
      nspc = nsp / nspx
      call dpzero(zos,npts*nsp*nchan)
      bin = npts - 1
      bin = (emax - emin) / bin
      v = ( 3d0  -  nsp ) / ( n1 * n2 * n3 * 6d0 )
      ndmx = mxxyz()

C --- Loop over irreducible tetrahedra ---
      do  5  itet = 1, ntet
        iq(1) = idtet(1,itet)
        iq(2) = idtet(2,itet)
        iq(3) = idtet(3,itet)
        iq(4) = idtet(4,itet)
C   ... For each of the iq, find mapping to equivalent jq in eband
        do  6  i = 1, 4
          i3 = getdig(igstar(iq(i)),2,ndmx)
          i2 = getdig(igstar(iq(i)),1,ndmx)
          i1 = getdig(igstar(iq(i)),0,ndmx)
          jq(i) = ipq0(i1,i2,i3)
    6   continue

C --- Loop over spins and sum over bands ---
        do  4  isp = 1, nspx
          do  3  ib = 1, nevmx
            if (iblst(1) .gt. 0) then
              ibp = iblst(ib)
            else
              ibp = ib
            endif
            eigen(1) = eband(ibp,isp,jq(1))
            eigen(2) = eband(ibp,isp,jq(2))
            eigen(3) = eband(ibp,isp,jq(3))
            eigen(4) = eband(ibp,isp,jq(4))
            ebot = dmin1(eigen(1),eigen(2),eigen(3),eigen(4))
            if (ebot .gt. emax) goto 3

            do  12  jsp = 1, nspc
C       ... ksp is isp for uncoupled spins, and jsp for coupled spins
              ksp = max(jsp,isp)

              call mkcond(mode,eigen,qp,iq(1),iq(2),iq(3),iq(4),cvec,wc)

C       ... Accumulate no. states assuming constant wt from this tet
              do  2  ichan = 1, nchan
C         ... This is weight for no. states
                wt = doswt(ichan,ibp,ksp,jq(1))
     .          + doswt(ichan,ibp,ksp,jq(2))
     .          + doswt(ichan,ibp,ksp,jq(3))
     .          + doswt(ichan,ibp,ksp,jq(4))
                wt = wt * idtet(0,itet) * v / 4d0
C         ... Add weights from mkcond
                wt = wt*wc
                call slinz(wt,eigen,emin,emax,zos(1,ksp,ichan),npts)
    2         continue
   12       continue
    3     continue
    4   continue
    5 continue

      if (lidos) return

C --- DOS from finite difference of NOS ---
      bin = 2d0 * bin
      do  11  isp  = 1, nsp
      do  11  ichan = 1, nchan
        do  10  i = 2, npts - 1
          wk(i) = (zos(i+1,isp,ichan) - zos(i-1,isp,ichan)) / bin
   10   continue
        wk(1)    = wk(2)
        wk(npts) = wk(npts-1)
        call dcopy(npts,wk,1,zos(1,isp,ichan),1)
   11 continue
      end

