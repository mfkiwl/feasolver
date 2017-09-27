SUBROUTINE STREAMLINE_INI()
    use function_plotter
    use solverds
    IMPLICIT NONE
    
    !INITIALIZE IVO
    IVO=0    
    select case(VECTOR_PLOT_GROUP)    
    case(VECTOR_GROUP_DIS)
        IVO=OUTVAR(DISX:DISZ).IVO
    case(VECTOR_GROUP_SEEPAGE_VEC)       
        IVO=OUTVAR(VX:VZ).IVO
    case(VECTOR_GROUP_SEEPAGE_GRAD)
        IVO=OUTVAR(GRADX:GRADZ).IVO
    case(VECTOR_GROUP_SFR)
        IVO(1:2)=OUTVAR(SFR_SFRX:SFR_SFRY).IVO
    end select
    
    call STREAMLINE_STEP_SIZE()
    
    isstreamlineinitialized=.true.
    
END SUBROUTINE    


SUBROUTINE STREAMLINE_PLOT()
    use solverds
    use opengl_gl
    use function_plotter
    use MESHGEO
    use view_modifier
    implicit none
   integer :: i,j,k,n1

    call glDeleteLists(STREAMLINELIST, 1_glsizei)
    call reset_view    
    call glNewList(STREAMLINELIST, gl_compile_and_execute)

    call glPolygonMode(gl_front_and_back, gl_fill)
	call gldisable(GL_CULL_FACE);  
    CALL glcolor4fv(mycolor(:,BLUE))
    CALL glLineWidth(2.0_glfloat)
    DO I=1,NSTREAMLINE
	    call glBegin(gl_LINE_STRIP)
		DO J=1,STREAMLINE(I).NV
			call glvertex3dv(STREAMLINE(I).V(:,J)) 
		ENDDO
	    CALL GLEND()
        
		call glPointSize(4.0_glfloat)
		call glbegin(gl_points)
		    DO J=1,STREAMLINE(I).NV
			    call glvertex3dv(STREAMLINE(I).V(:,J)) 
		    ENDDO			
		call glend        

    ENDDO
    CALL glLineWidth(1.0_glfloat)
    call glEndList

    
    call glutPostRedisplay



ENDSUBROUTINE

subroutine streamline_integration(PTstart)
    USE solverds
    use MESHGEO
    use function_plotter
    use ODE_SOLVER
    implicit none
    real(8),intent(in)::PTstart(3)    
    INTEGER::N1=3,IEL,I,J,NUP1
    INTEGER,PARAMETER::MAXSTEP1=1000
    REAL(8)::V1(3),V2(3),Y(3),EPS,YSCAL(3),Hdid,Hnext,T,Htry,direction1,IPT1(3)=0.D0,IPT2(3)=0.D0
    REAL(8)::YSAV(1:NDIMENSION,MAXSTEP1),YSAV_UP(1:NDIMENSION,MAXSTEP1)
    REAL(8)::P1(3),P2(3)
    EXTERNAL::DERIVS
    INTEGER::ISINTERCEPT1
    
    if(.not.isstreamlineinitialized) CALL STREAMLINE_INI()
    NSTREAMLINE=NSTREAMLINE+1
    IF(NSTREAMLINE>100) THEN
        PAUSE 'NSTREAMLINE>100.'
        RETURN
    ENDIF
    STREAMLINE(nstreamline).PTstart=PTstart
    DO J=1,2
        I=0
        y=PTstart(1:NDIMENSION);t=0.d0;YSAV=0.D0
        IF(J==1) THEN
            DIRECTION1=-1.d0
        ELSE
            DIRECTION1=1.d0
        ENDIF
        DO WHILE(I<MAXSTEP1)        
            CALL derivs(T,y,V1) 
           IF(RKINFO.ISOUTOFRANGE.AND.I>1) then
                ISINTERCEPT1=0
                P1(1:NDIMENSION)=YSAV(1:NDIMENSION,I-1)
                P2(1:NDIMENSION)=YSAV(1:NDIMENSION,I)
                IF(NDIMENSION==2) THEN
                    P1(3)=0.D0;P2(3)=0.D0
                ENDIF
                CALL GET_BC_INTERSECTION(P1,P2,IPT1,IPT2,ISINTERCEPT1)
                IF(ISINTERCEPT1==1) THEN
                    YSAV(:,I)=IPT1(1:NDIMENSION)                
                ENDIF
                EXIT 
            ENDIF    
            IF(NORM2(V1)<1E-10) EXIT
            
            IF(I<1) THEN
                htry=TET(RKINFO.IEL).STEPSIZE
            ELSE
                htry=min(TET(RKINFO.IEL).STEPSIZE,abs(hnext))
            ENDIF
            Htry=direction1*Htry
            N1=NDIMENSION;EPS=1.D-3;YSCAL=1.0D0
            CALL rkqs(y,V1,N1,T,Htry,eps,yscal,hdid,hnext,derivs)
            !IF(RKINFO.ISOUTOFRANGE) EXIT
            I=I+1
            YSAV(:,I)=Y(1:NDIMENSION)
        
        ENDDO
        
        IF(I>=MAXSTEP1) THEN
            pause 'Too many steps in streamline'
        else
            IF(J==1) THEN
                NUP1=I
                YSAV_UP(:,1:NUP1)=YSAV(:,NUP1:1:-1)                
            ELSE
                STREAMLINE(nstreamline).NV=I+NUP1+1
                IF(ALLOCATED(STREAMLINE(NSTREAMLINE).V)) DEALLOCATE(STREAMLINE(NSTREAMLINE).V)                
                ALLOCATE(STREAMLINE(NSTREAMLINE).V(3,STREAMLINE(nstreamline).NV))
                STREAMLINE(NSTREAMLINE).V(3,:)=0.d0
                STREAMLINE(NSTREAMLINE).V(1:NDIMENSION,1:NUP1)=YSAV_UP(:,1:NUP1)
                STREAMLINE(NSTREAMLINE).V(1:NDIMENSION,NUP1+1)=PTstart(1:NDIMENSION)
                STREAMLINE(NSTREAMLINE).V(1:NDIMENSION,2+NUP1:I+1+NUP1)=YSAV(:,1:I)
                
            ENDIF
        ENDIF
    ENDDO
  
    CALL STREAMLINE_PLOT()
    
end subroutine
    
SUBROUTINE STREAMLINE_STEP_SIZE()
    USE solverds
    USE MESHGEO
    USE function_plotter
    IMPLICIT NONE

    INTEGER::I,J
    REAL(8)::T1,STEP1

    DO I=1,NTET
        STEP1=1E10
        DO J=1,NDIMENSION
            T1=MAXVAL(ABS(NODALQ(TET(I).V(1:TET(I).NV),IVO(J))))
            IF(T1>1.E-14)  STEP1=MIN(STEP1,0.5D0*(TET(I).BBOX(2,J)-TET(I).BBOX(1,J))/T1)
        ENDDO
        TET(I).STEPSIZE=MAX(STEP1,0.01)
    END DO
ENDSUBROUTINE

SUBROUTINE derivs(T,PT,V)
    USE function_plotter
    USE ODE_SOLVER
    IMPLICIT NONE
    REAL(8),INTENT(IN)::T,PT(3)
    REAL(8),INTENT(OUT)::V(3)
    INTEGER::IEL
    REAL(8)::VAL1(100)    
    INTEGER,EXTERNAL::POINTlOC
    
    VAL1=0.D0
    iel=POINTlOC(PT)
    V=0.D0
    RKINFO.ISOUTOFRANGE=.FALSE.
    RKINFO.IEL=IEL
    IF(iel>0) then        
        call getval(PT,iel,val1)
        V(1:2)=VAL1(IVO(1:2))
        IF(IVO(3)>0) V(3)=VAL1(IVO(3))
        RKINFO.LASTIEL=IEL
    ELSE        
        RKINFO.ISOUTOFRANGE=.TRUE.
    endif    


END



SUBROUTINE GET_BC_INTERSECTION(PT1,PT2,IPT1,IPT2,ISINTERCEPT)
    USE solverds
    USE MESHGEO
    IMPLICIT NONE
    REAL(8),INTENT(IN)::PT1(3),PT2(3)
    REAL(8),INTENT(OUT)::IPT1(3),IPT2(3)
    INTEGER,INTENT(OUT)::ISINTERCEPT
    INTEGER::I,J
    
    
    IF(NDIMENSION==2) THEN
        DO I=1,NEDGE
            IF(EDGE(I).ENUM==1) THEN
                CALL GET_SEGINTERCECTION(NODE(EDGE(I).V(1)).COORD,NODE(EDGE(I).V(2)).COORD,&
                                           PT1,PT2,IPT1,IPT2,ISINTERCEPT,NDIMENSION)
                IF(ISINTERCEPT==1) EXIT
            ENDIF
        ENDDO
    ELSEIF(NDIMENSION==3) THEN
         DO I=1,NFACE
            IF(FACE(I).ENUM==1) THEN
                CALL intersect3D_SegmentPlane([PT1,PT2],[NODE(FACE(I).V(1)).COORD,&
                    NODE(FACE(I).V(2)).COORD,NODE(FACE(I).V(3)).COORD],&
                    IPT1,ISINTERCEPT)
                IF(ISINTERCEPT==1) EXIT
            ENDIF
        ENDDO   
    
    
    ENDIF
    
    
    
END SUBROUTINE

SUBROUTINE GET_SEGINTERCECTION(P1,P2,T1,T2,IPT1,IPT2,ISINTERCEPT,DIM)
     
    IMPLICIT NONE
    INTEGER,INTENT(IN)::DIM
    REAL(8),INTENT(IN)::P1(3),P2(3),T1(3),T2(3)
    REAL(8),INTENT(OUT)::IPT1(3),IPT2(3)
    INTEGER,INTENT(OUT)::ISINTERCEPT
    REAL(8)::U(3),V(3),W(3),D(3),D1(3),DU,DV,RT1,RT2,RT3,SI,TI,D2
    REAL(8),PARAMETER::SMALL_NUM=1.0D-8
    INTEGER,EXTERNAL::ISFRONT,ISACW
    REAL(8),EXTERNAL::PERP2D
    
    ISINTERCEPT=0
    
    IF(MIN(P1(1),P2(1))>MAX(T1(1),T2(1)).OR.MAX(P1(1),P2(1))<MIN(T1(1),T2(1))) RETURN
    IF(MIN(P1(2),P2(2))>MAX(T1(2),T2(2)).OR.MAX(P1(2),P2(2))<MIN(T1(2),T2(2))) RETURN
   
    IF(DIM>2) THEN
        IF(MIN(P1(3),P2(3))>MAX(T1(3),T2(3)).OR.MAX(P1(3),P2(3))<MIN(T1(3),T2(3))) RETURN
        IF(Isfront([P1,P2,T1,T2])<2) RETURN
    ENDIF
    
    
    U=P2-P1
    V=T2-T1
    W=P1-T1
    

    CALL r8vec_cross_3d ( U, V, D )
    
    ! test if  they are parallel (includes either being a point)
    if (NORM2(D) < SMALL_NUM) then           ! S1 and S2 are parallel
        CALL r8vec_cross_3d ( U, W, D )
        CALL r8vec_cross_3d ( V, W, D1 )
        if (NORM2(D) > SMALL_NUM .OR. NORM2(D1) > SMALL_NUM)  THEN
            return                    ! they are NOT collinear
        ENDIF
        ! they are collinear or degenerate
        ! check if they are degenerate  points
        du = NORM2(U);
        dv = NORM2(v);
        if (du<SMALL_NUM .AND. dv<SMALL_NUM) THEN            ! both segments are points
            if (NORM2(P1-T1)>SMALL_NUM) THEN        ! they are distinct  points
                ISINTERCEPT=0 
                return
            ENDIF
            IPT1 = P1;                 ! they are the same point
            ISINTERCEPT=1
            return 
        ENDIF
        
        if (du<SMALL_NUM) THEN                     ! S1 is a single point
            IF(isacw(T1(1),T1(2),T1(3),T2(1),T2(2),T2(3),&
                  P1(1),P1(2),P1(3))==2) THEN
                IPT1 = P1;                 
                ISINTERCEPT=1
                RETURN
            ELSE
                ISINTERCEPT=0
                RETURN               
            ENDIF           

        ENDIF
        
        if (dV<SMALL_NUM) THEN                     ! S2 is a single point
            IF(isacw(P1(1),P1(2),P1(3),P2(1),P2(2),P2(3),&
                  T1(1),T1(2),T1(3))==2) THEN
                IPT1 = T1;                 
                ISINTERCEPT=1
                RETURN
            ELSE
                ISINTERCEPT=0
                RETURN               
            ENDIF           

        ENDIF
        
        IF(ABS(V(1))>SMALL_NUM) THEN
            RT1=(P1(1)-T1(1))/V(1)
            RT2=(P2(1)-T1(1))/V(1)
        ELSEIF(ABS(V(2))>SMALL_NUM) THEN
            RT1=(P1(2)-T1(2))/V(2)
            RT2=(P2(2)-T1(2))/V(2)        
        ELSE
            RT1=(P1(3)-T1(3))/V(3)
            RT2=(P2(3)-T1(3))/V(3)       
        ENDIF
        
        IF(RT2<RT1) THEN
            RT3=RT1;RT1=RT2;RT2=RT3
        ENDIF
        

        if (Rt1 > 1.D0 .OR. Rt2 < 0.D0) THEN
            ISINTERCEPT=0
            RETURN       ! NO overlap
        ENDIF
        RT1=MAX(0.D0,RT1)
        RT2=MIN(RT2,1.D0)
        IF(ABS(RT1-RT2)<SMALL_NUM) THEN ! intersect is a point
            IPT1 = T1 +  RT1 * v;
            ISINTERCEPT=1
            return;
        ENDIF

        ! they overlap in a valid subsegment
        IPT1 =T1 + Rt1* v;
        IPT2 =T1 + Rt2* v;
        ISINTERCEPT=2
        return;
    ENDIF
    
    
    !CALL r8vec_cross_3d (U,[T2-P1], D1 )
    !transfor to 2D problem
    IF(ABS(D(3))>SMALL_NUM) THEN
        !PROJECT ON X-Y PLANE
        V(3)=0.D0;U(3)=0.D0;W(3)=0.D0
    ELSEIF(ABS(D(2))>SMALL_NUM) THEN
        !PROJECT ON X-Z PLANE
        V(2)=V(3);U(2)=U(3);W(2)=W(3)   
    ELSE
        !PROJECT ON Y-Z PLANE
        V(1:2)=V(2:3);U(1:2)=U(2:3);W(1:2)=W(2:3)         
    ENDIF
    ! the segments are skew and may intersect in a point
    ! get the intersect parameter for S1
    D2=perp2D(u(1:2),v(1:2))    
    sI = perp2D(v(1:2),w(1:2)) / D2;
    if (sI < 0 .OR. sI > 1)  then              ! no intersect with S1
        ISINTERCEPT=0
        return;
    endif
    ! get the intersect parameter for S2
    tI = perp2D(u(1:2),w(1:2)) / D2; 
    if (tI < 0 .OR. tI > 1)  then              ! no intersect with S2
        ISINTERCEPT=0
        return
    endif
    
    IPT1 = P1 + sI * (P2-P1);                ! compute S1 intersect point
    ISINTERCEPT=1
    return ;
    
    
                            
ENDSUBROUTINE

real(8) function perp2d(v1,v2)
    
    implicit none
    real(8),intent(in)::v1(2),v2(2)
    
    perp2d=v1(1)*v2(2)-v1(2)*v2(1)
    
end function




! intersect3D_SegmentPlane(): find the 3D intersection of a segment and a plane
!    Input:  S = a segment, and Pn = a plane = {Point V0;  Vector n;}
!    Output: *I0 = the intersect point (when it exists)
!    Return: 0 = disjoint (no intersection)
!            1 =  intersection in the unique point *I0
!            2 = the  segment lies in the plane
subroutine intersect3D_SegmentPlane( Seg,TRI,IPT,ISINTERCEPT )
    implicit none
    REAL(8),INTENT(IN)::SEG(3,2),TRI(3,3)
    REAL(8),INTENT(OUT)::IPT(3)
    INTEGER,INTENT(OUT)::ISINTERCEPT
    REAL(8),PARAMETER::SMALL_NUM=1.0D-8
    REAL(8)::U(3),W(3),NORMAL(3),D,N,SI
    INTEGER::I
    LOGICAL,EXTERNAL::PtInTri
    
    ISINTERCEPT=0
    DO I=1,3
        IF(MINVAL(SEG(I,:))>MAXVAL(TRI(I,:)).OR.MAXVAL(SEG(I,:))<MINVAL(TRI(I,:))) RETURN
    ENDDO
    
    U=SEG(:,2)-SEG(:,1)
    W=SEG(:,1)-TRI(:,1)
    
    CALL r8vec_cross_3d (TRI(:,2)-TRI(:,1), TRI(:,3)-TRI(:,1), NORMAL )
    D=DOT_PRODUCT(NORMAL,U)
    N=-DOT_PRODUCT(NORMAL,W)

    if (ABS(D) < SMALL_NUM) THEN           ! segment is parallel to plane
        if (ABS(N)<SMALL_NUM) THEN                     ! segment lies in plane
            ISINTERCEPT=2 !!to be improved
            return;
        else
            ISINTERCEPT=0
            return ;                    ! no intersection
        ENDIF
    ENDIF
    
    ! they are not parallel
    ! compute intersect param
    sI = N / D;
    if (sI < 0 .OR. sI > 1) THEN
        ISINTERCEPT=0
        return;                        ! no intersection
    ENDIF
    
    IPT = SEG(:,1) + sI * u;                  ! compute segment intersect point
    
    IF(PtInTri (IPT, TRI(:,1), TRI(:,2), TRI(:,3))) THEN
        ISINTERCEPT=1
        return;    
    ENDIF
    
end SUBROUTINE
!===================================================================