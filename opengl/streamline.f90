SUBROUTINE STREAMLINE_INI()
    use function_plotter
    IMPLICIT NONE
    
    !INITIALIZE IVO
    IVO=0    
    select case(VECTOR_PLOT_GROUP)    
    case(VECTOR_GROUP_DIS)
        IVO=[POSDATA.IDISX,POSDATA.IDISY,POSDATA.IDISZ]
    case(VECTOR_GROUP_SEEPAGE_VEC)       
        IVO=[POSDATA.IVX,POSDATA.IVY,POSDATA.IVZ]
    case(VECTOR_GROUP_SEEPAGE_GRAD)
        IVO=[POSDATA.IGRADX,POSDATA.IGRADY,POSDATA.IGRADZ]
    case(VECTOR_GROUP_SFR)
        IVO(1:2)=[POSDATA.ISFR_SFRX,POSDATA.ISFR_SFRY]
    end select
 
    
    
END SUBROUTINE    


SUBROUTINE STREAMLINE_PLOT()
    use function_plotter

    implicit none
    integer :: i,j,k,n1,DIRECTION1=1
    REAL(8)::DX1,DY1,DEG1,T1,SCALE1,PPM1,FS1,DEG2,MAX1
    CHARACTER(16)::STR1
    REAL(GLFLOAT)::COLOR1(4),COLOR2(4)

    call glDeleteLists(STREAMLINELIST, 1_glsizei)
    call reset_view    
    call glNewList(STREAMLINELIST, gl_compile_and_execute)

    call glPolygonMode(gl_front_and_back, gl_fill)
	call gldisable(GL_CULL_FACE);  
    !MAX1=MAXVAL(STREAMLINE.SF_SLOPE,MASK=STREAMLINE.SF_SLOPE<10)
    
    
    DO I=1,NSTREAMLINE

        IF((.NOT.STREAMLINE(I).SHOW).AND.STREAMLINE(I).ISINPUTSLIP==0) CYCLE !INPUT SLIPS ARE ALWAYS SHOWN 
        IF(STREAMLINE(I).NV<2) CYCLE
        CALL glLineWidth(2.0_glfloat)
        !IF(ISSTREAMLINESLOPE) THEN
        !    CALL get_rainbow(STREAMLINE(I).SF_SLOPE,STREAMLINE(SF_SLOPE(1)).SF_SLOPE,MAX1,COLOR1)
        !ELSE
        COLOR1=mycolor(:,BLUE)
        !ENDIF
       
        !INPUTSLIPS ARE ALWAYS PLOTTED.
        IF(ISSTREAMLINESLOPE.AND.STREAMLINE(I).ISINPUTSLIP==0) THEN        
            N1=MINLOC(ABS(SF_SLOPE(1:10)-I),DIM=1)
            IF(SF_SLOPE(N1)==I)  THEN
                COLOR1=mycolor(:,COLOR_TOP_TEN(N1))
                !CALL glcolor4fv()
                CALL glLineWidth(3.0_glfloat)            
            ENDIF
            !IF(.NOT.IS_SHOW_ALL_SLOPE) THEN                
            !    IF(IS_JUST_SHOW_TOP_TEN_SLOPE) THEN
            !        IF(SF_SLOPE(N1)/=I) THEN
            !            STREAMLINE(I).SHOW=.FALSE.
            !            CYCLE
            !        ENDIF
            !    ENDIF
            !    IF(IS_JUST_SHOW_THE_MINIMAL_ONE_SLOPE) THEN
            !        IF(SF_SLOPE(1)/=I) THEN
            !            STREAMLINE(I).SHOW=.FALSE.
            !            CYCLE
            !        ENDIF
            !    ENDIF                
            !ENDIF            
        ENDIF
        
        DIRECTION1=1 !SLIDE LEFE
        IF(ISSTREAMLINESLOPE) THEN
            IF((STREAMLINE(I).V(2,STREAMLINE(I).NV)-STREAMLINE(I).V(2,1))/(STREAMLINE(I).V(1,STREAMLINE(I).NV)-STREAMLINE(I).V(1,1))<0.D0) DIRECTION1=-1 !SLIDE RIGHT      
        ENDIF
        
         
        
	    call glBegin(gl_LINE_STRIP)
		DO J=1,STREAMLINE(I).NV
            COLOR2=COLOR1
            IF(ALLOCATED(STREAMLINE(I).PARA_SFCAL)) THEN
                IF(DIRECTION1*STREAMLINE(I).PARA_SFCAL(2,J)<0.D0) THEN
                    COLOR2=mycolor(:,WHITE)
                ENDIF
            ENDIF
            CALL glcolor4fv(COLOR2)
			call glvertex3dv(STREAMLINE(I).V(:,J)) 
		ENDDO
	    CALL GLEND()
        
        IF(ISSTREAMLINESLOPE) THEN
            DX1=STREAMLINE(I).VAL(POSDATA.IX,STREAMLINE(I).NV)-STREAMLINE(I).VAL(POSDATA.IX,STREAMLINE(I).NV-1)
            DY1=STREAMLINE(I).VAL(POSDATA.IY,STREAMLINE(I).NV)-STREAMLINE(I).VAL(POSDATA.IY,STREAMLINE(I).NV-1)

            IF(ABS(DX1)>1E-7) THEN
                DEG1=ATAN(DY1/DX1)/PI*180.
            ELSE
                DEG1=SIGN(PI/2.0,DY1)/PI*180.
            ENDIF
            
            IF(DEG1<0) DEG1=DEG1+180.

            DX1=STREAMLINE(I).VAL(POSDATA.IX,1)-STREAMLINE(I).VAL(POSDATA.IX,2)
            DY1=STREAMLINE(I).VAL(POSDATA.IY,1)-STREAMLINE(I).VAL(POSDATA.IY,2)
            !DEG1=ASIN(DY1/T1)/PI*180.0 
            IF(ABS(DX1)>1E-7) THEN
                DEG2=ATAN(DY1/DX1)/PI*180.
            ELSE
                DEG2=SIGN(PI/2.0,DY1)/PI*180.
            ENDIF
            
            IF(DEG2<0) DEG2=DEG2+180.
            
            
            WRITE(STR1,'(F7.3)') STREAMLINE(I).SF_SLOPE
            
            !PPM1=glutget(GLUT_SCREEN_WIDTH)/REAL(glutget(GLUT_SCREEN_WIDTH_MM)) !PIXELS PER MM
            !10 pound 
            FS1=glutStrokeWidth(GLUT_STROKE_ROMAN,ICHAR("X")) 
            SCALE1=POSDATA.MODELR/80/FS1*stroke_fontsize
            !scale1=PPM1*3.527777778/119.05*0.02*stroke_fontsize
            call glLineWidth(1.0_glfloat)
            
            CALL drawStrokeText(DEG1,&
                                STREAMLINE(I).VAL(POSDATA.IX,STREAMLINE(I).NV), &
                                STREAMLINE(I).VAL(POSDATA.IY,STREAMLINE(I).NV),0.0, &
                                scale1,&
                                STR1)
            CALL drawStrokeText(DEG2,&
                                STREAMLINE(I).VAL(POSDATA.IX,1), &
                                STREAMLINE(I).VAL(POSDATA.IY,1),0.0, &
                                scale1,&
                                STR1)                                
            !CALL output3D(STREAMLINE(I).VAL(POSDATA.IX,STREAMLINE(I).NV), &
            !              STREAMLINE(I).VAL(POSDATA.IY,STREAMLINE(I).NV),0.0, &
            !              STR1)                    
        ENDIF
        IF(SHOW_STREAMLINE_NODE) THEN
		    call glPointSize(4.0_glfloat)
		    call glbegin(gl_points)
		        DO J=1,STREAMLINE(I).NV
			        call glvertex3dv(STREAMLINE(I).V(:,J)) 
		        ENDDO			
		    call glend        
        ENDIF
    ENDDO
    CALL glLineWidth(1.0_glfloat)
    call glEndList

    
    call glutPostRedisplay



ENDSUBROUTINE


subroutine gen_new_streamline(PTstart)
	use function_plotter
	implicit none
	
	real(8),intent(in)::PTstart(3)
	
	CALL STREAMLINE_INI()
	call STREAMLINE_STEP_SIZE()    
    IF(NSTREAMLINE+1>MAXNSTREAMLINE) CALL ENLARGE_STREAMLINE()
	NSTREAMLINE=NSTREAMLINE+1
    STREAMLINE(nstreamline).PTstart=PTstart
	STREAMLINE(nstreamline).isinputslip=0
	call streamline_integration(nstreamline)
	
	CALL STREAMLINE_PLOT()
	
end subroutine

subroutine streamline_update()
	use function_plotter
	implicit none
	integer::i
	
	CALL STREAMLINE_INI()
	call STREAMLINE_STEP_SIZE()
	
	do i=1,nstreamline
        if(streamline(i).isinputslip==1) cycle
		call streamline_integration(i)		
	enddo
	
	CALL STREAMLINE_PLOT()
	
end subroutine

subroutine slopestability_streamline(islip)
    use function_plotter
    use quicksort
    implicit none
    integer,intent(in)::islip
    real(8)::pt1(3)
    integer::iel1,i,j,n1,n2
    REAL(8)::SS(3),T1,RAD1,DX1,DY1,SNT1(2),C1,PHI1,SIGMA_TF1,SIGMA_T1,T2,SFR1
    REAL(8)::RA1(NSTREAMLINE)
   
    IF(POSDATA.ISXX*POSDATA.ISYY*POSDATA.ISXY*POSDATA.IMC_C*POSDATA.IMC_PHI==0) THEN
        RETURN
    ELSE
        ISSTREAMLINESLOPE=.TRUE.
    ENDIF
    if(islip>0) then
        n1=islip;n2=islip
    else
        n1=1;n2=nstreamline
    endif
    
    do i=n1,n2
        SIGMA_TF1=0.D0;SIGMA_T1=0.D0        
        DO j=1,streamline(i).nv-1
            IF(ALLOCATED(STREAMLINE(I).PARA_SFCAL)) DEALLOCATE(STREAMLINE(I).PARA_SFCAL)
            ALLOCATE(STREAMLINE(I).PARA_SFCAL(8,streamline(i).nv))
            STREAMLINE(I).PARA_SFCAL(:,streamline(i).nv)=0.d0
            SS(1)=(STREAMLINE(I).VAL(POSDATA.ISXX,J)+STREAMLINE(I).VAL(POSDATA.ISXX,J+1))/2.0
            SS(2)=(STREAMLINE(I).VAL(POSDATA.ISYY,J)+STREAMLINE(I).VAL(POSDATA.ISYY,J+1))/2.0
		    SS(3)=(STREAMLINE(I).VAL(POSDATA.ISXY,J)+STREAMLINE(I).VAL(POSDATA.ISXY,J+1))/2.0
            C1=(STREAMLINE(I).VAL(POSDATA.IMC_C,J)+STREAMLINE(I).VAL(POSDATA.IMC_C,J+1))/2.0
            PHI1=(STREAMLINE(I).VAL(POSDATA.IMC_PHI,J)+STREAMLINE(I).VAL(POSDATA.IMC_PHI,J+1))/2.0
            SFR1=(STREAMLINE(I).VAL(POSDATA.ISFR,J)+STREAMLINE(I).VAL(POSDATA.ISFR,J+1))/2.0
            
            DX1=STREAMLINE(I).VAL(POSDATA.IX,J+1)-STREAMLINE(I).VAL(POSDATA.IX,J)
            DY1=STREAMLINE(I).VAL(POSDATA.IY,J+1)-STREAMLINE(I).VAL(POSDATA.IY,J)
            T1=(DX1**2+DY1**2)**0.5
            IF(ABS(DX1)>1E-7) THEN
                RAD1=ATAN(DY1/DX1)
            ELSE
                RAD1=SIGN(PI/2.0,DY1)
            ENDIF
            CALL stress_in_inclined_plane(SS,RAD1,SNT1)
            
            T2=(C1-MIN(SNT1(1),0.D0)*DTAN(PHI1/180.0*PI)) !TAUF
            IF(SNT1(1)<0.D0.AND.SFR1>=0.D0) THEN
            !IF(SNT1(1)<0.D0) THEN
                SIGMA_TF1=SIGMA_TF1+T2*T1
                SIGMA_T1=SIGMA_T1+SNT1(2)*T1
            ELSE
                T2=0.D0;SNT1(2)=0.D0
            ENDIF
            !SIGN,SIGT,RAD1,TAUF,DIS,C,PHI
            STREAMLINE(I).PARA_SFCAL(:,J)=[SNT1,RAD1,T2,T1,C1,PHI1,SFR1]
        ENDDO
        IF(ABS(SIGMA_T1)>1E-10) THEN
            STREAMLINE(I).SF_SLOPE=ABS(SIGMA_TF1/SIGMA_T1) 
        ELSE
            STREAMLINE(I).SF_SLOPE=HUGE(1.D0)
        ENDIF
        
        !IF(ISNAN(STREAMLINE(I).SF_SLOPE)) THEN
        !    PAUSE
        !ENDIF
        
        !INPUTSLIP 让其参在最后(实际上不参与排序)
        !IF(STREAMLINE(I).ISINPUTSLIP>0) THEN
        !    T1=1.D10
        !ELSE
        !    T1=STREAMLINE(I).SF_SLOPE
        !ENDIF
        !SF_SLOPE(1)=I MEANS STREAMLINE(I).SF_SLOPE IS MINMAL
        !SF_SLOPE(NSTREAMLINE)=I        
        !DO J=1, NSTREAMLINE-1
        !   !IF(STREAMLINE(SF_SLOPE(J)).ISINPUTSLIP>0) THEN
        !   !     T2=1.D10
        !   ! ELSE
        !   !     T2=STREAMLINE(SF_SLOPE(J)).SF_SLOPE
        !   ! ENDIF
        !    IF(STREAMLINE(SF_SLOPE(J)).SF_SLOPE>STREAMLINE(I).SF_SLOPE) THEN
        !        SF_SLOPE(NSTREAMLINE:J+1:-1)=SF_SLOPE(NSTREAMLINE-1:J:-1)
        !        SF_SLOPE(J)=I
        !        EXIT
        !    ENDIF
        !
        !ENDDO
	enddo
    
    
    RA1=STREAMLINE.SF_SLOPE
    SF_SLOPE(1:NSTREAMLINE)=[1:NSTREAMLINE]
    CALL quick_sort(RA1,SF_SLOPE)
    
    RETURN
endsubroutine

subroutine Filterlocalminimalslope(P1,P2)
    USE function_plotter
    IMPLICIT NONE
    REAL(8),INTENT(IN)::P1(3),P2(3)
    REAL(8)::V1(3),V2(3),IPT1(3),IPT2(3),T1
    INTEGER::I,J,ISINTERCEPT,N1,N2
    INTEGER,ALLOCATABLE::SELECTED1(:)
    
    ALLOCATE(SELECTED1(NSTREAMLINE))
    T1=1.D10;N1=0;SELECTED1=0;N2=0
    DO I=1,NSTREAMLINE
        IF(.NOT.STREAMLINE(I).SHOW) CYCLE
        DO j=1,streamline(i).nv-1
            V1=STREAMLINE(I).V(:,J);V2=STREAMLINE(I).V(:,J+1);
            CALL GET_SEGINTERCECTION(P1,P2,V1,V2,IPT1,IPT2,ISINTERCEPT,POSDATA.NDIM)
            IF(ISINTERCEPT>0) THEN
                N1=N1+1
                SELECTED1(N1)=I
                IF(STREAMLINE(I).SF_SLOPE<T1) THEN
                    T1=STREAMLINE(I).SF_SLOPE
                    N2=I
                ENDIF
                CYCLE
            ENDIF
        ENDDO
    ENDDO
    
    STREAMLINE(SELECTED1(1:N1)).SHOW=.FALSE.
    IF(N2>0) STREAMLINE(N2).SHOW=.TRUE.
    
    CALL STREAMLINE_PLOT()
    
    DEALLOCATE(SELECTED1)


END SUBROUTINE

SUBROUTINE stress_in_inclined_plane(ss,RAD,SNT)
!rad，angle with x axis,in rad.
!ss:sx,sy,sxy
!ss1:sn,st
    implicit none
    real(8),intent(in)::ss(3),RAD
    real(8),INTENT(OUT)::Snt(2)
    
    !Snt(1)=0.5*(ss(1)+ss(2))+0.5*(ss(1)-ss(2))*cos(2*RAD)+ss(3)*sin(2*RAD)
    !Snt(2)=-0.5*(ss(1)-ss(2))*sin(2*RAD)+ss(3)*cos(2*RAD) 
    Snt(1)=0.5*(ss(1)+ss(2))-0.5*(ss(1)-ss(2))*cos(2*RAD)-ss(3)*sin(2*RAD)
    Snt(2)=0.5*(ss(1)-ss(2))*sin(2*RAD)-ss(3)*cos(2*RAD)
    
endSUBROUTINE

SUBROUTINE SEARCH_MINIMAL_SF_SLOPE()
    use function_plotter
    use FindLocalEx1D
    implicit none
    INTEGER::I,J,K,IA1(NNLBC),NH1,IA2(NNLBC),IMSF1,N1,NSTREAMLINE1,IMSF2,N2
    LOGICAL::L1,L2
    REAL(8)::MSF1,PT1(3),MSF2,ASF1(NNLBC)
    REAL(8),ALLOCATABLE::MAXTEM1(:,:),MINTEM1(:,:)
    character(16)::str1
    
    NH1=0;IA1=0
    MSF1=1E10
    isPlotStreamLine=.TRUE.
    VECTOR_PLOT_GROUP=VECTOR_GROUP_SEEPAGE_VEC
    NSTREAMLINE1=NSTREAMLINE+1
    ISSTREAMLINESLOPE=.TRUE.
   
    info.color=red;info.qkey=.true.
    
    DO I=1,NNLBC 
        IF(POSDATA.IH_BC>0) THEN
            L1=(POSDATA.NODALQ(NODE_LOOP_BC(I),POSDATA.IH_BC,stepplot.istep)+4.0D0)<1E-7
            L2=POSDATA.NODALQ(NODE_LOOP_BC(I),POSDATA.IQ,stepplot.istep)>0.d0
            IF(L1.AND.L2) THEN                
             
                PT1(3)=0.0D0
                PT1(1:POSDATA.NDIM)=POSDATA.NODE(NODE_LOOP_BC(I)).COORD(1:POSDATA.NDIM)
                CALL gen_new_streamline(PT1)                
                NH1=NH1+1
                IA1(NH1)=I
                IA2(NH1)=NSTREAMLINE
                ASF1(NH1)=STREAMLINE(NSTREAMLINE).SF_SLOPE
                STREAMLINE(NSTREAMLINE).SHOW=.FALSE.
                IF(STREAMLINE(NSTREAMLINE).SF_SLOPE<MSF1) THEN
                    MSF1=STREAMLINE(NSTREAMLINE).SF_SLOPE
                    IMSF1=NSTREAMLINE
                    N2=I                    
                ENDIF
            ENDIF
            
        ELSE
            STOP 'THERE SEEMS TO BE NO SUCH A VARIABLE "H_BC".'
        ENDIF
    
    ENDDO
    
    !REFINE

    MSF2=MSF1;IMSF2=IMSF1
    DO K=1,2
        IF(K==1) THEN
            N1=N2-1
            IF(N1<1) N1=NNLBC
        ELSE
            N1=MOD(N2,NNLBC)+1   
        ENDIF
        L1=(POSDATA.NODALQ(NODE_LOOP_BC(N1),POSDATA.IH_BC,stepplot.istep)+4.0D0)<1E-7
        L2=POSDATA.NODALQ(NODE_LOOP_BC(N1),POSDATA.IQ,stepplot.istep)>0.d0
        IF(L1.AND.L2) THEN        
            DO J=2,10
                PT1=POSDATA.NODE(NODE_LOOP_BC(N2)).COORD+(J-1)/10.0*(POSDATA.NODE(NODE_LOOP_BC(N1)).COORD-POSDATA.NODE(NODE_LOOP_BC(N2)).COORD)
                call gen_new_streamline(PT1)
                STREAMLINE(NSTREAMLINE).SHOW=.FALSE.
                IF(STREAMLINE(NSTREAMLINE).SF_SLOPE<MSF2) THEN
                    MSF2=STREAMLINE(NSTREAMLINE).SF_SLOPE
                    IMSF2=NSTREAMLINE                  
                ENDIF
            ENDDO        
        ENDIF
    
    ENDDO
    
    STREAMLINE(IMSF2).SHOW=.TRUE.
    write(str1,'(f8.3)') msf2
    info.str='Search done...The MinimalFS='//trim(adjustl(str1))
    !call peakdet(MAXTEM1,MINTEM1,NH1,ASF1(1:NH1),0.01)
    !
    !DO I=1,SIZE(MINTEM1,DIM=1)
    !    STREAMLINE(IA2(INT(MINTEM1(1,I)))).ISLOCALSMALL=.TRUE.    
    !ENDDO
    
    RETURN
    

ENDSUBROUTINE

SUBROUTINE ShowLocalMinimalSlope()
    USE function_plotter
    USE FindLocalEx1D
    use quicksort
    implicit none
    INTEGER::I,IORDER1(NSTREAMLINE),N1
    real(8)::RA1(NSTREAMLINE)
    REAL(8),ALLOCATABLE::MAXTEM1(:,:),MINTEM1(:,:)
    
    RA1=STREAMLINE.VAL(POSDATA.IX,1)
    IORDER1=[1:NSTREAMLINE]
    CALL quick_sort(RA1,IORDER1)
    call peakdet(MAXTEM1,MINTEM1,NSTREAMLINE,STREAMLINE(IORDER1).SF_SLOPE,0.01)
    STREAMLINE(1:NSTREAMLINE).SHOW=.FALSE.
    STREAMLINE(1:NSTREAMLINE).ISLOCALSMALL=.FALSE.
    DO I=1,SIZE(MINTEM1,DIM=2)
        N1=IORDER1(INT(MINTEM1(1,I)))
        STREAMLINE(N1).ISLOCALSMALL=.TRUE.
        STREAMLINE(N1).SHOW=.TRUE.
    ENDDO
    
    

ENDSUBROUTINE

subroutine streamline_integration(istreamline)
    use function_plotter
    use ODE_SOLVER
    implicit none
    integer,intent(in)::istreamline  
    INTEGER::N1=3,IEL,I,J,NUP1
    INTEGER,PARAMETER::MAXSTEP1=10000
    REAL(8)::V1(3),V2(3),Y(3),EPS,YSCAL(3),Hdid,Hnext,T,Htry,direction1,IPT1(3)=0.D0,IPT2(3)=0.D0
    REAL(8)::YSAV(1:POSDATA.NDIM,MAXSTEP1),YSAV_UP(1:POSDATA.NDIM,MAXSTEP1),&
            VAL1(1:POSDATA.NVAR,0:MAXSTEP1), VAL2(1:POSDATA.NVAR,0:MAXSTEP1)
    REAL(8)::P1(3),P2(3)
    EXTERNAL::DERIVS
    INTEGER::ISINTERCEPT1
    
 
    DO J=1,2
        I=0;Y=0.D0
        y=STREAMLINE(ISTREAMLINE).PTstart(1:POSDATA.NDIM);t=0.d0;YSAV=0.D0;VAL1=0.D0
        IF(J==1) THEN
            DIRECTION1=-1.d0
        ELSE
            DIRECTION1=1.d0
        ENDIF
        DO WHILE(I<MAXSTEP1)        
           CALL derivs(T,y,V1) 
           VAL1(1:POSDATA.NVAR,I)=RKINFO.VAL(1:POSDATA.NVAR)
           IF(RKINFO.ISOUTOFRANGE.AND.I>0) then
                ISINTERCEPT1=0
                IF(I==1) THEN                
                    P1(1:POSDATA.NDIM)=STREAMLINE(ISTREAMLINE).PTstart(1:POSDATA.NDIM)                    
                ELSE
                    P1(1:POSDATA.NDIM)=YSAV(1:POSDATA.NDIM,I-1)
                ENDIF
                P2(1:POSDATA.NDIM)=YSAV(1:POSDATA.NDIM,I)
                IF(POSDATA.NDIM==2) THEN
                    P1(3)=0.D0;P2(3)=0.D0
                ENDIF
                IPT1=0.D0;IPT2=0.D0
                CALL GET_BC_INTERSECTION(P1,P2,IPT1,IPT2,ISINTERCEPT1)
                IF(ISINTERCEPT1==1) THEN
                    IF(NORM2(P1-IPT1)>1E-7) THEN
                        YSAV(:,I)=IPT1(1:POSDATA.NDIM)
                    ELSE
                        I=I-1
                    ENDIF
                    !IF(NORM2(IPT1)<1E-10) THEN
                    !    PAUSE
                    !ENDIF
                    call ProbeatPhyscialspace(IPT1,VAL1(1:POSDATA.NVAR,I),iel) 
                    !if(norm2(ipt1(1:2)-VAL1(1:2,i))>0.01) then
                    !    pause
                    !endif
                    !if(iel<=0) then
                    !    pause 'point out of mesh.sub=streamline_integration'
                    !endif
                ELSE
                    CALL GET_BC_INTERSECTION(P1,P2,IPT1,IPT2,ISINTERCEPT1)
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
            N1=POSDATA.NDIM;EPS=1.D-3;YSCAL=1.0D0
            CALL rkqs(y,V1,N1,T,Htry,eps,yscal,hdid,hnext,derivs)
            !IF(RKINFO.ISOUTOFRANGE) EXIT
            I=I+1
            YSAV(:,I)=Y(1:POSDATA.NDIM)
        
        ENDDO
        
        !IF(ALL(abs(VAL1(1:POSDATA.NVAR,i))<1e-7)) then
        !    pause
        !endif
        
        IF(I>=MAXSTEP1) THEN
            pause 'Too many steps in streamline'
        else
            IF(J==1) THEN
                NUP1=I
                YSAV_UP(:,1:NUP1)=YSAV(:,NUP1:1:-1)
                VAL2(1:POSDATA.NVAR,1:NUP1)=VAL1(1:POSDATA.NVAR,NUP1:1:-1)
            ELSE
                STREAMLINE(istreamline).NV=I+NUP1+1
                IF(ALLOCATED(STREAMLINE(istreamline).V)) DEALLOCATE(STREAMLINE(istreamline).V)                
                ALLOCATE(STREAMLINE(istreamline).V(3,STREAMLINE(istreamline).NV))
                IF(ALLOCATED(STREAMLINE(ISTREAMLINE).VAL)) DEALLOCATE(STREAMLINE(ISTREAMLINE).VAL)
                ALLOCATE(STREAMLINE(ISTREAMLINE).VAL(1:POSDATA.NVAR,STREAMLINE(istreamline).NV))
                STREAMLINE(ISTREAMLINE).VAL=0.D0
                STREAMLINE(istreamline).V(3,:)=0.d0
                STREAMLINE(istreamline).V(1:POSDATA.NDIM,1:NUP1)=YSAV_UP(:,1:NUP1)                
                STREAMLINE(istreamline).V(1:POSDATA.NDIM,NUP1+1)=STREAMLINE(ISTREAMLINE).PTstart(1:POSDATA.NDIM)
                STREAMLINE(istreamline).V(1:POSDATA.NDIM,2+NUP1:I+1+NUP1)=YSAV(:,1:I)
                STREAMLINE(ISTREAMLINE).VAL(:,1:NUP1)=VAL2(1:POSDATA.NVAR,1:NUP1)
                STREAMLINE(ISTREAMLINE).VAL(:,NUP1+1:NUP1+I+1)=VAL1(1:POSDATA.NVAR,0:I)
                CALL slopestability_streamline(ISTREAMLINE)

            ENDIF
        ENDIF
    ENDDO
  
    
    
end subroutine
    
SUBROUTINE STREAMLINE_STEP_SIZE()
    USE function_plotter
    IMPLICIT NONE

    INTEGER::I,J
    REAL(8)::T1,STEP1

    DO I=1,NTET
        STEP1=1E10
        DO J=1,POSDATA.NDIM
            T1=MAXVAL(ABS(POSDATA.NODALQ(TET(I).V(1:TET(I).NV),IVO(J),STEPPLOT.ISTEP)))
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
    INTEGER,EXTERNAL::POINTlOC,POINTlOC_BC
    INTEGER,SAVE::TRYIEL=0
    
    VAL1=0.D0
    !iel=POINTlOC(PT,TRYIEL)
    
    IEL=POINTlOC_BC(Pt,TRYIEL)
    TRYIEL=IEL
    V=0.D0
    RKINFO.ISOUTOFRANGE=.FALSE.
    RKINFO.IEL=IEL
    IF(iel>0) then        
        call getval(PT,iel,val1)
        RKINFO.VAL(1:POSDATA.NVAR)=val1(1:POSDATA.NVAR)
        V(1:2)=VAL1(IVO(1:2))
        IF(IVO(3)>0) V(3)=VAL1(IVO(3))
        RKINFO.LASTIEL=IEL
    ELSE
        RKINFO.VAL(1:POSDATA.NVAR)=0.D0
        RKINFO.ISOUTOFRANGE=.TRUE.
    endif    


END

SUBROUTINE OUT_SHOWN_STREAMLINE()
    USE function_plotter
    IMPLICIT NONE
    INTEGER::I,J,EF
    
    PRINT *, 'SELECT TO FILE TO SAVE THE STREAMLINE DATA...'
    
    open(20,file='',status='UNKNOWN',iostat=EF)
    IF(EF/=0) RETURN
    WRITE(20,10) (TRIM(POSDATA.OUTVAR(I).NAME),I=1,POSDATA.NVAR)
        
    
    DO I=1,NSTREAMLINE
       IF((.NOT.STREAMLINE(I).SHOW).OR.STREAMLINE(I).NV<2) CYCLE
            
        DO J=1,STREAMLINE(I).NV 
            IF(ALLOCATED(STREAMLINE(I).PARA_SFCAL)) THEN
                WRITE(20,20) I,J,STREAMLINE(I).SF_SLOPE,STREAMLINE(I).VAL(1:POSDATA.NVAR,J),STREAMLINE(I).PARA_SFCAL(:,J)
            ELSE
                WRITE(20,20) I,J,STREAMLINE(I).SF_SLOPE,STREAMLINE(I).VAL(1:POSDATA.NVAR,J),0,0,0,0,0,0,0,0
            ENDIF
            IF(J==STREAMLINE(I).NV) WRITE(20,'(I5)') I
        ENDDO        
    
    END DO
    
    CLOSE(20)
        
    PRINT *, 'OUTDATA DONE!'
    

    
10  FORMAT('ILINE',1X,'  INODE',1X,22X,'FOS',1X,<POSDATA.NVAR>(A24,1X),&
        1X,'SLIPSEG_SN',1X,'SLIPSEG_TAU',1X,'SLIPSEG_ANGLE_IN_RAD',1X,'SLIPSEG_TAUF',&
        1X,'SLIPSEG_DIS',1X,'SLIPSEG_C',1X,'SLIPSEG_PHI',1X,'SLIPSEG_SFR')
20  FORMAT(I5,1X,I7,1X,<POSDATA.NVAR+9>(EN24.15,1X))
         
30  FORMAT(I5,1X,I7,1X,<POSDATA.NDIM>(EN24.15,1X),'*THE POINT IS OUT OF MODEL ZONE.*')

ENDSUBROUTINE

SUBROUTINE GET_BC_INTERSECTION(PT1,PT2,IPT1,IPT2,ISINTERCEPT)
    !USE solverds
    USE MESHGEO
    IMPLICIT NONE
    REAL(8),INTENT(IN)::PT1(3),PT2(3)
    REAL(8),INTENT(OUT)::IPT1(3),IPT2(3)
    INTEGER,INTENT(OUT)::ISINTERCEPT
    INTEGER::I,J
    LOGICAL::TOF1
    
    
    IF(POSDATA.NDIM==2) THEN
        DO I=1,NEDGE
			IF(EDGE(I).ISDEAD==1) CYCLE
            TOF1=.FALSE.
            IF(EDGE(I).ENUM==1) THEN
                TOF1=.TRUE.
            ELSEIF(EDGE(I).ENUM==2) THEN
                TOF1=TET(EDGE(I).ELEMENT(1)).ISDEAD==1.OR.TET(EDGE(I).ELEMENT(2)).ISDEAD==1 
            ENDIF            
            IF(TOF1) THEN
                CALL GET_SEGINTERCECTION(POSDATA.NODE(EDGE(I).V(1)).COORD,POSDATA.NODE(EDGE(I).V(2)).COORD,&
                                           PT1,PT2,IPT1,IPT2,ISINTERCEPT,POSDATA.NDIM)
                IF(ISINTERCEPT==1) EXIT
            ENDIF
        ENDDO
    ELSEIF(POSDATA.NDIM==3) THEN
         DO I=1,NFACE
			IF(FACE(I).ISDEAD==1) CYCLE
            TOF1=.FALSE.
            IF(FACE(I).ENUM==1) THEN
                TOF1=.TRUE.
            ELSEIF(FACE(I).ENUM==2) THEN
                TOF1=TET(ABS(FACE(I).ELEMENT(1))).ISDEAD==1.OR.TET(ABS(FACE(I).ELEMENT(2))).ISDEAD==1 
            ENDIF
            IF(TOF1) THEN
                CALL intersect3D_SegmentPlane([PT1,PT2],[POSDATA.NODE(FACE(I).V(1)).COORD,&
                    POSDATA.NODE(FACE(I).V(2)).COORD,POSDATA.NODE(FACE(I).V(3)).COORD],&
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
