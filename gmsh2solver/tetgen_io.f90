module tetgen_io
    use DS_Gmsh2Solver,only:lowcase,strtoint,incount
    use GeoMetricAlgorithm
    implicit none
    
    public::read_tetgen_file,tetgen_to_tecplot,element_tg,nelt_tg
    
    private
    integer::nnode_tg=0,ndim_tg=0,nelt_tg=0,nve_tg=0,nvf_tg=0,nvc_tg=0,nvnode_tg=0,nface_tg=0,nedge_tg=0,nneigh_tg=0
    integer::order=1
    character(512)::tec_title,filepath
    integer::natr=0,ntetnode=4,nvoropassvar=0
    
    integer::type_container=0 !0 for box,1 for z-axis cylinder 
    logical::isfirstcall=.true.
    
    integer,parameter::zcylinder=1
    real(8)::eps=1.d-6
    
    type::tetgen_node_tydef
        integer::na=0,marker=0,surfin=0,a1=0,uid=0      
        !for vnode_tg, marker>0 inside the con and is the nodeid for tecplot out
        !if(node(i).uid<=i) then the node is a duplicated node, which is the copy of node(uid) 
        real(8)::x(3)
        real(8),allocatable::at(:)
    endtype
    type(tetgen_node_tydef),allocatable::node_tg(:),vnode_tg(:)

    
    type tetgen_element_tydef
        integer::nnode=0,marker=0,nedge=0,isclose=0
        !isclose,for vedge,vface and vcell =0 open/infinite. >0 close/finite
        !for vedge,marker=0 outside container;marker/=0,inside the con;=2,clipped;=3,clipped and coplan of the con; =4,clipped and not coplan;
        !for vface,isclose>0, close and (all nodes) inside the con,and it will be output to the tec file; =-1,close and some node outside the cont; =-2 close and all node outside the con;
        !for vface,iclose=0, open
        !for vcell, isclose>0,close and (all nodes) inside the con,and it will output to the the tec file.
        !for vface, marker==0,not clipped face; =3,clipped on only the generated edge is on one boundary; =4,clopped and the generated egde is on different boundary 
        !
        integer,allocatable::node(:)
        integer::cell(2)=-1 !for voronoi face, they are cell sharing the face, for vcell, cell(1) is the corresponding node id (node(cell(1))) for the cell
        real(8),allocatable::V(:)  
        !for edge ray, its direction, for face, its unit normal
        !for cell, its center.
        integer,allocatable::edge(:) !for voronoi face only
        integer::celoc=0,surfin=-1 !for vface, celoc=clipped edge id; surfin is the boudary id where the vertex  of the clipped edge laying. 
    contains
        procedure::sort_face_edge
        procedure::update_face
    end type  
    type(tetgen_element_tydef),allocatable::edge_tg(:),face_tg(:),element_tg(:), vface_tg(:),&
                vedge_tg(:),vcell_tg(:),neigh_tg(:)
    !type,extends(tetgen_element_tydef)::vface_tydef
    !    integer::nne=0
    !    integer,allocatable::newedge(:),newedgep(:)
    !    contains
    !        procedure::update_face
    !end type
    !
    !type(vface_tydef),allocatable::vface_tg(:)
    

    integer,allocatable::t2e(:,:),t2f(:,:),f2e(:,:)
    
   
    
    
    
    !邻接表
    type adj_tydef
        integer::n00=0,n01=0,n02=0,n03=0
        integer,allocatable::adj00(:),adj01(:),adj02(:),adj03(:)
    end type
    type(adj_tydef),allocatable::vnadj(:),veadj(:)
    !integer::nvnadj=0,nveadj=0

    integer::nvnadj=0,nvfadj=0    
    real(8)::xmin=1.0d20,xmax=-1.0d20,ymin=1.0d20,ymax=-1.0d20,zmin=1.0d20,zmax=-1.0d20
    real(8)::maxr
    
    character(len=512)::VarString
    character(len=64)::MeshPassVar,VoroPassVar
    type cylinder_tydef
        real(8)::P1(3),P2(3),R
        !目前假定圆柱体平行于z轴，上下底面分别为p2和p1所在的z平面
    endtype
    type model_container_tydef
        logical::isini=.false.,isread=.false.
        integer::nupdate=0
        integer::type=0 !=0,aabb box;=1,z-axis cylinder
        real(8)::box(3,2),DLen=0 ! Dlen diagonal length of the container
        type(cylinder_tydef)::cylinder
        !box=[minB(3),maxB(3)];cylinder=[p1,p2,r]
        integer::nvc_tec=0,nvf_tec=0,nvn_tec=0,TOTALNUMFACENODES=0
        integer,allocatable::vf_tec2vf_tg(:),vn_tec2vn_tg(:),vc_tec2vc_tg(:) !
    contains
        procedure::initialize=>set_container   !(numdim,minB,maxB,origin,dir,isint,coord)
        procedure::PtIsInContainer
        procedure::update=>set_container
        !procedure,NOPASS::intersetcylinder=>intcyl
        procedure::ray_clip
        !procedure::clip=>clip_container
        procedure::cut_by_box
    end type
    type(model_container_tydef)::container
    
    
    !INTERFACE read_tetgen_file
    !    MODULE PROCEDURE read_tetgen_element,read_tetgen_node
    !END INTERFACE
    
    INTERFACE ENLARGE_AR
        MODULE PROCEDURE I_ENLARGE_AR,NODE_ENLARGE_AR,ELEMENT_ENLARGE_AR                        
    END INTERFACE 
    
    contains
    
    subroutine find_duplicated_node(node1)
    !remove duplicated node and stored in uvertex
        type(tetgen_node_tydef)::node1(:)
        integer::i,j,k,n1,n2
        
        !allocate(ver2node(nver))
        n1=size(node1)
        do i=1,n1
            if(node1(i).uid>0) cycle
            do j=i+1,n1
                if(node1(j).uid>0) cycle
                if(node1(j).x(1)<node1(i).x(1)-eps) cycle
                if(node1(j).x(1)>node1(i).x(1)+eps) cycle
                if(node1(j).x(2)<node1(i).x(2)-eps) cycle
                if(node1(j).x(2)>node1(i).x(2)+eps) cycle
                if(node1(j).x(3)<node1(i).x(3)-eps) cycle
                if(node1(j).x(3)>node1(i).x(3)+eps) cycle                
                node1(j).uid=i
            enddo
            node1(i).uid=i
        enddo

    end subroutine
    
    subroutine tetgen_to_tecplot()
    
        integer::i,j,n1,av1(2)
        real(8)::v1(3,3),p1(3),p2(3),r1
        
        !prehandle
        
        !define a container
        !call set_container()
        
      
        

        call container.initialize()
        !call container.clip()
        !call container.update()
        call tec_variable_string(VarString,MeshPassVar,VoroPassVar,nvoropassvar)
        !call tetgen_mesh_to_tecplot(isfirstcall)
        call tetgen_voro_to_tecplot(isfirstcall)
        isfirstcall=.false.

        
   

        
    contains
    
        
    end subroutine
    



    
    subroutine read_tetgen_file(unit,fext)
        use dflib
        USE IFPORT
        implicit none
        integer,intent(in)::unit
        character(len=*),optional,intent(in)::fext(:)
        CHARACTER(3)        drive
	    CHARACTER(512)      dir
	    CHARACTER(512)      name,file1
	    CHARACTER(16)      ext
        CHARACTER(len=:),allocatable::ext1(:)
	    integer(4)::length,msg
        logical::isexist
        integer::unit1,i,hasread
        
        inquire(UNIT,name=file1)
		length = SPLITPATHQQ(file1, drive, dir, name, ext)
		tec_title=trim(name)
        FILEPATH=trim(drive)//trim(dir)
        msg = CHDIR(FILEPATH)
        FILEPATH=trim(drive)//trim(dir)//trim(name)
        
        if(trim(adjustl(ext))=='.cell') then
            FILEPATH=filepath(:len_trim(filepath)-2)
        endif
        close(unit)
        
        if(present(fext)) then
            ext1=fext
        else
            allocate(character(16)::ext1(12))
            ext1(1:12)=['node','ele','face','edge','neigh','t2e','t2f','f2e','v.node','v.edge','v.face','v.cell']
        endif
        
        
        do i=1,size(ext1)
            file1=trim(filepath)//'.'//trim(adjustl(ext1(i)))
            inquire(file=file1,exist=isexist)
            if(isexist) then
                unit1=10
                open(unit=unit1,file=file1,status='old')
                hasread=1
                select case(trim(adjustl(ext1(i))))
                case('node')
                    call read_tetgen_node(unit1,trim(adjustl(ext1(i))),node_tg,nnode_tg)
                    natr=node_tg(1).na
                case('ele')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),element_tg,nelt_tg)
                    ntetnode=element_tg(1).nnode
                case('neigh')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),neigh_tg,nneigh_tg)                    
                case('face')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),face_tg,nface_tg)
                case('edge')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),edge_tg,nedge_tg)
                case('v.node')
                    call read_tetgen_node(unit1,trim(adjustl(ext1(i))),vnode_tg,nvnode_tg)
                    call find_duplicated_node(vnode_tg)
                case('v.face')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),vface_tg,nvf_tg)                                      
                case('v.edge')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),vedge_tg,nve_tg)
                case('v.cell')
                    call read_tetgen_element(unit1,trim(adjustl(ext1(i))),vcell_tg,nvc_tg)  
                case('t2e')
                    call read_adj_table(unit1,trim(adjustl(ext1(i))),t2e,nelt_tg) 
                case('t2f')
                    call read_adj_table(unit1,trim(adjustl(ext1(i))),t2f,nelt_tg)  
                case('f2e')
                    call read_adj_table(unit1,trim(adjustl(ext1(i))),f2e,nface_tg)                       
                case default
                    hasread=0
                    print *, 'No such file type=',trim(ext1(i))
                end select
                if(hasread>0) print *, 'Done in reading file=',trim(file1)
            else
                print *, 'file is not exist and skipped. file=',trim(file1)
            endif
        enddo    


    end subroutine
        
    subroutine read_tetgen_element(unit,ftype,element,nelt)
        integer,intent(in)::unit
        character(len=*)::ftype
        integer,intent(out)::nelt
        type(tetgen_element_tydef),allocatable::element(:)
        
        integer::na1=0,ismarker1=0,n1=0,n2,nelt1,nmax,maxset,i
        integer::nread,nset,nneed,nnode1,n3
        integer::iar1(10)
        
        parameter(nmax=100)
	    parameter(maxset=100)
	
	    real(8)::linedata(nmax),ar1(nmax)
	    character(32)::set(maxset)
        !call skipcomment(unit)
        !read(unit,*) nnode_tg,ndim_tg,na1,ismarker1
        nneed=nmax
        
        call strtoint(unit,linedata,nmax,nread,nneed,set,maxset,nset)
        
        nelt=int(linedata(1))
        
        call lowcase(ftype)
        select case(trim(adjustl(ftype)))
        case('ele')
            n1=sum(linedata(2:nread))
            nnode1=int(linedata(2))
            if(nnode1>4) order=2
            ismarker1=linedata(nread)
        case('face')
            n1=-1 !order=1 by default.
            if(order==2) then
                nnode1=6
            else
                nnode1=3
            endif
            
            ismarker1=linedata(nread)
        case('edge')
            n1=-1 !order=1 by default.
            if(order==2) then
                nnode1=6
            else
                nnode1=3
            endif
            ismarker1=linedata(nread)
        case('neigh')
            n1=4
            nnode1=4
            ismarker1=0
        case('v.cell')
            if(nread>1) container.type=int(linedata(2))
            if(nread>2) then
                if(container.type==0) then
                    container.box=reshape(linedata(3:8),([3,2]))
                else
                    container.cylinder.p1=linedata(3:5)
                    container.cylinder.p2=linedata(6:8)
                    container.cylinder.r=linedata(9)
                endif
                container.isread=.true.
            endif
            
            n1=-1
            nnode1=-1
            ismarker1=0
        case default
            n1=-1
            nnode1=-1
            ismarker1=0
        end select
              
        allocate(element(nelt))
        
        select case(trim(adjustl(ftype)))
        case('ele','neigh')
            do i=1,nelt
                read(unit,*) n2,ar1(1:n1)
                element(n2).nnode=nnode1
                element(n2).node=ar1(1:nnode1)
                if(ismarker1>0) element(n2).marker=int(ar1(n1))
            end do
        case('face','edge')
            call strtoint(unit,linedata,nmax,nread,nneed,set,maxset,nset)
       
            n1=nread-1
            n2=int(linedata(1))
            element(n2).node=int(linedata(2:1+nnode1))
            if(ismarker1>0) element(n2).marker=int(linedata(2+nnode1))
            element(n2).nnode=nnode1
            n3=1+nnode1+ismarker1
            if(nread>n3) element(n2).cell(1:(nread-n3))=int(linedata(n3+1:nread))
            
            do i=2,nelt
                read(unit,*) n2,ar1(1:n1)
                element(n2).nnode=nnode1
                element(n2).node=ar1(1:nnode1)
                if(ismarker1>0) element(n2).marker=int(ar1(nnode1+1))
                element(n2).cell(1:(n1-(nnode1+ismarker1)))=int(ar1(nnode1+ismarker1+1:n1))
            end do
            
        case('v.edge')
            do i=1,nelt
                call strtoint(unit,linedata,nmax,nread,nneed,set,maxset,nset)
                n2=int(linedata(1))
                element(n2).node=int(linedata(2:3))
                element(n2).nnode=2
                if(nread>3) then
                    if(nread/=6) error stop 'error in readin numbers for vedge. subroutine=read_tetgen_element'
                    element(n2).v=linedata(4:6)
                endif
                if(element(n2).node(2)>0) element(n2).isclose=1
            enddo
        case('v.face')
            do i=1,nelt
                call strtoint(unit,linedata,nmax,nread,nneed,set,maxset,nset)
                n2=int(linedata(1))
                element(n2).nedge=int(linedata(4))
                if(nread/=4+element(n2).nedge) error stop 'error in readin numbers for vface. subroutine=read_tetgen_element'
                element(n2).cell=int(linedata(2:3))
                element(n2).edge=int(linedata(5:nread))
                if(element(n2).edge(element(n2).nedge)>0) element(n2).isclose=1
            enddo  
        case('v.cell')
            do i=1,nelt
                call strtoint(unit,linedata,nmax,nread,nneed,set,maxset,nset)
                n2=int(linedata(1))
                !the corresponding node for the cell is  node_tg(element(n2).cell(1))                     
                element(n2).cell(1)=int(linedata(2))
                element(n2).nnode=int(linedata(3))
                if(nread/=3+element(n2).nnode) then
                    error stop 'error in readin numbers for vcell. subroutine=read_tetgen_element'
                endif
                element(n2).node=int(linedata(4:nread))
                if(element(n2).node(element(n2).nnode)>0) element(n2).isclose=1    
            enddo             
        end select
        
        close(unit)
    end subroutine

    
    subroutine read_tetgen_node(unit,ftype,element,nelt)
        integer,intent(in)::unit
        character(len=*)::ftype
        integer,intent(out)::nelt
        type(tetgen_node_tydef),allocatable::element(:) 
        
        integer::na1=0,ismarker1=0,n1=0,n2,i
        real(8),allocatable::ar1(:)
        
        call skipcomment(unit)
        read(unit,*) nelt,ndim_tg,na1,ismarker1
        n1=3+na1+ismarker1        
        allocate(element(nelt),ar1(n1))
        !if(na1>0) allocate(node_tg.at(na1))
        do i=1,nelt
            read(unit,*) n2,ar1(1:n1)            
            element(n2).x=ar1(1:3)
            if(na1>0) element(n2).at=ar1(4:3+na1)
            element(n2).na=na1
            if(ismarker1>0) element(n2).marker=ar1(3+na1+1)
        end do
        close(unit)
    end subroutine
    
    subroutine read_adj_table(unit,ftype,element,nelt)
        integer,intent(in)::unit,nelt
        character(len=*)::ftype
        integer,allocatable::element(:,:)
        
        integer::i,nnode1,n1
        
        select case(trim(adjustl(ftype)))
        case('f2e')            
            nnode1=3
        case('t2e')
            nnode1=6
        case('t2f')
            nnode1=4        
        end select
        allocate(element(nnode1,nelt))
        
        read(unit,*) ((n1,element(:,n1)),i=1,nelt)
        
        close(unit)
    end subroutine
    
    
!    subroutine tetgen_mesh_to_tecplot(isfirstcall)
!        logical,intent(inout)::isfirstcall
!        integer::unit1,nc1,i,j
!        integer,external::incount
!        
!        if(nelt_tg<1) return
!        
!        unit1=10
!        if(isfirstcall) then
!            open(unit1,file=trim(filepath)//'_tetgen_mesh.tec',status='replace')
!            write(unit1,10) trim(tec_title)//'-mesh'
!            write(unit1,20) (i,i=1,natr)
!            !isfirstcall=.false.
!        else
!            open(unit1,file=trim(filepath)//'_tetgen_mesh.tec',status='old',access='append')
!        endif
!        
!        write(unit1,30) nnode_tg,nelt_tg
!        nc1=20
!        !write x        
!        write(unit1,41) ((node_tg(i).x(j),i=1,nnode_tg),j=1,3)
!        !write attributs
!        if(natr>0) write(unit1,41) ((node_tg(i).at(j),i=1,nnode_tg),j=1,natr)
!        !write marker
!        write(unit1,51) (node_tg(i).marker,i=1,nnode_tg)
!        !!write radius
!        !write(unit1,41) (node_tg(i).at(1)**2,i=1,nnode_tg)
!        
!        !do i=1,nnode_tg
!        !    write(unit1,40) node_tg(i).x,node_tg(i).at(1:natr),node_tg(i).marker
!        !enddo
!        
!        nc1=ntetnode
!        do i=1,nelt_tg
!            write(unit1,50) element_tg(i).node
!        enddo
!        
!        close(unit1)
!        
!10  format('Title="',a<len_trim(tec_title)+5>,'"')
!20  format('Variables="X","Y","Z",',<natr>('"ATR',i<incount(i)>,'",'),'"Marker"') 
!30  format('Zone,zonetype=FETETRAHEDRON,N=',I7,',E=',I7,',datapacking=BLOCK') 
!40  format(<nc1>(E24.16,1X),i7)
!41  format(<nc1>(E24.16,','))    
!50  format(<nc1>(I7,1X))    
!51  format(<nc1>(I7,','))    
!    end subroutine

    subroutine tetgen_voro_to_tecplot(isfirstcall)
        logical,intent(inout)::isfirstcall
        integer::unit1,nc1,i,j,natr1,nc2,nv1
        !integer,external::incount
        

        
        
        
        unit1=10
        natr1=vnode_tg(1).na
        NV1=3+NATR1+1
        
        if(isfirstcall) then
            open(unit1,file=trim(filepath)//'_tetgen_voro.tec',status='replace')
            write(unit1,10) trim(tec_title)//'-voro'
            
            write(unit1,*) trim(VarString)
            isfirstcall=.false.
        else
            open(unit1,file=trim(filepath)//'_tetgen_voro.tec',status='old',access='append')
        endif
        
        
        
        if(container.nvc_tec>0) then
            write(unit1,30) container.nvn_tec,container.nvc_tec,container.nvf_tec,'[6]',container.TOTALNUMFACENODES,trim(VoroPassVar)
            nc1=20
            do i=1,3
                write(unit1,41) (vnode_tg(container.vn_tec2vn_tg(j)).x(i),j=1,container.nvn_tec)
            enddo
            
            !nc1=container.nvn_tec
            !do i=1,nvoropassvar
            !    write(unit1,80) container.nvn_tec
            !enddo
            !
            !nc1=20
            if(natr1>0) write(unit1,41) ((vnode_tg(container.vn_tec2vn_tg(j)).at(i),j=1,container.nvn_tec),i=1,natr1)
            !output the r of the associated node of th cell
            !默认半径为对应节点属性1的值平方
            write(unit1,41) (node_tg(vcell_tg(container.vc_tec2vc_tg(j)).cell(1)).at(1)**0.5,j=1,container.nvc_tec)
        
            !node count per face
            write(unit1,70)
            write(unit1,50) (vface_tg(container.vf_tec2vf_tg(i)).nnode,i=1,container.nvf_tec)
            !nodes per face
            write(unit1,71)
            do i=1,container.nvf_tec
                nc2=vface_tg(container.vf_tec2vf_tg(i)).nnode
                write(unit1,51) vnode_tg(vface_tg(container.vf_tec2vf_tg(i)).node).marker
            enddo
            !left element per face
            write(unit1,72)
            write(unit1,50) (vcell_tg(vface_tg(container.vf_tec2vf_tg(i)).cell(2)).isclose,i=1,container.nvf_tec)
            !right element per face
            write(unit1,73)
            write(unit1,50) (vcell_tg(vface_tg(container.vf_tec2vf_tg(i)).cell(1)).isclose,i=1,container.nvf_tec)
        endif
        
        call write_mesh_zone() 
   
        
        close(unit1)
        
10  format('Title="',a<len_trim(tec_title)+5>,'"')
20  format('Variables="X","Y","Z",',<natr1>('"ATR',i<incount(i)>,'","Rn"')) 
21  format('Variables="X","Y","Z","Rn"')   
    30  format('Zone,T=Voro,zonetype=FEPOLYHEDRON,N=',I7,',E=',I7,',datapacking=BLOCK,Faces=',i7, &
        ',VARLOCATION=(',A,'=CELLCENTERED)',',TOTALNUMFACENODES=',i7, &
        ',NUMCONNECTEDBOUNDARYFACES=0,TOTALNUMBOUNDARYCONNECTIONS=0',2X,A) 
40  format(<nc1>(E24.16,1X),i7)
41  format(<nc1>(E24.16,','))
50  format(<nc1>(I7,1X))
51  format(<nc2>(I7,1X))
52  format('# faceid:',<nc2>(I7,1X))
60  format('#node count per face for cell=',i7)
61  format('#face nodes for cell=',i7)
62  format('#face left elements for cell=',i7)
63  format('#face right elements for cell=',i7)
70  format('#node count per face')
71  format('#nodes per face')
72  format('#left elements per face')
73  format('#right elements per face')
80  format(i<incount(nc1)>,'*0.')
    contains
    
    subroutine write_mesh_zone()
        
        integer::i,j,nc1
        
        if(nelt_tg<1) return
        
        write(unit1,30) nnode_tg,nelt_tg,trim(MeshPassVar)
        nc1=20
        !write x        
        write(unit1,41) ((node_tg(i).x(j),i=1,nnode_tg),j=1,3)
        !write marker
        write(unit1,51) (node_tg(i).marker,i=1,nnode_tg)
        !write attributs
        if(natr>0) write(unit1,41) ((node_tg(i).at(j),i=1,nnode_tg),j=1,natr)
        
        nc1=ntetnode
        do i=1,nelt_tg
            write(unit1,50) element_tg(i).node
        enddo

30  format('Zone,T=Mesh,zonetype=FETETRAHEDRON,N=',I7,',E=',I7,',datapacking=BLOCK',2X,A) 
40  format(<nc1>(E24.16,1X),i7)
41  format(<nc1>(E24.16,','))    
50  format(<nc1>(I7,1X))    
51  format(<nc1>(I7,','))         
        
        
    end subroutine
    
    
end subroutine
    

    
    subroutine tec_variable_string(VarString,MeshPassVar,VoroPassVar,nvoropassvar)
        character(len=*)::VarString,MeshPassVar,VoroPassVar
        integer::nvoropassvar
        integer::i,nc1,nc2,nmeshvar,nvartec
        character(len=64)::VarTec(100)
        !integer,external::incount
        
        nvartec=4
        VarTec(1:4)=['"X"','"Y"','"Z"','"MARKER"']
        do i=1,node_tg(1).na
            WRITE(VarTec(nvartec+i),10) I
        enddo
        
        nvartec=nvartec+node_tg(1).na
        nmeshvar=nvartec
        
        do i=1,vnode_tg(1).na
            WRITE(VarTec(nvartec+i),11) I
        enddo
        
        nvartec=nvartec+vnode_tg(1).na
        !rn
        write(VarTec(nvartec+1),*) '"VORO_Rn"'        
        nvartec=nvartec+1
        
        VarString='Variables='
        do i=1,nVarTec
            VarString=trim(adjustl(VarString))//trim(VarTec(i))//','
        enddo
        
        nc1=nmeshvar+1;nc2=nvartec
        if(nc2>nc1) then
            write(MeshPassVar,20) nc1,nc2
        else
             write(MeshPassVar,21) nc1
        endif
        VoroPassVar=''
        if(nmeshvar>3) then
            nc1=4;nc2=nmeshvar
            nvoropassvar=nc2-nc1+1
            if(nc2>nc1) then
                write(VoroPassVar,20) nc1,nc2
            else
                write(VoroPassVar,21) nc1
            endif
        endif
        
10      FORMAT('"MESH_ATR',I<INCOUNT(I)>,'"')
11      FORMAT('"VORO_ATR',I<INCOUNT(I)>,'"')  
20      FORMAT('PassiveVarList=[',I<INCOUNT(nc1)>,'-',I<INCOUNT(nc2)>,']') 
21      FORMAT('PassiveVarList=[',I<INCOUNT(nc1)>,']')  
    end subroutine


    

    

    
subroutine set_container(this)
    class(model_container_tydef)::this
    integer::i,n1
    

    
    if(.not.this.isread) then
        if(natr>0) maxr=maxval(node_tg.at(1))
        maxr=maxr**0.5 !assumption
        this.box(1,1)=minval(node_tg.x(1))-maxr
        this.box(2,1)=minval(node_tg.x(2))-maxr
        this.box(3,1)=minval(node_tg.x(3))-maxr
        this.box(1,2)=maxval(node_tg.x(1))+maxr
        this.box(2,2)=maxval(node_tg.x(2))+maxr
        this.box(3,2)=maxval(node_tg.x(3))+maxr
        if(this.type==zcylinder) then
            this.cylinder.p1=[(xmin+xmax)/2,(ymin+ymax)/2,zmin]
            this.cylinder.p2=[(xmin+xmax)/2,(ymin+ymax)/2,zmin]
            this.cylinder.r=max((xmax-xmin)/2,(ymax-ymin)/2)
        endif
    endif
    
    if(this.type==zcylinder) then
        print *, 'not finished yet.'
        return
    else
        call this.cut_by_box()
    endif   

    
    this.nvn_tec=0
    if(allocated(this.vn_tec2vn_tg)) deallocate(this.vn_tec2vn_tg)
    allocate(this.vn_tec2vn_tg(nvnode_tg))
    do i=1,nvnode_tg
        if(vnode_tg(i).marker>0) then
            this.nvn_tec=this.nvn_tec+1
            vnode_tg(i).marker=this.nvn_tec
            this.vn_tec2vn_tg(this.nvn_tec)=i
        endif
    enddo
        

    !only ouput the cell whose all node inside the container.
    this.nvc_tec=0
    if(allocated(this.vc_tec2vc_tg)) deallocate(this.vc_tec2vc_tg)
    allocate(this.vc_tec2vc_tg(nvc_tg))
    do i=1,nvc_tg
        if(vcell_tg(i).marker>0) then
            this.nvc_tec=this.nvc_tec+1
            this.vc_tec2vc_tg(this.nvc_tec)=i
        endif
    enddo     

    
    !reorder 
    this.nvf_tec=0
    if(allocated(this.vf_tec2vf_tg)) deallocate(this.vf_tec2vf_tg)
    allocate(this.vf_tec2vf_tg(nvf_tg))
    this.vf_tec2vf_tg=0
    This.TOTALNUMFACENODES=0
    do i=1,nvf_tg
        if(vface_tg(i).marker>0) then
            this.nvf_tec=this.nvf_tec+1            
            this.vf_tec2vf_tg(this.nvf_tec)=i
            This.TOTALNUMFACENODES=This.TOTALNUMFACENODES+vface_tg(i).nnode                
        endif
    enddo
    
    
    this.nupdate=this.nupdate+1
endsubroutine

subroutine cut_by_box(this)
    class(model_container_tydef)::this
    integer::i,j,k,v1(2),n1,n2
    real(8)::t1
        

    !make infinite point to finite
    do i=1,nve_tg
        if(vedge_tg(i).isclose==0) then
            nvnode_tg=nvnode_tg+1
            if(nvnode_tg>size(vnode_tg)) call enlarge_ar(vnode_tg,100)
            vnode_tg(nvnode_tg).x=vnode_tg(vedge_tg(i).node(1)).x+vedge_tg(i).v*1.d6
            vedge_tg(i).isclose=2
            vedge_tg(i).node(2)=nvnode_tg
        endif
    enddo
    
    !close the face
    do i=1,nvf_tg
        if(vface_tg(i).isclose==0) then
            n2=0;v1=0
            do j=1,vface_tg(i).nedge-1
                n1=vface_tg(i).edge(j)
                if(vedge_tg(n1).isclose/=2) cycle
                n2=n2+1
                v1(n2)=vedge_tg(n1).node(2)
            enddo
            nve_tg=nve_tg+1
            if(nve_tg>size(vedge_tg)) call ELEMENT_ENLARGE_AR(vedge_tg,100)
            vedge_tg(nve_tg).node=v1
            vedge_tg(nve_tg).nnode=2
            vedge_tg(nve_tg).isclose=1
            vface_tg(i).edge(vface_tg(i).nedge)=nve_tg
            vface_tg(i).isclose=1
        endif
    enddo
    
        
     do i=1,nvf_tg
        call vface_tg(i).sort_face_edge(vedge_tg,nvnode_tg)
     end do 
     
    vnode_tg.marker=-1 !==2 on the cutting face
    vedge_tg.marker=-1 !==1, the edge has been clipped;==2,on the cutting face
    vface_tg.marker=-1 !==1, the face has been clipped;==2,on the cutting face
    vcell_tg.marker=-1 
    do i=1,3
        do j=1,2

            
            t1=this.box(i,j) 
            
            !update node state
            !marker==1,inside; marker==2,on the surface;=0,ouside
            do k=1,nvnode_tg
                if(j==1) then
                    if(abs(vnode_tg(k).x(i)-t1)<eps) then
                        vnode_tg(k).marker=2
                    elseif(vnode_tg(k).x(i)>t1) then
                        vnode_tg(k).marker=1
                    else                        
                        vnode_tg(k).marker=0
                    endif
                else
                    if(abs(vnode_tg(k).x(i)-t1)<eps) then
                        vnode_tg(k).marker=2
                    elseif(vnode_tg(k).x(i)<t1) then
                        vnode_tg(k).marker=1
                    else
                        vnode_tg(k).marker=0
                    endif                    
                endif
            enddo
            
            !upadte vedge state
            !marker=0 outside container;
            !marker=1,inside the con
            !marker=2,on the con faces;
            do k=1,nve_tg
                call cut_edge(k,t1,i)
            enddo  
            
            !cut face
            do k=1,nvf_tg
                call cut_face(k)                
            enddo
            
            !cut the cell
            do k=1,nvc_tg
                call cut_cell(k)
            enddo
            
            
        enddo
    enddo

endsubroutine

    subroutine cut_cell(icell)
        implicit none
        integer,intent(in)::icell
        integer::i,j,nface1,n1,n2,n3,n4,face1(100),cutedge1(100)
        integer,allocatable::cutface1(:)
        !assume the cell is convex
        
        if(vcell_tg(icell).marker==0) return
        
        nface1=vcell_tg(icell).nnode
        if(vcell_tg(icell).isclose<1) nface1=nface1-1 
        face1(:nface1)=vcell_tg(icell).node(1:nface1)
        
       
        n2=count(vface_tg(face1(:nface1)).marker>0)
        
        vcell_tg(icell).marker=-1
        if(n2==nface1) then
            vcell_tg(icell).marker=1
        elseif(n2==0) then
            vcell_tg(icell).marker=0
            return
        endif
        
        cutface1=pack(face1(:nface1),vface_tg(face1(:nface1)).marker==3)
        n1=size(cutface1)
        if(n1<2) return
        n3=0
        do i=1,n1
            n2=vface_tg(cutface1(i)).nedge
            do j=1,n2
                n4=abs(vface_tg(cutface1(i)).edge(j))
                if(vedge_tg(n4).marker==2) then                    
                    !n3=n3+1
                    cutedge1(i)=n4
                    exit !only one such edge for each clipped face
                endif
            enddo            
        enddo
        
        !if(n3/=n1) then
        !    error stop 'unexpected error. sub=cut_cell'
        !endif
        
        !gen new face
        nvf_tg=nvf_tg+1
        if(nvf_tg>size(vface_tg)) call ELEMENT_ENLARGE_AR(vface_tg,100)
        vface_tg(nvf_tg).nedge=n1
        vface_tg(nvf_tg).edge=cutedge1(1:n1)
        vface_tg(nvf_tg).isclose=1
        vface_tg(nvf_tg).marker=2
        vface_tg(nvf_tg).cell(1)=icell        
        call vface_tg(nvf_tg).sort_face_edge(vedge_tg,nvnode_tg)
        vcell_tg(icell).isclose=1
        vcell_tg(icell).node=[pack(vcell_tg(icell).node(:nface1),vface_tg(vcell_tg(icell).node(:nface1)).marker>0),nvf_tg]
        vcell_tg(icell).nnode=size(vcell_tg(icell).node)
        vcell_tg(icell).marker=3 !clipped
         
    end subroutine
    
    subroutine cut_face(iface)
        implicit none
        integer,intent(in)::iface
        integer::i,j,n1,n2,node1(10)
        
        !assume the face is convex.
        
        if(vface_tg(iface).marker==0) return
        
        vface_tg(iface).marker=-1
        n1=count(vnode_tg(vface_tg(iface).node).marker==2)
        n2=count(vnode_tg(vface_tg(iface).node).marker>0)
        if(vface_tg(iface).nnode==n1) then
            vface_tg(iface).marker=2        
        elseif(vface_tg(iface).nnode==n2) then
            vface_tg(iface).marker=1
            !one edge on the cutting face
            if(count(vedge_tg(abs(vface_tg(iface).edge)).marker==2)>0) then
                vface_tg(iface).marker=3 !also group it to 3                
            endif            
        elseif(n2-n1==0) then
            vface_tg(iface).marker=0
        endif
        if(vface_tg(iface).marker/=-1) return
        

     
        !gen a new edge
        n2=0
        do i=1,vface_tg(iface).nedge
            n1=abs(vface_tg(iface).edge(i))
            do j=1,2
                if(vnode_tg(vedge_tg(n1).node(j)).marker==2) then
                    n2=n2+1
                    node1(n2)=vedge_tg(n1).node(j)
                endif
            enddo
        enddo
        if(n2/=2) then
            print *, 'the number of the nodes on the cutting face should be 2. but it=',n2
            error stop
        endif
        
        
        nve_tg=nve_tg+1
        if(nve_tg>size(vedge_tg)) call ELEMENT_ENLARGE_AR(vedge_tg,100)
        vedge_tg(nve_tg).node=node1(1:2)
        vedge_tg(nve_tg).nnode=2
        vedge_tg(nve_tg).isclose=1
        vedge_tg(nve_tg).MARKER=2
        vface_tg(iface).edge=[pack(vface_tg(iface).edge,vedge_tg(abs(vface_tg(iface).edge)).marker>0),nve_tg]    
        vface_tg(iface).nedge=size(vface_tg(iface).edge)

        call vface_tg(iface).sort_face_edge(vedge_tg,nvnode_tg)
        vface_tg(iface).marker=3 !clip and make it inside
        
                
    end subroutine

    subroutine cut_edge(iedge,vcut,dim,inode)
       
        implicit none
        integer,intent(in)::iedge,dim
        integer,intent(out),optional::inode
        real(8),intent(in)::vcut
        real(8)::v1(2),t2,xi1(3)
        integer::inode1,n2,n1
        
        
        if(vedge_tg(iedge).marker==0) return !outside is always outside.
        
        v1=vedge_tg(iedge).node
        
        n1=count(vnode_tg(v1).marker>0)  
        n2=count(vnode_tg(v1).marker==2)
        
        vedge_tg(iedge).marker=-1
        
        if(n2==2) then
            vedge_tg(iedge).marker=2 !one the cutface
        elseif(n1==2) then   
            vedge_tg(iedge).marker=1 !inside the con
        elseif(n1-n2==0) then
            vedge_tg(iedge).marker=0 !ouside the con
        endif
        
        if(vedge_tg(iedge).marker/=-1) return
        
        !cross the con, cut it 
        
        t2=(vcut-vnode_tg(v1(1)).x(dim))/(vnode_tg(v1(2)).x(dim)-vnode_tg(v1(1)).x(dim))
        
         
        xi1=vnode_tg(v1(1)).x+t2*(vnode_tg(v1(2)).x-vnode_tg(v1(1)).x)
        nvnode_tg=nvnode_tg+1
        if(size(vnode_tg)<nvnode_tg) call enlarge_ar(vnode_tg,100)
        vnode_tg(nvnode_tg).x=xi1
        vnode_tg(nvnode_tg).marker=2 !!one the cutting face
        vnode_tg(nvnode_tg).uid=nvnode_tg
        vedge_tg(iedge).marker=3 !clipped to make it inside the con
        if(vnode_tg(v1(1)).marker<=0) then
            vedge_tg(iedge).node(1)=nvnode_tg
        else
            vedge_tg(iedge).node(2)=nvnode_tg
        endif
        inode1=nvnode_tg
        if(present(inode)) inode=inode1
    
    
    endsubroutine
            
    subroutine sort_face_edge(this,edges,nmax)
    !given the disordered edges of a polygon,sort it 
    !return the ordered nodes and edges
        implicit none
        class(tetgen_element_tydef)::this
        type(tetgen_element_tydef),intent(in)::edges(:)
        integer,intent(in)::nmax        
        integer::v1(2),i,j,n1,n2,n3,sign1,edge1(100)
        integer,allocatable::node1(:,:)
        real(8)::av1(3,3)
        
        allocate(node1(3,nmax))        
        node1=0
        do i=1,this.nedge
            
            v1=edges(abs(this.edge(i))).node            
            do j=1,2
                if(j==1) then
                    sign1=1 !first vetex
                else
                    sign1=-1 !second vetex
                endif
                
                node1(3,v1(j))=node1(3,v1(j))+1
                if(node1(3,v1(j))>2) then
                    error stop 'the face seems not to be a simple polygon. sub=sort_face_edge'
                endif 
                
                if(node1(1,v1(j))==0) then
                    node1(1,v1(j))=i*sign1                    
                else
                    node1(2,v1(j))=i*sign1
                endif
            enddo
        enddo
        
        if(any(node1(3,:)>0.and.node1(3,:)/=2)) then
            print *, 'the face seems not to be close. sub=sort_face_edge'
            error stop
        endif
        
        n1=count(node1(1,:)/=0)
        if(allocated(this.node)) deallocate(this.node)
        allocate(this.node(n1+1))
        if(this.edge(1)>0) then
            this.node(1:2)=edges(this.edge(1)).node
        else
            this.node(1:2)=edges(-this.edge(1)).node(2:1:-1)
        endif        
        
        n1=2;n2=1;edge1(1)=this.edge(1)
        do while(this.node(n1)/=this.node(1))
            if(abs(node1(1,this.node(n1)))==n2) then
                n2=node1(2,this.node(n1))
            else
                n2=node1(1,this.node(n1))
            endif
            edge1(n1)=sign(this.edge(abs(n2)),n2)
            if(n2<0) then                
                n2=-n2;n3=1
            else
                n3=2
            endif
            n1=n1+1
            this.node(n1)=edges(abs(this.edge(n2))).node(n3)
            
        enddo
        
        this.node=this.node(1:n1-1)
        this.nnode=n1-1;this.nedge=n1-1
        this.edge=edge1(1:n1-1)
        
        if(.not.allocated(this.v)) then
            allocate(this.v(3))
            do i=1,3
                av1(:,i)=vnode_tg(this.node(i)).x
            enddo
            this.v=NORMAL_TRIFACE(av1)
            if(norm2(this.v)==0.d0) then
                pause
            endif
            
            av1(:,1)=vnode_tg(maxval(this.node)).x
            av1(:,1)=node_tg(vcell_tg(this.cell(1)).cell(1)).x-av1(:,1)
            
            if(dot_product(av1(:,1),this.v)<0) then
                n1=this.cell(1)
                this.cell(1)=this.cell(2)
                this.cell(2)=n1
            endif
                
        endif        
        
        deallocate(node1)
        
    endsubroutine            

SUBROUTINE NODE_ENLARGE_AR(AVAL,DSTEP)
    TYPE(tetgen_node_tydef),ALLOCATABLE,INTENT(INOUT)::AVAL(:)
    INTEGER,INTENT(IN)::DSTEP
    TYPE(tetgen_node_tydef),ALLOCATABLE::VAL1(:)
    INTEGER::LB1=0,UB1=0
    
    LB1=LBOUND(AVAL,DIM=1);UB1=UBOUND(AVAL,DIM=1)
    ALLOCATE(VAL1,SOURCE=AVAL)
    DEALLOCATE(AVAL)
    ALLOCATE(AVAL(LB1:UB1+DSTEP))
    AVAL(LB1:UB1)=VAL1
    !AVAL(UB1+1:UB1+10)=0
    DEALLOCATE(VAL1)
END SUBROUTINE

SUBROUTINE ELEMENT_ENLARGE_AR(AVAL,DSTEP)
    TYPE(tetgen_element_tydef),ALLOCATABLE,INTENT(INOUT)::AVAL(:)
    INTEGER,INTENT(IN)::DSTEP
    TYPE(tetgen_element_tydef),ALLOCATABLE::VAL1(:)
    INTEGER::LB1=0,UB1=0
    
    LB1=LBOUND(AVAL,DIM=1);UB1=UBOUND(AVAL,DIM=1)
    ALLOCATE(VAL1,SOURCE=AVAL)
    DEALLOCATE(AVAL)
    ALLOCATE(AVAL(LB1:UB1+DSTEP))
    AVAL(LB1:UB1)=VAL1
    !AVAL(UB1+1:UB1+10)=0
    DEALLOCATE(VAL1)
END SUBROUTINE

SUBROUTINE I_ENLARGE_AR(AVAL,DSTEP)
    INTEGER,ALLOCATABLE,INTENT(INOUT)::AVAL(:)
    INTEGER,INTENT(IN)::DSTEP
    INTEGER,ALLOCATABLE::VAL1(:)
    INTEGER::LB1=0,UB1=0
    
    LB1=LBOUND(AVAL,DIM=1);UB1=UBOUND(AVAL,DIM=1)
    ALLOCATE(VAL1,SOURCE=AVAL)
    DEALLOCATE(AVAL)
    ALLOCATE(AVAL(LB1:UB1+DSTEP))
    AVAL(LB1:UB1)=VAL1
    !AVAL(UB1+1:UB1+10)=0
    DEALLOCATE(VAL1)
END SUBROUTINE

subroutine setup_voro_adjacent_table()

    integer i,j,n1
    integer,allocatable::node1(:)
    nvnadj=nvnode_tg
    
    allocate(vnadj(nvnode_tg),veadj(nve_tg))
    
    do i=1,nve_tg
        node1=vedge_tg(i).node
        n1=vedge_tg(i).nnode
        if(vedge_tg(i).isclose==0) n1=n1-1        
        do j=1,n1
            vnadj(node1(j)).adj01=[vnadj(node1(j)).adj01,i,j]
        enddo
    enddo    

    do i=1,nvf_tg
        node1=pack(vface_tg(i).node,vface_tg(i).node>0)
        n1=vface_tg(i).nnode
        !if(vface_tg(i).isclose==0) n1=n1-1 
        do j=1,n1
            vnadj(node1(j)).adj02=[vnadj(node1(j)).adj02,i,j]
        enddo
        node1=pack(vface_tg(i).edge,vface_tg(i).edge>0)
        n1=vface_tg(i).nedge
        if(vface_tg(i).isclose==0) n1=n1-1 
        do j=1,n1
            veadj(node1(j)).adj01=[veadj(node1(j)).adj01,i,j]
        enddo        
        
    enddo    
    
end subroutine
        
logical function PtIsInContainer(this,pt)
    class(model_container_tydef)::this
    real(8),intent(in)::pt(3)
    
    select case(this.type)
    case(zcylinder)
        PtIsInContainer=cylinder_point_inside_3d ( this.cylinder.p1, this.cylinder.p2, this.cylinder.r, pt )
    case default
        PtIsInContainer=box_contains_point_nd ( ndim_tg, this.box(:,1), this.box(:,2), pt )
    end select
endfunction

subroutine ray_clip(this,raybase,raydir,isint,intp,Surfin)
!return the intersect point coord(intp) of the ray and the container.
!isnit=.true. intersected. =.false. no intersect

    class(model_container_tydef)::this
    real(8),intent(in)::raybase(3)
    real(8),intent(in)::raydir(3)
    real(8),intent(out)::intp(3)
    logical,intent(out)::isint
    integer,intent(out)::surfin
    real(8)::axis(3),botplane(4),topplane(4),tin,tout
    integer::surfout
    
    select case(this.type)
        
    case(zcylinder)
        axis=this.cylinder.p2-this.cylinder.p1
        !假定圆柱体平行于z轴，上下底面分别为p2和p1所在的z平面
        botplane=[0.d0,0.d0,-1.d0,this.cylinder.p1(3)]
        topplane=[0.d0,0.d0,1.d0,-this.cylinder.p1(3)]
        call rayintcyl(raybase,raydir,this.cylinder.p1,axis,this.cylinder.r,isint,tin,tout,botplane,topplane,surfin,surfout)
        if(isint) intp=raybase+tin*raydir
        
    case default
        call rayintbox(3,this.box(:,1),this.box(:,2),raybase,raydir,isint,intp,surfin)
    end select

end subroutine


!subroutine clip_container(this)
!    class(model_container_tydef)::this
!    integer::i,j,k,surfin,f1,mk1(2),e1,n1,bn1(2),n2,nvn1,nbase1,hull_num
!    real(8)::raybase(3),raydir(3),intp(3),t1,rar1(3,100)
!    integer,allocatable::node1(:)
!    integer::iar1(100),iar2(100),ia2d1(100,100)
!    integer,allocatable::ia
!    logical::isint,tof1,tof2
!    
!
!    
!    
!  
!    nvn1=nvnode_tg        
!    do i=1,nve_tg
!               
!        if(vedge_tg(i).isclose==0) then
!            if(vnode_tg(vedge_tg(i).node(1)).marker>0) then
!                raybase=vnode_tg(vedge_tg(i).node(1)).x
!                raydir=vedge_tg(i).v
!                !make raybase outside the container
!                raybase=raybase+raydir*t1
!                raydir=-raydir
!                n1=2;nbase1=vedge_tg(i).node(1)
!            else
!                !all node outside container
!                cycle
!            endif
!        else
!            mk1=vnode_tg(vedge_tg(i).node).marker
!            if(mk1(1)>0.and.mk1(2)==0) then
!                bn1(1)=vedge_tg(i).node(2) !basenode
!                bn1(2)=vedge_tg(i).node(1)
!                n1=2;nbase1=bn1(2)
!            elseif(mk1(1)==0.and.mk1(2)>0) then
!                bn1(1)=vedge_tg(i).node(1)
!                bn1(2)=vedge_tg(i).node(2)
!                n1=1;nbase1=bn1(2)
!            else
!                if(mk1(1)*mk1(2)>0) then
!                    vedge_tg(i).marker=1 !all node inside container
!                endif
!                !all nodes are inside/outside the container
!                cycle
!            endif
!            raybase=vnode_tg(bn1(1)).x
!            raydir=vnode_tg(bn1(2)).x-vnode_tg(bn1(1)).x
!        endif
!    
!        call this.ray_clip(raybase,raydir,isint,intp,Surfin)
!        
!        if(.not.isint) then
!            error stop 'unexpected error. sub=clip_edge'
!        else
!            !判断这个线段的端点在面上，即端点等于交点，这样的线段也属于体外线段
!            if(norm2(vnode_tg(nbase1).x-intp)<1.d-8) cycle
!            
!            if(nvnode_tg+1>size(vnode_tg)) call enlarge_ar(vnode_tg,100)
!            !vnode_tg=[vnode_tg,vnode_tg(1)]
!            nvnode_tg=nvnode_tg+1
!            vnode_tg(nvnode_tg).x=intp
!            vnode_tg(nvnode_tg).na=0
!            this.nvn_tec=this.nvn_tec+1
!            vnode_tg(nvnode_tg).marker=this.nvn_tec
!            if(this.nvn_tec>size(this.vn_tec2vn_tg)) call enlarge_ar(this.vn_tec2vn_tg,100)
!            this.vn_tec2vn_tg(this.nvn_tec)=nvnode_tg
!            !this.vn_tec2vn_tg=[this.vn_tec2vn_tg(:this.nvn_tec-1),nvnode_tg]
!            vnode_tg(nvnode_tg).surfin=Surfin !表示插入的点,及其所在的面
!            n2=vedge_tg(i).node(n1)
!            if(n2==-1) deallocate(vedge_tg(i).v)
!            vedge_tg(i).node(n1)=nvnode_tg
!            vedge_tg(i).isclose=1
!            vedge_tg(i).marker=2 !mean had been modified.
!            !vedge_tg(i).Surfin=Surfin
!            !vedge_tg(i).celoc=nvnode_tg !新点的位置
!            !where(vface_tg(f1).node==n2) vface_tg(f1).node=nvnode_tg !update face nodes
!        endif    
!    enddo
!    
!    !update face
!    ia2d1=0
!    do i=1,nvf_tg
!        if(vface_tg(i).isclose>0) cycle !exclude faces with all nodes inside the container
!        if(vface_tg(i).isclose==-2) cycle !exclude faces with all nodes outside the container
!        n1=vface_tg(i).nedge
!        if(vface_tg(i).isclose==0) n1=vface_tg(i).nedge-1
!        if(all(vedge_tg(vface_tg(i).edge(:n1)).marker==0)) then
!            vface_tg(i).isclose=-2 !exclude outsid face
!            cycle
!        endif        
!
!        
!        if(all(vedge_tg(vface_tg(i).edge(1:n1)).marker/=2)) cycle !exclude no modification edge.
!        
!      
!            
!        vface_tg(i).edge=pack(vface_tg(i).edge(1:n1),vedge_tg(vface_tg(i).edge(1:n1)).marker>0)
!        
!        vface_tg(i).nedge=size(vface_tg(i).edge)
!        
!        iar1=0;n2=2
!        iar1(1:2)=vedge_tg(vface_tg(i).edge(1)).node
!        vnode_tg(iar1(1:2)).a1=[1,2]
!        ia2d1(1,2)=i;ia2d1(2,1)=i
!        rar1(:,1)=vnode_tg(iar1(1)).x
!        rar1(:,2)=vnode_tg(iar1(2)).x
!        
!        do j=2,vface_tg(i).nedge
!            if(vface_tg(i).edge(j)<1) cycle
!            bn1=vedge_tg(vface_tg(i).edge(j)).node
!            do k=1,2
!                n1=bn1(k)
!                if(.not.any(iar1(:n2)==n1)) then
!                    n2=n2+1
!                    iar1(n2)=n1
!                    vnode_tg(n1).a1=n2
!                    rar1(:,n2)=vnode_tg(n1).x
!                endif
!            enddo
!            ia2d1(vnode_tg(bn1(1)).a1,vnode_tg(bn1(2)).a1)=i;ia2d1(vnode_tg(bn1(2)).a1,vnode_tg(bn1(1)).a1)=i
!        enddo
!        !print *,'A0,i=',i
!        call coplane_points_hull_3d(n2, rar1(:,:n2), hull_num, iar2(:n2)) !assume n2<=100
!        if(n2/=hull_num) then
!            error stop 'the polygon was expected convex. but it is not'
!        endif
!        do j=1,hull_num
!            k=mod(j,hull_num)+1
!            if(ia2d1(iar2(j),iar2(k))/=i) then !generate new edge
!                nve_tg=nve_tg+1
!                if(nve_tg>size(vedge_tg)) call enlarge_ar(vedge_tg,100)
!                
!                vedge_tg(nve_tg).nnode=2
!                bn1=iar1(iar2([j,k]))
!                vedge_tg(nve_tg).node=bn1
!                vedge_tg(nve_tg).isclose=1 
!                vface_tg(i).edge=[vface_tg(i).edge,nve_tg]
!                vface_tg(i).nedge=vface_tg(i).nedge+1    
!                
!                if(vnode_tg(bn1(1)).surfin==vnode_tg(bn1(2)).surfin) then
!                    vedge_tg(nve_tg).marker=3 !3，两点共处一container的面 
!                    vedge_tg(nve_tg).Surfin=vnode_tg(bn1(1)).surfin                    
!                else
!                    vedge_tg(nve_tg).marker=4 !4，两点不共面
!                    vedge_tg(nve_tg).Surfin=vnode_tg(bn1(1)).surfin+vnode_tg(bn1(2)).surfin*10 !新生边节点所在的面                    
!                endif       
!            endif
!        enddo
!        
!        vface_tg(i).isclose=1
!        print *,'A1,i=',i
!        call vface_tg(i).update_face()
!
!
!    enddo
!    
!    !update cell
!    
!    do i=1,nvc_tg
!        if(vcell_tg(i).isclose>0) cycle !exclude cells with all nodes inside the container
!        n1=vcell_tg(i).nnode
!        if(vcell_tg(i).isclose==0) n1=vcell_tg(i).nnode-1
!        vcell_tg(i).node=pack(vcell_tg(i).node(:n1),vface_tg(vcell_tg(i).node(:n1)).isclose>0)
!        vcell_tg(i).nnode=size(vcell_tg(i).node)
!        n1=0
!        do j=1,vcell_tg(i).nnode
!            if(vface_tg(vcell_tg(i).node(j)).surfin>0) then
!                n1=n1+1
!                iar1(n1)=vface_tg(vcell_tg(i).node(j)).surfin
!                iar2(n1)=vface_tg(vcell_tg(i).node(j)).celoc
!            endif            
!        enddo
!        if(n1>1) then
!            if(all(iar1(:n1)-iar1(1)==0)) then !all new edge are coplan
!                !generate new face
!                nvf_tg=nvf_tg+1
!                if(nvf_tg+1>size(vface_tg)) call enlarge_ar(vface_tg,100)
!                vface_tg(nvf_tg).nedge=n1
!                vface_tg(nvf_tg).edge=iar2(:n2)
!                vface_tg(nvf_tg).isclose=1
!                vface_tg(nvf_tg).cell=[i,0]
!                print *,'A2,i=',nvf_tg
!                call vface_tg(nvf_tg).update_face()
!            endif
!        endif
!        
!    enddo
!    
!            
!
!        
!endsubroutine

    subroutine check_face_loop(this)
    !检查面的各线段是否首尾相连，不存在交叉。
        class(tetgen_element_tydef)::this
        integer::i,v1(2),v2(2),e1
        logical::ischk1=.false.
        
        v1=edge_tg(this.edge(1)).node
        
        do i=2,this.nedge
            e1=this.edge(i)
            if(e1<1) cycle
            v2=vedge_tg(e1).node
            
            ischk1=.true.
            if(v1(2)==v2(1)) then
                v1(2)=v2(2)
            elseif(v1(2)==v2(2)) then
                v1(2)=v2(1)
            else
               ischk1=.false.
            endif
            
            if(.not.ischk1.and.i==2) then
                if(v1(1)==v2(1)) then
                    v1(2)=v2(2)
                    ischk1=.true.
                elseif(v1(1)==v2(2)) then
                    v1(2)=v2(1)
                    ischk1=.true.
                endif
            endif            
            
            if(.not.ischk1) then
            endif
                
        enddo
        
    
    end subroutine
    
    subroutine update_face(this)
        class(tetgen_element_tydef)::this
        !logical,optional,intent(in)::isupdatecelladj
        !integer,intent(in)::iface
        real(8)::av1(3,3)    
        integer::i,j,e1,v1(2),n1,n2,n3,ic=0
        integer::node1(100),ischeck1(100),edge1(100)
        logical::isupdatecelladj1=.true.
        
            
        !set face node
        !ischeck1=0
        !ic=0
        !do while(any(ischeck1(:this.nedge)==0))
        !    ic=ic+1
        !    if(ic>this.nedge**2) then
        !        error stop 'failed to order the node.sub=update_face'                
        !    endif
        !    i=mod(ic-1,this.nedge)+1
        !    if(ischeck1(i)==1) cycle
        !    
        !    if(this.edge(i)<1) then
        !        ischeck1(i)=1
        !        cycle
        !    endif
        !    v1=vedge_tg(this.edge(i)).node
        !    if(i==1) then
        !        node1(1:2)=v1
        !        n1=2
        !        ischeck1(i)=1
        !        edge1(1)=this.edge(i)
        !    else
        !        do j=1,2
        !            if(node1(n1)==v1(j)) then
        !                n2=mod(j,2)+1
        !                n1=n1+1
        !                node1(n1)=v1(n2)
        !                if(n2==2) then
        !                    edge1(n1-1)=this.edge(i)
        !                else
        !                    edge1(n1-1)=-this.edge(i)
        !                endif
        !                ischeck1(i)=1
        !                exit
        !            elseif(node1(1)==v1(j)) then
        !                n2=mod(j,2)+1
        !                n1=n1+1
        !                node1(n1:2:-1)=node1(n1-1:1:-1)
        !                node1(1)=v1(n2)
        !                edge1(n1-1:2:-1)=edge1(n1-2:1:-1)
        !                if(n2==2) then
        !                    edge1(1)=-this.edge(i)
        !                else
        !                    edge1(1)=this.edge(i)
        !                endif
        !                ischeck1(i)=1
        !                exit
        !            endif
        !        enddo
        !                                   
        !    endif
        !enddo
        !
        !if(node1(1)==node1(n1)) then
        !    n1=n1-1 
        !endif
        call this.sort_face_edge(vedge_tg,nvnode_tg)
        !this.nnode=size(this.node) 
        !this.node=node1(1:n1)
        
        
        !进一步细分face类型
        if(this.isclose>0) then

            if(any(vnode_tg(node1(1:n1)).marker==0)) then
                if(any(vnode_tg(node1(1:n1)).marker>0)) then
                    this.isclose=-1 !mean close but have some vetexes outside the container.
                else
                    this.isclose=-2 !close but all vetexes outside the container.
                endif
                
            !else
            !    if(any(vcell_tg(this.cell).isclose==0)) then
            !        this.isclose=-3 !any its adjacent cells are not close.
            !    endif
            endif
        endif
        
        
        
        !if(.not.isupdatecelladj1) return
        !!让face.cell(1)存该面的右侧单元，cell(2)为其左侧单元(按tecplot fePloyHedron的格式)
        if(.not.allocated(this.v)) then
            !do i=1,2
            !    n1=abs(edge1(i))
            !    if(vedge_tg(n1).isclose>0) then
            !        if(edge1(i)>0) then
            !            n2=2;n3=1
            !        else
            !            n2=1;n3=2
            !        endif
            !        av1(:,1+i)=vnode_tg(vedge_tg(n1).node(n2)).x-vnode_tg(vedge_tg(n1).node(n3)).x
            !    else
            !        if(edge1(i)>0) then
            !            av1(:,1+i)=vedge_tg(n1).v
            !        else
            !            av1(:,1+i)=-vedge_tg(n1).v
            !        endif
            !    endif
            !enddo
            do i=1,3
                av1(:,i)=vnode_tg(this.node(i)).x
            enddo
            this.v=NORMAL_TRIFACE(av1)
            av1(:,1)=vnode_tg(maxval(this.node)).x
            av1(:,1)=node_tg(vcell_tg(this.cell(1)).cell(1)).x-av1(:,1)
            
            if(dot_product(av1(:,1),this.v)<0) then
                n1=this.cell(1)
                this.cell(1)=this.cell(2)
                this.cell(2)=n1
            endif
                
        endif        
        
    end subroutine  

end module