
Module DS_SlopeStability
    integer,parameter,private::double=kind(1.0D0)
	integer::SS_PWM=0	
	!=0,water pressure calculated from the input waterlevel line.(default case)
    !=1,water pressure interpolated from the finite element seepage calculation.
	INTEGER::MAXNIGC=100
 
    
    
    real(double),allocatable::Xslice(:),Yslice(:,:)
    integer::nXslice=0
    
    real(double),ALLOCATABLE::InsectGC(:,:) !圆形滑弧与地质线的交点
    INTEGER::NIGC=0
    
    type slope_load_tydef
        INTEGER::dof,dim
        real(double)::v=0.D0
    endtype
    
    type slice_line_tydef
        integer::NV=0,IRTPOINT=0,MATB=0!IRTP>0,表明此节点处于一竖直坡面线中，该坡面线的坡脚点为rtpoint(irtpoing)
		!MATB=滑弧交点所处的材料。
		
        INTEGER,ALLOCATABLE::MAT(:)
		
        REAL(DOUBLE)::WATERLEVEL=-1.0D6
        REAL(DOUBLE)::VB(2)=0.D0 !THE Y AND TOTAL VERTICAL STRESS AT THE BOTTOM OF A SLICE SURFACE.        
        REAL(DOUBLE),ALLOCATABLE::V(:,:) !V(1,),Y;V(2,):SIGMAT(竖向总应力);   
        !TYPE(slope_load_tydef),ALLOCATABLE::LOAD(:) !APPLIED DISTRIBUTED SURFACE LOAD(WATER PRESSURE EXCLUDED.).
    endtype
	TYPE(slice_line_tydef),ALLOCATABLE::sliceLine(:),SLICELINE_C(:) 
    INTEGER::NSLICELINE=0,NSLICELINE_C=0
	
	TYPE SLICE_SURFACE_LOAD_TYDEF
		REAL(DOUBLE)::QX=0.D0,QY=0.D0,M=0.D0,XQ=0.D0,YQ=0.D0 
        !SURFACE FORCES AND COORDINATE AT THE SLOPE SURFACE.M IS MOMENT AROUND THE MIDPOINT(CONTERCLOCK IS POSITIVE.)
	ENDTYPE
	TYPE(SLICE_SURFACE_LOAD_TYDEF),ALLOCATABLE::SSLOAD(:)
	INTEGER::NSSLOAD=0
    
    TYPE SLICE_TYPDEF
		INTEGER::NSL,NSR  !SLICE LINE ID 
		REAL(DOUBLE)::YBL,YBR !SLICE BOTTOM Y COORDINATES.
		REAL(DOUBLE)::BETA,ALPHA,THETA !坡面、坡底与水平面的夹角,浸润面与水平面的夹角。
		REAL(DOUBLE)::WX=0.D0,WY=0.D0,XW=0.0D0,YW=0.0D0 !WEIGHT AND COORDINATES OF SLICE  IN X AND Y DIRECTIONS.
		REAL(DOUBLE)::ZLX=0.D0,ZLY=0.D0,XZL=0.D0,YZL=0.D0 !INTERSLICE FORCES AND THE CORRESPONDING COORDINATS ON THE LEFT SLICE LINE.
		REAL(DOUBLE)::ZRX=0.D0,ZRY=0.D0,XZR=0.D0,YZR=0.D0  !INTERSLICE FORCES AND THE CORRESPONDING COORDINATS ON THE RIGHT SLICE LINE.
		REAL(DOUBLE)::NX=0.D0,NY=0.D0,XN=0.D0,YN=0.D0 !EFFECTIVE FORCES AND COORDINATE IN GLOBAL  AT THE BOTTOM. 
		REAL(DOUBLE)::U=0.D0,UX=0.D0,UY=0.D0,XU=0.D0,YU=0.D0 !PORE WATER FORCES AND COORDINATE AT THE BOTTOM.
		REAL(DOUBLE)::NA=0.D0,TA=0.0D0,TAC=0.D0 !EFFECTIVE  FORCES AND COORDINATE AT THE BOTTOM (ROTATED IN ALPHA, X' PARELLEL TO THE BOTTOM ).
		!TA=MOBLIZED SHEAR FORCE ALONG THE BOTTOM DIRECTION
		!TAC=SHEAR FORCES CAPACITY (AVAILABLE) ALONG THE BOTTOM DIRECTION.	
		REAL(DOUBLE)::QX=0.D0,QY=0.D0,XQ=0.D0,YQ=0.D0,M=0.D0 !SURFACE FORCES AND COORDINATE AT THE SLOPE SURFACE.
			
	ENDTYPE
	TYPE(SLICE_TYPDEF),ALLOCATABLE::SLICE(:)
    INTEGER::NSLICE=0

    type slope_typdef
          INTEGER::SLOPEMethod=2 !BISHOP,BY DEFAULT. =0, CAL BY ALL.
          !BISHOP = 2,ORDINARY=1,SPENCER=3,JANBU=4,GLE=5
          INTEGER::SLIPSHAPE=1 !=1,CIRCULAR,=2,NONCIRCULAR
          INTEGER::OPTMETHOD=1 !=1,GRID;2;MONTECARLO
          INTEGER::SLIDEDIRECTION=1  !-1, LEFT; 1,RIGHT
          INTEGER::NTRIALS=0
          REAL(DOUBLE)::SLICEWIDTH=1.0D0,UWIDTH=1.0D0 !土条宽度，边坡计算厚度（平面假定）
          REAL(DOUBLE)::KX=0.D0,KY=0.0D0 !SEISMIC COEFFICIENT TO ACCOUNT FOR A DYNAMIC HORIZONTAL FORCE.
          REAL(DOUBLE)::XMIN_MC=1.D20,XMAX_MC=-1.D20
          LOGICAL::ISYDWZ=.FALSE. !INDICATE WHETHER THE YDOWNWARDZONE IS ACTIVATED.
          REAL(DOUBLE)::YDOWNWARDZONE=0.D0,MU=0.45 !IF Y=A, THE FAILUE SURFACE DIRECTION IS SWITCH TO ANOTHER(THERE ARE TWO OPTIMAL DIRETION) WHEN THE NODE IN THE ZONE Y>A 
          REAL(DOUBLE)::TOEZONE(3)=0.D0 !AX+BY+C<=0,为坡脚区，A,B,C由输入的两点给出。如果TOEZONE(:)=0.D0,则表坡脚区没定义。
          INTEGER::NBCPA=0,IBCPA=0,NNODE=0 
          REAL(DOUBLE),ALLOCATABLE::NODE(:,:),BCENTRY(:,:),BCEXIT(:,:) !FOR ENTRY AND EXIT,(XL,XR,XV,A,B,C). FOR NODE, NODE(2,NNODE) X,Y,
    endtype
    TYPE(slope_typdef)::SLOPEPARAMETER
    
    CONTAINS
	
	REAL(DOUBLE) FUNCTION GLEVEL(ISLINE)
		USE GEOMETRY
		IMPLICIT NONE
		INTEGER,INTENT(IN)::ISLINE
		GLEVEL=SLICELINE(ISLINE).V(1,1)
		IF(SLICELINE(ISLINE).IRTPOINT>0) GLEVEL=KPOINT(2,RTPOINT(SLICELINE(ISLINE).IRTPOINT))
	ENDFUNCTION
	
End Module
    
     
subroutine Gen_slope_model()
    USE Geometry
    use DS_SlopeStability
    implicit none
    
    call GenSliceLine()
    
    call SliceGrid(xslice,Yslice,nXslice,nGeoline)
    
    call SLICELINEDATA(Yslice,nXslice,sliceLine,NSLICELINE)
	
	call GenSurfaceLoad(0,0)
    
    CALL checkdata()
    
    call SlopeSearch()
    
    endsubroutine
    
SUBROUTINE SLOPESEARCH()
    USE DS_SlopeStability
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
    INCLUDE 'CONSTANT.H'    
    REAL(DPN)::XEXIT,YEXIT,XENTRY,YENTRY
    
    SELECT CASE(SLOPEPARAMETER.OPTMETHOD)
    CASE(GRID)
        
    CASE(MONTECARLO)
        CALL MONTECARLOSEARCH()
        
    ENDSELECT
ENDSUBROUTINE

SUBROUTINE MONTECARLOSEARCH()
    
    USE Geometry
    USE DS_SlopeStability
    USE IFPORT
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
    INTEGER::I,J,K,SL_EXIT1,SL_ENTRY1
    REAL(DPN)::XEXIT,YEXIT,XENTRY,YENTRY,XD,YD,XE,YE,WATERLEVEL1
    
    
    IF(ABS(SLOPEPARAMETER.XMIN_MC-1.D20)<1.D-6) SLOPEPARAMETER.XMIN_MC=MINVAL(KPOINT(1,:))
    IF(ABS(SLOPEPARAMETER.XMAX_MC+1.D20)<1.D-6) SLOPEPARAMETER.XMAX_MC=MAXVAL(KPOINT(1,:))
    
    XEXIT=SLOPEPARAMETER.XMIN_MC+(SLOPEPARAMETER.XMAX_MC-SLOPEPARAMETER.XMIN_MC)/2.0*DRAND(1)
    CALL FIND_ENTRY_AND_EXIT(SL_EXIT1,XEXIT,YEXIT,WATERLEVEL1)
	SLICELINE(0).NV=1;ALLOCATE(SLICELINE(0).V(2,1))
    XSLICE(0)=XEXIT;SLICELINE(0).V(1,1)=YEXIT;SLICELINE(0).V(2,1)=0.D0
	SLICELINE(0).VB(1)=YEXIT;SLICELINE(0).VB(2)=0.D0
        
    XENTRY=SLOPEPARAMETER.XMAX_MC-(SLOPEPARAMETER.XMAX_MC-SLOPEPARAMETER.XMIN_MC)/2.0*DRAND(0)
    CALL FIND_ENTRY_AND_EXIT(SL_ENTRY1,XENTRY,YENTRY,WATERLEVEL1)
	SLICELINE(NSLICELINE+1).NV=1;ALLOCATE(SLICELINE(NSLICELINE+1).V(2,1))
    XSLICE(NSLICELINE+1)=XENTRY;SLICELINE(NSLICELINE+1).V(1,1)=YENTRY;SLICELINE(NSLICELINE+1).V(2,1)=0.D0
    SLICELINE(NSLICELINE+1).VB(1)=YENTRY;SLICELINE(NSLICELINE+1).VB(2)=0.D0
	
    CALL FIND_D_AND_E_MONTECARLO(XEXIT,YEXIT,XENTRY,YENTRY,XD,YD,XE,YE)
    
    CALL FIND_MINFACTOR_ON_DE(XEXIT,YEXIT,XENTRY,YENTRY,XD,YD,XE,YE)
    
ENDSUBROUTINE


SUBROUTINE FIND_MINFACTOR_ON_DE(XEXIT,YEXIT,XENTRY,YENTRY,XD,YD,XE,YE)    
    IMPLICIT NONE
	INCLUDE 'DOUBLE.H'
	REAL(DPN),INTENT(IN)::XEXIT,YEXIT,XENTRY,YENTRY,XD,YD,XE,YE
	REAL(DPN)::XC1,YC1,R1
	INTEGER::NS,NE
	
	XC1=(XD+XE)/2.D0
	YC1=(XD+XE)/2.D0
	DO WHILE(.TRUE.)
		R1=((XEXIT-XC1)**2+(YEXIT-YC1)**2)**0.5D0
		CALL CIRCLE_SLICE(XC1,YC1,R1,NS,NE)
		IF(NS/=0) THEN
			CALL GEN_SLICE(XEXIT,YEXIT,XENTRY,YENTRY,NS,NE)
		ENDIF
	ENDDO
	
    
ENDSUBROUTINE 

SUBROUTINE GEN_SLICE(XEXIT,YEXIT,XENTRY,YENTRY,NS,NE)
	USE DS_SlopeStability
	IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
	INTEGER,INTENT(IN)::NS,NE
	REAL(DPN),INTENT(IN)::XEXIT,YEXIT,XENTRY,YENTRY
		
	INTEGER::I,J,LS1,RS1,IFLAG1=1
	NSLICE=0
	DO I=2,NSLICELINE
		IF(XSLICE(I)<=XEXIT) CYCLE
		IF(XSLICE(I)>XENTRY) EXIT
		IF(ABS(SLICELINE(I).VB(1)-ERRORVALUE)<1.D-6 .OR. (SLICELINE(I).VB(1)>=GLEVEL(I))) CYCLE
		NSLICE=NSLICE+1		
		SLICE(NSLICE).NSL=I-1
		IF(XSLICE(I-1)<XEXIT) THEN
			SLICE(NSLICE).NSL=0
			IFLAG1=1
			CALL GenSurfaceLoad(IFLAG1,I)
		ENDIF
		SLICE(NSLICE).NSR=I
		
	ENDDO
	IF(XSLICE(SLICE(NSLICE).NSR)<XENTRY) THEN
		NSLICE=NSLICE+1
		SLICE(NSLICE).NSL=SLICE(NSLICE-1).NSR
		SLICE(NSLICE).NSR=NXSLICE+1
		IFLAG1=2
		CALL GenSurfaceLoad(IFLAG1,SLICE(NSLICE-1).NSR)
	ENDIF

	
ENDSUBROUTINE

SUBROUTINE INTERSLICEFORCE_CAL()
    USE DS_SlopeStability
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H' 
    INCLUDE 'CONSTANT.H'
    
    
    SLICE.ZLX=0.D0;SLICE.ZLY=0.D0;SLICE.XZL=0.D0;SLICE.YZL=0.D0
    SLICE.ZRX=0.D0;SLICE.ZRY=0.D0;SLICE.XZR=0.D0;SLICE.YZR=0.D0
    
	SELECT CASE(SLOPEPARAMETER.SLOPEMethod)
        CASE(BISHOP)
            
        CASE(SPENCER)
            
        CASE(JANBU)
        
        CASE(GLE)
	
	END SELECT    
    

ENDSUBROUTINE
    
SUBROUTINE SLICEINITIALIZE(ISLICE)
	USE DS_SlopeStability
	IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
	INTEGER,INTENT(IN)::ISLICE
    INTEGER::NSL1,NSR1,N1
    REAL(DPN)::XY1(2,4),T1,WIDTH1,G2L1(4,4)

    !TYPE SLICE_TYPDEF
	!	INTEGER::NSL,NSR  !SLICE LINE ID 
	!	REAL(DOUBLE)::YBL,YBR !SLICE BOTTOM Y COORDINATES.
	!	REAL(DOUBLE)::BETA,ALPHA，THETA !坡面、坡底与水平面的夹角
	!	REAL(DOUBLE)::WX=0.D0,WY=0.D0,XW=0.0D0,YW=0.0D0 !TOTAL WEIGHT AND COORDINATES OF SLICE  IN X AND Y DIRECTIONS.
	!	REAL(DOUBLE)::ZLX=0.D0,ZLY=0.D0,XZL=0.D0,YZL=0.D0 !INTERSLICE FORCES AND THE CORRESPONDING COORDINATS ON THE LEFT SLICE LINE.
	!	REAL(DOUBLE)::ZRX=0.D0,ZRY=0.D0,XZR=0.D0,YZR=0.D0  !INTERSLICE FORCES AND THE CORRESPONDING COORDINATS ON THE RIGHT SLICE LINE.
	!	REAL(DOUBLE)::N=0.D0,NX=0.D0,NY=0.D0,XN=0.D0,YN=0.D0 !EFFECTIVE NORMAL FORCES AND COORDINATE AT THE BOTTOM. 
	!	REAL(DOUBLE)::U=0.0D0,UX=0.D0,UY=0.D0,XU=0.D0,YU=0.D0 !PORE WATER FORCES AND COORDINATE AT THE BOTTOM.
	!	REAL(DOUBLE)::SM=0.D0,SMX=0.D0,SMY=0.D0,XSM=0.D0,YSM=0.D0 !MOBILIZED FORCES AND COORDINATE AT THE BOTTOM.
	!	REAL(DOUBLE)::QX=0.D0,QY=0.D0,XQ=0.D0,YQ=0.D0 !SURFACE FORCES AND COORDINATE AT THE SLOPE SURFACE.
	!ENDTYPE	
	
	NSL1=SLICE(ISLICE).NSL
    NSR1=SLICE(ISLICE).NSR
    XY1(1,1)=XSLICE(NSL1)
    XY1(2,1)=SLICELINE(NSL1).V(1,1)
    XY1(1,2)=XSLICE(NSL1)
    XY1(2,2)=SLICELINE(NSL1).VB(1)
    XY1(1,3)=XSLICE(NSR1)
    XY1(2,3)=SLICELINE(NSR1).VB(1)
    XY1(1,4)=XSLICE(NSR1)
    XY1(2,4)=GLEVEL(NSR1)
    
    WIDTH1=ABS(XSLICE(NSR1)-XSLICE(NSL1))
    
	SLICE(ISLICE).YBL= XY1(2,2)
    SLICE(ISLICE).YBR=XY1(2,3)
    T1=((XY1(1,1)-XY1(1,4))**2+(XY1(2,1)-XY1(2,4))**2)**0.5D0
    SLICE(ISLICE).BETA=DACOS((XY1(1,4)-XY1(1,1))/T1)*DSIGN(1.D0,XY1(2,4)-XY1(2,1))
    T1=((XY1(1,3)-XY1(1,2))**2+(XY1(2,3)-XY1(2,2))**2)**0.5D0
    SLICE(ISLICE).ALPHA=DACOS((XY1(1,3)-XY1(1,2))/T1)*DSIGN(1.D0,XY1(2,3)-XY1(2,2))
    
    SLICE(ISLICE).WY=(SLICELINE(NSL1).VB(2)+SLICELINE(NSR1).VB(2))/2.D0*(-1.D0+SLOPEPARAMETER.KY)*WIDTH1
	SLICE(ISLICE).WX=(SLICELINE(NSL1).VB(2)+SLICELINE(NSR1).VB(2))*SLOPEPARAMETER.KX/2.D0*WIDTH1
    SLICE(ISLICE).XW=(XSLICE(NSR1)+XSLICE(NSL1))/2.d0 !assumpation
	SLICE(ISLICE).YW=SUM(XY1(2,1:4))/4.d0  !ASSUMPATION
	
	SLICE(ISLICE).XU=SLICE(ISLICE).XW;SLICE(ISLICE).YU=(SLICE(ISLICE).YBL+SLICE(ISLICE).YBR)/2.0D0
	T1=((XY1(1,1)-XY1(1,4))**2+(SLICELINE(NSL1).WATERLEVEL-SLICELINE(NSR1).WATERLEVEL)**2)**0.5D0
	SLICE(ISLICE).THETA=DACOS((XY1(1,4)-XY1(1,1))/T1)*DSIGN(1.D0,SLICELINE(NSR1).WATERLEVEL-SLICELINE(NSL1).WATERLEVEL)
	T1=MAX((SLICELINE(NSL1).WATERLEVEL+SLICELINE(NSR1).WATERLEVEL)/2.D0-SLICE(ISLICE).YU,0.D0)*GA
	T1=T1*(SLICE(ISLICE).THETA)**2
	SLICE(ISLICE).UY=T1*WIDTH1 !ALWAYS POSITIVE.
	SLICE(ISLICE).UX=T1*(SLICE(ISLICE).YBL-SLICE(ISLICE).YBR)
	SLICE(ISLICE).U=(SLICE(ISLICE).UY**2+SLICE(ISLICE).UX**2)**0.5D0
	
	N1=NSL1
	IF(NSR1==NSLICELINE+1) N1=NSSLOAD+1 !THE LAST ONE
	SLICE(ISLICE).QX=SSLOAD(N1).QX
	SLICE(ISLICE).QY=SSLOAD(N1).QY
	SLICE(ISLICE).XQ=SSLOAD(N1).XQ
	SLICE(ISLICE).YQ=SSLOAD(N1).YQ	
	SLICE(ISLICE).M=SSLOAD(N1).M
	
 
	
	SLICE(ISLICE).NX=-(SLICE(ISLICE).WX+SLICE(ISLICE).QX+SLICE(ISLICE).ZLX+SLICE(ISLICE).ZRX)-SLICE(ISLICE).UX
    SLICE(ISLICE).NY=-(SLICE(ISLICE).WY+SLICE(ISLICE).QY+SLICE(ISLICE).ZLY+SLICE(ISLICE).ZRY)-SLICE(ISLICE).UY
	
	G2L1(1,1)=DCOS(SLICE(ISLICE).ALPHA);G2L1(1,2)=DSIN(SLICE(ISLICE).ALPHA)
	G2L1(2,1)=-G2L1(1,2);G2L1(2,2)=G2L1(1,1)
	SLICE(ISLICE).NA=G2L1(2,1)*SLICE(ISLICE).NX+G2L1(2,2)*SLICE(ISLICE).NY
	SLICE(ISLICE).TA=G2L1(1,1)*SLICE(ISLICE).NX+G2L1(1,2)*SLICE(ISLICE).NY
	
	
	
	
	
ENDSUBROUTINE

SUBROUTINE CIRCLE_SLICE(XC,YC,RC,NS,NE)
    USE DS_SlopeStability
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
	INTEGER,INTENT(OUT)::NS,NE
    REAL(DPN),INTENT(IN)::XC,YC,RC
    REAL(DPN)::X1,Y1,X2,Y2,XI(2),YI(2)
    REAL(DPN),EXTERNAL::MultiSegInterpolate
	INTEGER::I,J,NI,ISLICE1(NSLICELINE)
    
	ISLICE1=0
	NS=0;NE=0
    DO I=1,NSLICELINE
        X1=XSLICE(I)
        Y1=SLICELINE(I).V(1,1)
        X2=X1
		Y2=SLICELINE(I).V(1,SLICELINE(I).NV)
		
        CALL INSECT_SEG_CIRCLE(XC,YC,RC,X1,Y1,X2,Y2,XI,YI,NI)
        
		IF(NI==0) THEN
			SLICELINE(I).VB(1)=ERRORVALUE
			
		ELSEIF(NI==1) THEN
			IF(NS==0) NS=I
			NE=I
			ISLICE1(I)=1
			SLICELINE(I).VB(1)=YI(1)
            SLICELINE(I).VB(2)=MultiSegInterpolate(SLICELINE(I).V(1,1:SLICELINE(I).NV),SLICELINE(I).V(2,1:SLICELINE(I).NV),SLICELINE(I).NV,YI(1))
			!matb
			DO J=1,SLICELINE(I).NV
				SLICELINE(I).MATB=SLICELINE(I).MAT(MAX(J-1,1))
				IF(YI(1)>SLICELINE(I).V(1,J)) EXIT
			ENDDO
			
		ELSE
			STOP "UNEXPECTED ERROR.THE SLICELINE THE TWO INTERSECTIONS WITH ONE CIRCLE. SUB=CIRCLE_SLICE."
		ENDIF
		
    ENDDO
	
	!假定滑弧是连续的，既排除一个滑弧切出多个小边坡的情况。
	!对于一个滑弧切出多个小边坡的情况，可人为调整滑弧出入点的位置进行分析。
	IF(NS/=0.AND.(SUM(ISLICE1)/=NE-NS+1)) NS=0
	
	
	
  
    
ENDSUBROUTINE
    
SUBROUTINE FIND_ENTRY_AND_EXIT(NI,XI,YI,WLEVEL)
    USE DS_SlopeStability
    IMPLICIT NONE
    include 'double.h'    
    REAL(DPN),INTENT(IN)::XI
    REAL(DPN),INTENT(OUT)::YI,WLEVEL
    INTEGER,INTENT(OUT)::NI
    INTEGER::I,J
    
    NI=0
    
    DO I=2,NXSLICE
        IF(XI<=XSLICE(I)) THEN
			
            CALL SegInterpolate(XSLICE(I-1),SLICELINE(I-1).V(1,1),XSLICE(I),GLEVEL(I),XI,YI)
            IF(YI==ERRORVALUE) STOP "ERRORVALUE.SUB=FIND_ENTRY_AND_EXIT"
            CALL SegInterpolate(XSLICE(I-1),SLICELINE(I-1).WATERLEVEL,XSLICE(I),SLICELINE(I).WATERLEVEL,XI,WLEVEL)
            NI=I
            EXIT
        ENDIF
    ENDDO  
    
ENDSUBROUTINE
    
SUBROUTINE FIND_D_AND_E_MONTECARLO(XEXIT,YEXIT,XENTRY,YENTRY,XD,YD,XE,YE)
    IMPLICIT NONE
    INCLUDE "DOUBLE.H"
    REAL(DPN),INTENT(IN)::XEXIT,YEXIT,XENTRY,YENTRY
    REAL(DPN),INTENT(OUT)::XD,YD,XE,YE
    REAL(DPN)::XC1,YC1,SLOPE1
    
    XC1=(XEXIT+XENTRY)/2.0D0;YC1=(YEXIT+YENTRY)/2.0D0
    XD=XEXIT;YE=YENTRY
    SLOPE1=(YENTRY-YEXIT)/(XENTRY-XEXIT)
    IF(ABS(SLOPE1)>1D-6) THEN
        SLOPE1=-1./SLOPE1
        YD=SLOPE1*(XD-XC1)+YC1
        XE=(YE-YC1)/SLOPE1+XC1
    ELSE
        STOP "YENTRY=YEIXT. SUB=FIND_D_AND_E_MONTECARLO"
    ENDIF
        
    
ENDSUBROUTINE
subroutine GenSliceLine()

    use ifport
    use Geometry
    use DS_SlopeStability
    USE quicksort
    implicit none
    
    include 'double.h'
    
    integer::i,j,n1,n2,IminX1,JmaxX1,sizeX1,sizeX2,N3,N4
    real(DPN),allocatable::X1(:),X2(:)
    INTEGER,ALLOCATABLE::ORDER1(:)
    
    allocate(x1,source=kpoint(1,1:nkp))
    sizeX1=size(x1)
    !ALLOCATE(ORDER1(NKP))
    
    !ORDER1=[1:NKP]
    CALL quick_sort(X1)
    !call sortqq(loc(x1),sizeX1,SRT$REAL8)
    !if(sizeX1/=size(x1)) stop "Error in sortqq.sub=GenSliceLine1"
    
    n1=int((maxX-minX)/SLOPEPARAMETER.SLICEWIDTH)
    
    Iminx1=int(minX)
    JmaxX1=int(maxX)+1
    n1=2*n1
    allocate(x2(n1))
    x2=0
    sizeX2=1
    x2(1)=Iminx1
    do while (x2(sizeX2)<JmaxX1)
       x2(sizeX2+1)=x2(sizeX2)+SLOPEPARAMETER.SLICEWIDTH
       sizeX2=sizeX2+1
       if(sizeX2>n1) then
            stop "SizeError.sub=GenSliceLine1."
       endif       
    enddo
    
    if(sizeX2+sizex1<=n1) then
        x2(sizeX2+1:sizeX2+sizeX1)=x1
        sizeX2=sizeX2+sizeX1
        n2=sizeX2
        !IF(ALLOCATED(ORDER1)) DEALLOCATE(ORDER1)
        !ALLOCATE(ORDER1(SIZEX2))
        !ORDER1=[1:SIZEX2:1]
        CALL quick_sort(X2)
        !call sortqq(loc(x2),n2,SRT$REAL8)
        !if(sizeX2/=n2) stop "Error in sortqq.sub=GenSliceLine2."
        !remove diplicated element
        j=1
        do i=2,sizeX2            
            if(abs((X2(i)-X2(j))>1e-6)) then
                j=j+1
                x2(j)=x2(i)
            endif
        enddo
		
		N3=minloc(x2,1,x2>=minX)
		N4=maxloc(x2,1,x2<=maxX)
		nXslice=N4-N3+1
        allocate(Xslice(0:NXSLICE+1))
        XSLICE(1:NXSLICE)=X2(N3:N4)
        
        deallocate(X1,X2)
        NSLICELINE=NXSLICE
        ALLOCATE(SLICELINE(0:NSLICELINE+1))
        allocate(YSlice(NGEOLINE,0:nXslice+1))
        YSLICE=0.D0
		ALLOCATE(SLICE(NXSLICE-1))
		ALLOCATE(SSLOAD(0:NSLICELINE))
		NSSLOAD=NSLICELINE-1
    else
        stop "SizeError.sub=GenSliceLine2."
    endif
    
    
end subroutine
    
   

SUBROUTINE SLICELINEDATA(YSLE,NYSLE,SLEDATA,NSLEDATA)
    USE DS_SlopeStability
    USE Geometry
    USE solverds
    IMPLICIT NONE

    INTEGER,INTENT(IN)::NYSLE,NSLEDATA
    REAL(DPN),INTENT(IN)::YSLE(NGEOLINE,NYSLE)
    TYPE(slice_line_tydef)::SLEDATA(NSLEDATA)
    REAL(DPN),EXTERNAL::MultiSegInterpolate
    INTEGER::I,J,K,MAT1(100),N1,ERR1,ISFOUND=0
    REAL(DPN)::Y1(100),T1
    
    DO I=1,NSLEDATA
        Y1(1:NGEOLINE)=YSLE(:,I)
        FORALL(J=1:NGEOLINE) MAT1(J)=geoline(j).mat
        !SORT,Z2A
        DO J=1,NGEOLINE-1
            DO K=J+1,NGEOLINE
                IF(Y1(K)>Y1(J).OR.(ABS(Y1(K)-Y1(J))<1.D-6 .AND. MAT1(K)<MAT1(J))) THEN 
				!当同一高程的各点，把材料号大的放在后面，既同高程各点，下层材料取决于此点材料号大的材料。
                    T1=Y1(J)
                    Y1(J)=Y1(K)
                    Y1(K)=T1
                    N1=MAT1(J)
                    MAT1(J)=MAT1(K)
                    MAT1(K)=N1
                ENDIF                                
            ENDDO            
        ENDDO
        
        SLEDATA(I).NV=COUNT(Y1(1:NGEOLINE)>ERRORVALUE)
        ALLOCATE(SLEDATA(I).MAT(SLEDATA(I).NV),SLEDATA(I).V(2,SLEDATA(I).NV),STAT=ERR1)
        SLEDATA(I).MAT=MAT1(1:SLEDATA(I).NV)
        SLEDATA(I).V=0.D0
        SLEDATA(I).V(1,1:SLEDATA(I).NV)=Y1(1:SLEDATA(I).NV)
        DO J=2,SLEDATA(I).NV
			T1=MATERIAL(SLEDATA(I).MAT(J-1)).PROPERTY(3)
			SLEDATA(I).V(2,J)=SLEDATA(I).V(2,J-1)+(SLEDATA(I).V(1,J-1)-SLEDATA(I).V(1,J))*T1
        ENDDO     
		
		
        !waterlevel
		if(SS_PWM==0) then
			SLEDATA(I).WATERLEVEL=MultiSegInterpolate(kpoint(1,waterlevel.point),kpoint(2,waterlevel.point),waterlevel.npoint,xslice(i))
			!ISFOUND=0
			!do j=1,SLEDATA(I).NV
			!	if(SLEDATA(i).mat(j)==matwater) then
			!		SLEDATA(i).waterlevel=SLEDATA(I).V(1,j)
			!	ELSE
			!		IF(ISFOUND==0) THEN
			!			SLEDATA(I).GROUND=SLEDATA(I).V(1,j)
			!			ISFOUND=1
			!		ENDIF
			!	endif
            !enddo
            
            !TOTAL VERTICAL STRESS
            !SLEDATA(I).V(2,1)=MAX((SLEDATA(i).waterlevel-SLEDATA(I).V(1,1))*GA,0.0D0)        
                   
            
		elseif(SS_PWM==1) then
			print *, "To Be Improved. Interpolate from FE Seepage Calculation."
			stop
		else
			print *, "PoreWater Pressure is not considered."
        endif

		!CALL SURFACELOAD_SLOPE(I)
		CALL ISRTPOINT(I,SLEDATA(I).IRTPOINT)
		
        
    ENDDO
        
    
ENDSUBROUTINE 


SUBROUTINE ISRTPOINT(ISLICELINE,IRTP)
	USE GEOMETRY
	USE DS_SLOPESTABILITY
	IMPLICIT NONE
	INTEGER,INTENT(IN)::ISLICELINE
	INTEGER,INTENT(OUT)::IRTP
	INTEGER::I
	
	IRTP=0
	DO I=1,NRTPOINT
		IF(ABS(XSLICE(ISLICELINE)-KPOINT(1,RTPOINT(I)))<1.D-6) THEN
			IRTP=I
			RETURN
		ENDIF
	ENDDO
ENDSUBROUTINE



SUBROUTINE  GenSurfaceLoad(IFLAG,ISLICELINE)
	USE DS_SlopeStability
	USE ExcaDS
    USE solverds
	IMPLICIT NONE
	INTEGER,INTENT(IN)::IFLAG,ISLICELINE
	REAL(DPN)::XI,YI,T1,T2,QP1(4)=0.0D0,XL1,XR1,GL1,GR1
    REAL(DPN),EXTERNAL::MultiSegInterpolate	
	INTEGER::I,J,K,N1,N2,N3
	
	SELECT CASE(IFLAG)
		CASE(1) !EXIT POINT
			N2=0;N3=0
		CASE(2) !ENTRY POINT
			N2=NSSLOAD+1;N3=NSSLOAD+1;
		CASE DEFAULT
			N2=1;N3=NSSLOAD
	END SELECT
	
	DO I=N2,N3
		SSLOAD(I).QX=0.D0;SSLOAD(I).QY=0.D0;SSLOAD(I).M=0.D0
		!均布线荷载，假定其作用点在土条中间
		SELECT CASE(IFLAG)
			CASE(1) !EXIT POINT
				XL1=XSLICE(0);XR1=XSLICE(ISLICELINE)
				GL1=SLICELINE(0).V(1,1);GR1=GLEVEL(ISLICELINE)
			CASE(2) !ENTRY POINT
				XL1=XSLICE(ISLICELINE);XR1=XSLICE(NSLICELINE+1)
				GL1=SLICELINE(ISLICELINE).V(1,1);GR1=GLEVEL(NSLICELINE+1)
			CASE DEFAULT
				XL1=XSLICE(I);XR1=XSLICE(I+1)
				GL1=SLICELINE(I).V(1,1);GR1=GLEVEL(I+1)
		END SELECT
		
		SSLOAD(I).XQ=(XL1+XR1)/2.0D0		
		SSLOAD(I).YQ=(GL1+GR1)/2.0D0
		DO J=1,NACTION
			IF(ACTION(J).TYPE/=0.OR.ACTION(J).NDIM/=1) CYCLE
			
			IF(ACTION(J).DOF==1) THEN
				N1=2
				T2=SSLOAD(I).YQ
			ELSEIF(ACTION(J).DOF==2) THEN
				N1=1
				T2=SSLOAD(I).XQ
			ENDIF
			T1=MultiSegInterpolate(KPOINT(N1,ACTION(J).KPOINT(1:ACTION(J).NKP)),ACTION(J).VALUE(1:ACTION(J).NKP),ACTION(J).NKP,T2)
			IF(ABS(T1-ERRORVALUE)>1.D-6) THEN
				!边坡计算厚度假定为1.0d0
				IF(ACTION(J).DOF==1) SSLOAD(I).QX=SSLOAD(I).QX+T1*ABS(GL1-GR1)*SLOPEPARAMETER.UWIDTH !!!!
			ELSE
				IF(ACTION(J).DOF==2) SSLOAD(I).QY=SSLOAD(I).QY+T1*ABS(XL1+XR1)*SLOPEPARAMETER.UWIDTH !!!!
			ENDIF
        ENDDO
        
        !SURFACE WATER PRESSURE 
        T1=(MAX((SLICELINE(I).WATERLEVEL-GL1),0.D0)+MAX((SLICELINE(I+1).WATERLEVEL-GR1),0.D0))/2.D0*GA
		SSLOAD(I).QX=SSLOAD(I).QX+T1*(GR1-GL1)*SLOPEPARAMETER.UWIDTH  
        SSLOAD(I).QY=SSLOAD(I).QY-T1*ABS(XR1-XL1)*SLOPEPARAMETER.UWIDTH !向下
		
		!集中荷载\
		QP1=0.D0
		 
		IF(I==1) THEN
			XI=XL1;YI=GL1
			DO J=1,NACTION
				IF(ACTION(J).TYPE/=0.OR.ACTION(J).NDIM/=0) CYCLE
				DO K=1,ACTION(J).NKP
					IF(ABS(XI-KPOINT(1,ACTION(J).KPOINT(K)))>1D-6) CYCLE
					IF(ABS(YI-KPOINT(2,ACTION(J).KPOINT(K)))>1D-6) CYCLE
					IF(ACTION(J).DOF==1) THEN
						QP1(1)=QP1(1)+ACTION(J).VALUE(K)
					ELSEIF(ACTION(J).DOF==2) THEN
						QP1(2)=QP1(2)+ACTION(J).VALUE(K)
					ENDIF
					EXIT
				ENDDO
			ENDDO
		ELSE
			QP1(1)=QP1(3)
			QP1(2)=QP1(4)
		ENDIF
		
		XI=XR1;YI=GR1
		DO J=1,NACTION
			IF(ACTION(J).TYPE/=0.OR.ACTION(J).NDIM/=0) CYCLE
			DO K=1,ACTION(J).NKP
				IF(ABS(XI-KPOINT(1,ACTION(J).KPOINT(K)))>1D-6) CYCLE
				IF(ABS(YI-KPOINT(2,ACTION(J).KPOINT(K)))>1D-6) CYCLE
				IF(ACTION(J).DOF==1) THEN
					QP1(3)=QP1(3)+ACTION(J).VALUE(K)
				ELSEIF(ACTION(J).DOF==2) THEN
					QP1(4)=QP1(4)+ACTION(J).VALUE(K)
				ENDIF
				EXIT
			ENDDO
		ENDDO		
		
		SSLOAD(I).QX=SSLOAD(I).QX+(QP1(1)+QP1(3))/2.0D0
		SSLOAD(I).QY=SSLOAD(I).QY+(QP1(2)+QP1(4))/2.0D0
		SSLOAD(I).M=SSLOAD(I).M+QP1(1)/2.0d0*((GL1+GR1)/2.0d0-GL1)
		SSLOAD(I).M=SSLOAD(I).M+QP1(3)/2.0d0*((GL1+GR1)/2.0d0-GR1)
		SSLOAD(I).M=SSLOAD(I).M-QP1(2)/2.0d0*((XL1+XR1)/2.0d0-XL1)
		SSLOAD(I).M=SSLOAD(I).M-QP1(4)/2.0d0*((XL1+XR1)/2.0d0-XR1)
		
        
		
	ENDDO

	
ENDSUBROUTINE
	
!SUBROUTINE  SURFACELOAD_SLOPE(ISL)
!!CALCULATE APPLIED SURFACE DISTRIBUTED LOADS AT ISLICE LOCATION IN HORIZONTAL AND VERTICAL DIRECTIONS. 
!!HEREIN, WATER PRESSURE IS NOT INCLUDED. IT WILL BE HANDLE IN A DIFFERENT WAY.
!    USE DS_SlopeStability 
!    USE ExcaDS
!    IMPLICIT NONE
!    INCLUDE 'DOUBLE.H'
!    INTEGER,INTENT(IN)::ISL
!    INTEGER::I,N1,NAT1
!    REAL(DPN)::XI,YI,T1,T2
!    REAL(DPN),EXTERNAL::MultiSegInterpolate
!    TYPE(slope_load_tydef)::AT1(10)
!    
!    XI=XSLICE(ISL)
!    YI=SLICELINE(ISL).V(1,1)
!    NAT1=0
!    DO I=1,NACTION
!        IF(ACTION(I).TYPE/=0) CYCLE
!        IF(ACTION(I).DOF==1) THEN
!            N1=2
!            T2=YI
!        ELSE
!            N1=1
!            T2=XI
!        ENDIF
!        T1=MultiSegInterpolate(KPOINT(N1,ACTION(I).KPOINT(1:ACTION(I).NKP)),ACTION(I).VALUE(1:ACTION(I).NKP),ACTION(I).NKP,T2)
!        IF(ABS(T1-ERRORVALUE)>1.D-6) THEN
!            NAT1=NAT1+1
!            IF(NAT1>10) STOP 'SIZEERROR IN SURFACELOAD_SLOPE.'
!            AT1(NAT1).V=T1
!            AT1(NAT1).DIM=ACTION(I).NDIM
!            AT1(NAT1).DOF=ACTION(I).DOF
!        ENDIF      
!        
!    ENDDO
!	
!    SLICELINE(ISL).NLOAD=NAT1
!    ALLOCATE(SLICELINE(ISL).LOAD,SOURCE=AT1(1:NAT1))
!    
!    
!ENDSUBROUTINE
    
    
    
SUBROUTINE SliceGrid(XSLE,YSLE,nXSLE,nYSLE)
!FIND INTERSECTION POINTS (YSEL(NGEOLINE,NXSLE)) BETWEEN GEOLINE(NGEOLINE) AND SLICE LINES（XSLE(NXSLE)）  

!Assume: only one intersection between one line and one sliceline.

    use Geometry
    use DS_SlopeStability
    implicit none
    include 'double.h'
    INTEGER,INTENT(IN)::NXSLE,NYSLE
    REAL(DPN),INTENT(IN)::XSLE(NXSLE)
    REAL(DPN),INTENT(OUT)::YSLE(NYSLE,NXSLE) !NYSEL=NGEOLINE
    
    integer::i,j,k,N1
    real(DPN)::X1,Y1,X2,Y2,YI1
    
    !allocate(YSlice(NGEOLINE,nXslice))
    YSLE=ERRORVALUE
    
    do i=1,nGEOline
        
        !Assumption of GeoLine：1)points must be ordered from a2z. 2) no reverse is allowed.
        do j=1,GEOline(i).npoint-1
            X1=kpoint(1,GEOline(i).point(j))
            Y1=kpoint(2,GEOline(i).point(j))
            X2=kpoint(1,GEOline(i).point(j+1))
            Y2=kpoint(2,GEOline(i).point(j+1))
            IF(abs(X1-X2)<1E-6) THEN
				
				CYCLE
			ENDIF
            if(x2<x1) THEN
                PRINT *, "INPUTERROR. No Reverse is allowed in Gline(I). SUB=SliceGrid. I=",I
                STOP
            ENDIF  
            K=1 
            DO WHILE(k<=NXSLE)
               CALL SegInterpolate(X1,Y1,X2,Y2,XSLE(K),YI1) 
               IF(YI1/=ERRORVALUE) THEN
                   YSLE(I,K)=YI1                   
                   !EXIT     
               endIF
               K=K+1
            end do 
        enddo        
    end do
    
    !INTERSECT IN WATERLEVE LINE   

END SUBROUTINE

    !圆弧与地质线的交点
SUBROUTINE CIRCLE_GEOLINE(XC,YC,RC)
    USE DS_SlopeStability
    USE Geometry
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
    REAL(DPN),INTENT(IN)::XC,YC,RC
    INTEGER::I,J,K,N1,NORDER1(MAXNIGC),NI1
    
    REAL(DPN)::X1,Y1,X2,Y2,T1,T2,XI1(2),YI1(2),TA1(MAXNIGC)
    
	ALLOCATE(InsectGC(2,MAXNIGC))
	INSECTGC=0.D0
	
    do i=1,nGEOline
        !Assumption of GeoLine：1)points must be ordered from a2z. 2) no reverse is allowed.
        do j=1,GEOline(i).npoint-1
            X1=kpoint(1,GEOline(i).point(j))
            Y1=kpoint(2,GEOline(i).point(j))
            X2=kpoint(1,GEOline(i).point(j+1))
            Y2=kpoint(2,GEOline(i).point(j+1))

            !if(abs(X1-X2)<1E-6) CYCLE
            if(x2<x1) THEN
                PRINT *, "INPUTERROR. No Reverse is allowed in Gline(I). SUB=SliceGrid. I=",I
                STOP
            ENDIF

			CALL INSECT_SEG_CIRCLE(XC,YC,RC,X1,Y1,X2,Y2,XI1,YI1,NI1)
			DO K=1,NI1
				NIGC=NIGC+1
				IF(NIGC>MAXNIGC) STOP "ERROR IN ARRAY SIZES.InsectGC,SUB=CIRCLE_GEOLINE."
				InsectGC(1,NIGC)=XI1(K)
				InsectGC(2,NIGC)=YI1(K)
			ENDDO           
        enddo        
    end do
	
	!REMOVED DUPLICATED(X) ELEMENT IN INSECTGC.
	!SORT INSECTGC A2Z BY X 	
	CALL SORT_A2Z(InsectGC(1,:),NIGC,NORDER1)
	TA1=INSECTGC(2,:)
	DO I=1,NIGC
		INSECTGC(2,I)=TA1(NORDER1(I))
	ENDDO
    J=1
	DO I=2,NIGC
		IF(ABS(INSECTGC(1,J)-INSECTGC(1,I))>1D-6) THEN
			J=J+1
			INSECTGC(:,J)=INSECTGC(:,I)
		ENDIF
	ENDDO
	NIGC=J	
    
    !DEALLOCATE(TA1,NORDER1)
    
END SUBROUTINE

SUBROUTINE INSECT_SEG_CIRCLE(XC,YC,RC,X1,Y1,X2,Y2,XI,YI,NI)
!find the intersection point (xi(2),yi(2)) between
!a line segment(x1,y1),(x2,y2) and 
!a circle (xc,yc,Rc)
!if NI=0,1,2, there is 0,1,and 2 intersections.
	IMPLICIT NONE
	INCLUDE 'DOUBLE.H'
	REAL(DPN),INTENT(IN)::XC,YC,RC,X1,Y1,X2,Y2
	REAL(DPN),INTENT(OUT)::XI(2),YI(2)
	INTEGER,INTENT(OUT)::NI
	
	REAL(DPN)::T1,T2,S1,YC1,A1,B1,C1,T3
	INTEGER::I
	
	XI=0.D0;YI=0.D0
	NI=0
	
	IF(ABS(X1-X2)>1E-6) THEN
		S1=(Y2-Y1)/(X2-X1)
		YC1=S1*X1-Y1+YC
		A1=1+S1**2
		B1=-(2*XC+2*S1*YC1)
		C1=XC**2+YC1**2-RC**2
		T1=(B1**2-4*A1*C1)
		IF(T1>0.D0) THEN
			T1=T1**0.5
			XI(1)=(-B1+T1)/(2*A1)
			XI(2)=(-B1-T1)/(2*A1)
			DO I=1,2
				IF(MIN(X1,X2)<=XI(I).AND.MAX(X1,X2)>=XI(I)) THEN
					NI=NI+1
					YI(NI)=S1*(XI(I)-X1)+Y1
				ENDIF
			ENDDO
		ENDIF
	ELSE
		T1=RC**2-(X1-XC)**2
		IF(T1>0.D0) THEN
			T1=T1**0.5
			YI(1)=YC+T1
			YI(2)=YC-T1
			DO I=1,2
				IF(MIN(Y1,Y2)<=YI(I).AND.MAX(Y1,Y2)>=YI(I)) THEN
					NI=NI+1
					XI(NI)=X1 !x1=x2					
				ENDIF
			ENDDO			
		ENDIF
	ENDIF
	
	
ENDSUBROUTINE
    

    
    

subroutine SegInterpolate(X1,Y1,X2,Y2,Xi,Yi)
    implicit none
    include 'double.h'
    real(DPN),intent(in)::X1,Y1,X2,Y2,Xi
    real(DPN),intent(out)::Yi
    REAL(DPN)::T1
    
    IF(XI<MIN(X1,X2).OR.XI>MAX(X1,X2)) THEN
        YI=ERRORVALUE
    ELSE
        T1=X1-X2
        IF(ABS(T1)>1E-6) THEN
            YI=(Y1-Y2)/T1*(XI-X2)+Y2
        ELSE
            YI=Y1
        ENDIF
        
    ENDIF
    
    
endsubroutine


function MultiSegInterpolate(x,y,nx,xi)
!x,y must be in order.
!if
	implicit none
	include 'double.h'
    integer,intent(in)::nx
	real(DPN),intent(in)::x(nx),y(nx),xi
	real(DPN)::MultiSegInterpolate,t1
	integer::i
    
    MultiSegInterpolate=0
    
    if(nx==1.AND.ABS(XI-X(1))<1.D-6) then
       MultiSegInterpolate=y(1)
       return
    endif
    do i=1,nx-1
        if((xi<=x(i+1).and.xi>=x(i)).or.(xi<=x(i).and.xi>=x(i+1))) then
	        t1=x(i+1)-x(i)
	        if(abs(t1)<1e-7) then
		        print *, "Warning! 分母=0,function=MultiSegInterpolate()"
		        MultiSegInterpolate=(y(i)+y(i+1))/2.0d0
	        else
		        MultiSegInterpolate=(y(i+1)-y(i))/(t1)*(xi-x(i))+y(i)
            endif
            return
        endif
    enddo    
    
endfunction

SUBROUTINE SORT_A2Z(X,NX,NORDER)
!SORT X(NX) IN A2Z ORDER. THE NEW ORDER IS STORED IN NORDER(NX).
	IMPLICIT NONE
	INCLUDE "DOUBLE.H"
	INTEGER,INTENT(IN)::NX
	REAL(DPN),INTENT(IN OUT)::X(NX)
	INTEGER,INTENT(OUT)::NORDER(NX)
	
	INTEGER::I,J,N1
    REAL(DPN)::T1
	
	DO I=1,NX
		NORDER(I)=I
	ENDDO
	
	DO I=1,NX-1		
		DO J=I+1,NX
			IF(X(J)<X(I)) THEN
				N1=NORDER(I)				
				NORDER(I)=NORDER(J)
				NORDER(J)=N1
				T1=X(I)
				X(I)=X(J)
				X(J)=T1				
			ENDIF
		ENDDO
	ENDDO
	
ENDSUBROUTINE
    
SUBROUTINE SLOPEMODEL_PLT(xmin,ymin,xmax,ymax,WXY)
    USE Geometry
    USE DS_SlopeStability
    USE ExcaDS
    USE IFQWIN
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
    REAL(DPN),INTENT(IN)::xmin,ymin,xmax,ymax
    TYPE (wxycoord),INTENT(IN)::wxy
    TYPE (wxycoord)::WXY1
    TYPE (windowconfig):: thescreen 
	common /c2/ thescreen
    TYPE(xycoord)::POLY1(100)
    INTEGER(4)::STATUS
    INTEGER::I,J,K,N1,N2
    REAL(DPN)::X1,Y1,SCALE1
    
    DO I=1,NGEOLINE
        CALL SETLINEWIDTHQQ (3)
        call setc(GEOLINE(I).mat)
        DO J=1,GEOLINE(I).NPOINT-1
            N1=GEOLINE(I).POINT(J)            
            CALL moveto_w(KPOINT(1,N1),KPOINT(2,N1),wxy)
            N2=GEOLINE(I).POINT(J+1)
            status=lineto_w(KPOINT(1,N2),KPOINT(2,N2))            
        ENDDO
    ENDDO
    
    DO I=1,NSLICELINE
        CALL SETLINEWIDTHQQ (1)
        X1=XSLICE(I)
        DO J=1,SLICELINE(I).NV-1
            Y1=SLICELINE(I).V(1,J)
            CALL moveto_w(X1,Y1,wxy)
            call setc(SLICELINE(I).mat(J))
            Y1=SLICELINE(I).V(1,J+1)
            status=lineto_w(X1,Y1)  
        ENDDO
    ENDDO
        
    DO I=1,NACTION
        
        
            
            DO J=1,ACTION(I).NKP
                IF(ACTION(I).NDIM==1) SCALE1=40.D0
                IF(ACTION(I).NDIM==0) SCALE1=20.D0    
                CALL GETVIEWCOORD_W(KPOINT(1,ACTION(I).KPOINT(J)),KPOINT(2,ACTION(I).KPOINT(J)),POLY1(J))
                IF(ACTION(I).DOF==2) THEN 
                    POLY1(2*ACTION(I).NKP-J+1).XCOORD=POLY1(J).XCOORD
                    POLY1(2*ACTION(I).NKP-J+1).YCOORD=POLY1(J).YCOORD+INT(ACTION(I).VALUE(J)/MAXACTION*THESCREEN.NUMYPIXELS/SCALE1)
                 ENDIF
                 IF(ACTION(I).DOF==1) THEN
                
                
                    POLY1(2*ACTION(I).NKP-J+1).YCOORD=POLY1(J).YCOORD
                    POLY1(2*ACTION(I).NKP-J+1).XCOORD=POLY1(J).XCOORD-INT(ACTION(I).VALUE(J)/MAXACTION*THESCREEN.NUMYPIXELS/SCALE1)
                ENDIF

                IF(ACTION(I).NDIM==1.AND.J==ACTION(I).NKP) THEN 
                    IF(ACTION(I).DOF==2) THEN
                        call setc(4)
                        CALL SETFILLMASK(VFILLMASK)
                    ELSE
                        call setc(2)
                        CALL SETFILLMASK(HFILLMASK)
                    ENDIF
                    
                    status=POLYGON($GFILLINTERIOR,POLY1,INT2(2*ACTION(I).NKP))
                    CALL SETFILLMASK(FILLMASK)
                
                ELSEIF(ACTION(I).NDIM==0) THEN 
                    
                    
                    CALL GETWINDOWCOORD(POLY1(2*ACTION(I).NKP-J+1).XCOORD,POLY1(2*ACTION(I).NKP-J+1).YCOORD,WXY1) 
                    call setc(1)
                    CALL SETFILLMASK(FILLMASK)
                    
                    CALL ARROW_PLOT(WXY1.WX,WXY1.WY,KPOINT(1,ACTION(I).KPOINT(J)),KPOINT(2,ACTION(I).KPOINT(J)),WXY)
                ENDIF
        ENDDO

         
    ENDDO
    
    
ENDSUBROUTINE

SUBROUTINE ARROW_PLOT(X1,Y1,X2,Y2,WXY) 
    USE IFQWIN
    IMPLICIT NONE
    INCLUDE 'DOUBLE.H'
    REAL(DPN),INTENT(IN)::X1,Y1,X2,Y2    
    TYPE (wxycoord),INTENT(IN)::wxy
    TYPE(xycoord)::POLY1(3)
    REAL(DPN)::UARROW1(2,2),SCALE1,TRANS1(2,2),COS1,SIN1
    INTEGER(4)::STATUS
    TYPE (windowconfig):: thescreen 
	common /c2/ thescreen
    
    
    CALL moveto_w(X1,Y1,wxy)
    status=lineto_w(X2,Y2)
    
    UARROW1(1,1)=-1.D0
    UARROW1(2,1)=3**0.5/3
    UARROW1(1,2)=-1.D0
    UARROW1(2,2)=-UARROW1(2,1)
    SCALE1=((X1-X2)**2+(Y1-Y2)**2)**0.5
    COS1=(X2-X1)/SCALE1
    SIN1=(Y2-Y1)/SCALE1
    TRANS1(1,1)=COS1
    TRANS1(1,2)=SIN1
    TRANS1(2,1)=-SIN1
    TRANS1(2,2)=COS1
    UARROW1=MATMUL(TRANS1,UARROW1)
    UARROW1=UARROW1*thescreen.numxpixels/300.D0
    CALL GETVIEWCOORD_W(X2,Y2,POLY1(1))
    UARROW1(1,:)=UARROW1(1,:)+POLY1(1).XCOORD
    UARROW1(2,:)=UARROW1(2,:)+POLY1(1).YCOORD 
    POLY1(2).XCOORD=INT(UARROW1(1,1))
    POLY1(2).YCOORD=INT(UARROW1(2,1))
    POLY1(3).XCOORD=INT(UARROW1(1,2))
    POLY1(3).YCOORD=INT(UARROW1(2,2))    
    !CALL GETVIEWCOORD_W(UARROW1(1,1),UARROW1(2,1),POLY1(2))
    !CALL GETVIEWCOORD_W(UARROW1(1,2),UARROW1(2,2),POLY1(3))
    
    status=POLYGON($GFILLINTERIOR,POLY1,3)
END SUBROUTINE

!SUBROUTINE GEN_ADMISSIBLE_SLIP_SURFACE(XT,XC,NSEG,GX,NGX,RX,NRX,RDF,IFLAG,X,Y,ISERROR)
!!REFERRENC: Cheng YM, Li L, Chi SC. Performance studies on six heuristic global optimization methods in the
!! location of critical slip surface. Computers and Geotechnics. 2007;34(6):462-484.
!!GIVEN:
!!THE TOE AND CREST POINT LOCATIONS OF THE SLIP SURFACE: XT(2),XC(2)
!!NUMBER OF SUBDIVISION: NSEG>1
!!GROUND SURFACE: GX(2,NGX)
!!BEDROCK SURFACE: RX(2,NRX)
!!(RADOM) FACTOR: RDF(NSEG-1), 0<=RDF(I)<=1
!!IFLAG:
!!=1 USE RDF TO GENERATE A SLIP SURFACE
!!/=1, USE RADOM FACTOR TO GENERATE A SLIP SURFACE, AND RETURN THE FACTOR IN RDF.
!!RETURN: 
!!THE X COMPONENT OF THE VETEX OF THE SLIP LINE:X(NSEG+1)
!!THE Y COMPONENT : Y(NSEG+1)
!!ISERROR=0,SUCCESSFULLY GENERATE A SLIP SURFACE.
!!/=0, NO ADMISSIBLE SLIP SURFACE FOUND.
!
!IMPLICIT NONE
!INTEGER,INTENT(IN)::NGX,NRX,NSEG,IFLAG
!REAL(8),INTENT(IN)::XT(2),XC(2),GX(2,NGX),RX(2,NRX)
!REAL(8),INTENT(INOUT)::RDF(2:NSEG)
!REAL(8),INTENT(OUT)::X(NSEG+1),Y(NSEG+1) 
!INTEGER,INTENT(OUT)::ISERROR
!
!INTEGER::I,J,NX,K1
!REAL(8)::DX1,YU1,YL1
!REAL(8),EXTERNAL::INTERPOLATION
!
!ISERROR=0
!
!IF(ABS(XT(1)-XC(1))<1.D-7) THEN
!    ISERROR=1 
!    RETURN
!ENDIF
!
!IF(NSEG==1) THEN
!    X=[XT(1),XC(1)];
!    Y=[XT(2),XC(2)];
!    RETURN
!ENDIF
!
!NX=NSEG+1
!DX1=(XC(1)-XT(1))/NSEG
!
!!ALLOCATE(X(NX),YU(NX),YL(NX))
!
!DO I=1,NX
!    X(I)=XT(1)+DX1*(I-1)
!ENDDO
!Y(1)=XT(2);Y(NX)=XC(2)
!
!IF(IFLAG/=1) THEN
!    call random_seed()
!    call random_number(RDF)
!ENDIF
!
!DO I=2,NSEG
!    YU1=INTERPOLATION(GX(1,:),GX(2,:),NGX,X(I))
!    YL1=INTERPOLATION(RX(1,:),RX(2,:),NRX,X(I))
!    IF(I>2) THEN 
!        
!        K1=(Y(I-1)-Y(I-2))/(X(I-1)-X(I-2))
!        YL1=MAX(K1*(X(I)-X(I-1))+Y(I-1),YL1)
!        K1=(Y(I-1)-Y(NX))/(X(I-1)-X(NX))
!        YU1=MIN(K1*(X(I)-X(I-1))+Y(I-1),YU1)
!        
!        IF(YU1<YL1) THEN
!            ISERROR=1
!            RETURN
!        ENDIF
!        
!    ENDIF
!    Y(I)=YL1+(YU1-YL1)*RDF(I)
!ENDDO
!
!    
!
!END SUBROUTINE
