
  subroutine kpmesh
     use meshDS
	 use dflib
	 implicit none
	 integer::i,j,i_t,iflag=0,n1,allstate
	 logical::tof1
	 character*7::msg
	 real(8)::ccw,ar(2,3),coor(2),r	 !counterclockwise,reference to incircle().
	 type(element_tydef),pointer::ept_t
	 type(BP_tydef),pointer::cpp1	
	 integer,allocatable::node1(:)
	 !keypn=nnode
	 nelt=nelt+1
	 enumber=enumber+1
	 do i=1,3
	    node(-i).number=-i
	    node(-i).x=triangle(1,i)
      node(-i).y=triangle(2,i)
      elt(nelt).node(i)=-i
	 end do
	 elt(nelt).number=enumber
	 !initial edge array
	 if(.not.allocated(edge)) allocate(edge(maxnedge))
	 if(.not.allocated(cedge)) allocate(cedge(maxncedge))

	 do i=1,3
	 	if(nedge+1>maxnedge) call enlargeedge()
		nedge=nedge+1
		edge(nedge).v(1)=elt(nelt).node(i)
		edge(nedge).v(2)=elt(nelt).node(mod(i,3)+1)
		elt(nelt).edge(i)=nedge
		edge(nedge).e(1)=nelt
	 end do
	! nnode=nnode+3
     !keypn=5
	 !把有土层信息的点先插入
	 node1=pack([1:nnode],node(1:nnode).havesoildata==2)
	 node1=[node1,pack([1:nnode],node(1:nnode).havesoildata==1)]
	 node1=[node1,pack([1:nnode],node(1:nnode).havesoildata==0)]
	 !初始化iept
	 iept=1

	 do i=1,nnode
		n1=node1(i)
		call TRILOC(node(n1).x,node(n1).y)
		call GNM_Sloan(n1)
!		write(msg,'(i7)') i
!		call SETMESSAGEQQ(msg,QWIN$MSG_RUNNING) 
	 end do
	 !iept=>ehead
	
	 !利用cpphead(0)去检查是否所有的边都存在了。
     !if(allocated(cpphead)) deallocate(cpphead)
	 !allocate(cpphead(1))
	 !cpphead(0)=BNhead
	 !initilize the cedge
	 ncedge=0
	 do i=0,cln
		cpp=>cpphead(i)
		do while(associated(cpp))
			if(associated(cpp.next)) then
				ncedge=ncedge+1
				if(ncedge>maxncedge) then
					call enlargecedge()
				end if
				cedge(ncedge).v(1)=cpp.npt.number
				cedge(ncedge).v(2)=cpp.next.npt.number
                !if(cedge(ncedge).v(1)==cedge(ncedge).v(2)) then
                !    pause
                !endif
				cedge(ncedge).cl=i
			end if
			cpp=>cpp.next
			if(associated(cpp,cpphead(i))) exit
		end do
	 end do
	
	 deallocate(node1,stat=allstate)
!	 cpp1=>cpphead(0)
!	 open(10,file='bnode.dat',status='replace')
!	 do while(.true.)
!		write(10,'(20i5)') cpp1.npt.number
!		cpp1=>cpp1.next
!		if(associated(cpp1,bnhead)) exit
!	 end do
!	 close(10)


	 !i_t=cln
	 !cln=1
	 !call RCL
  	 !deallocate(cpphead)
	 !cln=i_t
	
	 !删去包有包含外包三角形顶点的单元
	 !call Removesupertri()

  end subroutine

!enlarge the size of array cedge by double its original size
subroutine enlargecedge()
	use meshDS
	implicit none
	type(constrained_edge_tydef),allocatable::cedge1(:)

	allocate(cedge1(maxncedge))
	cedge1=cedge
	deallocate(cedge)
	allocate(cedge(2*maxncedge))
	cedge(1:maxncedge)=cedge1
	deallocate(cedge1)
	maxncedge=2*maxncedge	

end subroutine

subroutine enlargeedge()
	use meshDS
	implicit none
	type(edge_tydef),allocatable::edge1(:)

	allocate(edge1(maxnedge))
	edge1=edge
	deallocate(edge)	
	allocate(edge(maxnedge+30000))
	edge(1:maxnedge)=edge1
	deallocate(edge1)
	maxnedge=maxnedge+30000	

end subroutine



subroutine rm(cslt)
	use meshDS
	implicit none
	integer::i,j,c1,c2,c3,iflag
	integer::count
	logical::tof
	real(8)::xt,yt,xm,ym  !xt,yt,为单元的形心坐标，xm,ym=yt为一个足够远的点，取为xm=-10e10,两者构造了一条水平射线
	real(8)::xa,ya,xb,yb  !
	real(8)::t1,t2,t3,t4
	type(constrainline_tydef)::cslt
	xm=-10e10

	iflag=1
	do ept=1,nelt
		if(elt(ept).isdel) cycle
		count=0
		xt=(node(elt(ept).node(1)).x+node(elt(ept).node(2)).x+node(elt(ept).node(3)).x)/3
		yt=(node(elt(ept).node(1)).y+node(elt(ept).node(2)).y+node(elt(ept).node(3)).y)/3
		ym=yt
		do i=1,cslt.num
			xa=cslt.conpoint(1,i)
			ya=cslt.conpoint(2,i)
			if(i==cslt.num) then
				xb=cslt.conpoint(1,1)
				yb=cslt.conpoint(2,1)
			else
				xb=cslt.conpoint(1,i+1)
				yb=cslt.conpoint(2,i+1)
			end if
			if(ya/=yb) then
				if(min(xa,xb)>=xt.or.max(ya,yb)<yt.or.min(ya,yb)>yt) then
					cycle
				else
					!if(xt>max(xa,xb).and.(min(ya,yb)<=yt.and.yt<=max(ya,yb))) then
					!  if(yt/=min(ya,yb)) count=count+1
					! cycle
					!end if
					!if(min(xa,xb)<=xt.and.xt<=max(xa,xb).and.min(ya,yb)<=yt.and.yt<=max(ya,yb)) then
					t1=(xt-xa)*(yb-ya)-(xb-xa)*(yt-ya)
					t2=(xb-xa)*(ym-ya)-(xm-xa)*(yb-ya)
					t3=(xa-xt)*(ym-yt)-(xm-xt)*(ya-yt)
					t4=(xm-xt)*(yb-yt)-(xb-xt)*(ym-yt)
					if(t1*t2>0.and.t3*t4>0)   count=count+1
					if(((t3==0).and.(ya>yb).and.(xa<=xt)).or.((t4==0).and.(yb>ya).and.(xb<=xt))) count=count+1	 !		
				end if
			end if
		end do

		if(mod(count,2)==0) 	call del_element(ept)

	end do


end subroutine

	 !删去包有包含外包三角形顶点的单元

subroutine RemoveSuperTri()
	use meshds
	implicit none

	integer::i,iflag,n1
	logical::tof1
	type(element_tydef),pointer::ept_t
	type(constrainline_tydef)::csl_t


	iflag=1
	do ept=1,nelt
		if(elt(ept).isdel) cycle
		tof1=(node(elt(ept).node(1)).number<0).or.(node(elt(ept).node(2)).number<0).or.(node(elt(ept).node(3)).number<0)
		if(tof1) call del_element(ept)
	end do

	call Rm(csl(0))

end subroutine

!delect elt(el)
subroutine del_element(el)
	use meshds
	implicit none
	integer::i,iflag
	integer,intent(in)::el

	iflag=1	
	do i=1,3
		if(elt(el).adj(i)>0) call EDG(elt(el).adj(i),el,-1,iflag)
	end do
	elt(el).isdel=.true.
	elt(el).kcd=0
	elt(el).adj=-1
	call del_element_update_edge(el)
	
end subroutine

!when ept_t is delected update edge() and adjlist()
subroutine	del_element_update_edge(el)
	use meshds
	implicit none
	integer::i,n1
	integer,intent(in)::el	

	do i=1,elt(el).nnum
		n1=elt(el).edge(i)
		if(edge(n1).e(1)==el) edge(n1).e(1)=-1
		if(edge(n1).e(2)==el) edge(n1).e(2)=-1
		if(edge(n1).e(1)==-1.and.edge(n1).e(2)==-1) then
			!update adjlist()
			call Removeadjlist(adjList,edge(n1).v(1),edge(n1).v(2))	
			!if edge.v=0 then the edge is invalid.
			edge(n1).v=0 
			 
		end if
    end do
    elt(el).nnum=0
			
end subroutine


subroutine linearsoilinterpolate_tri(ielt,inode)
    use meshDS
    integer,intent(in)::ielt,inode
    real(8)::shafun(3)=0,tri(2,3)
    integer::i,n1
    
    if(node(inode).havesoildata==2) return
      
    if(any(node(elt(ielt).node(1:3)).havesoildata==0)) return
    
    tri(1,:)=node(elt(ielt).node(1:3)).x
    tri(2,:)=node(elt(ielt).node(1:3)).y
    shafun=trishafun(tri,node(inode).x,node(inode).y)
    
    if(node(inode).havesoildata==0) then
        if(.not.allocated(node(inode).elevation)) then
            allocate(node(inode).elevation(0:soillayer))
            node(inode).elevation=-999.d0
        endif
        
        node(inode).havesoildata=minval(node(elt(ielt).node(1:3)).havesoildata)
        node(inode).elevation=shafun(1)*node(elt(ielt).node(1)).elevation+shafun(2)*node(elt(ielt).node(2)).elevation +shafun(3)*node(elt(ielt).node(3)).elevation
        if(node(inode).havesoildata==1) then
            do i=1,3
                node(inode).elevation=merge(node(inode).elevation,node(elt(ielt).node(i)).elevation, &
                    abs(node(elt(ielt).node(i)).elevation+999.d0)>1.e-7)
            enddo
        endif
        node(inode).havesoildata=2
        
    endif
    
    if(node(inode).havesoildata==1) then
        n1=0
        do i=0,soillayer
            if(abs(node(inode).elevation(i)+999.d0)<1.e-7) then
                if(any(abs(node(elt(ielt).node(1:3)).elevation(i)+999.d0)<1.e-7)) then
                    print *,'UNBALE TO INTERPOLATE. THE NODE(I) OF THE INDCLUDING ELEMENT(J) HAS UNKOWN ELEVATION IN LAYER(K). (I,J,K)= ',INODE,IELT,I   
                    n1=1
                else
                    node(inode).elevation(i)=dot_product(shafun,node(elt(ielt).node(1:3)).elevation(i))
                endif
            endif
        enddo
        if(n1==0) node(inode).havesoildata=2
    endif
    
contains
    
function trishafun(tri,x,y) result(shafun)
    implicit none
    real(8),intent(in)::tri(2,3),x,y
    real(8)::shafun(3)
    real(8)::a(3),b(3),c(3),t1
    integer::i
    
    
    a(1)=tri(1,2)*tri(2,3)-tri(1,3)*tri(2,2)
    a(2)=tri(1,3)*tri(2,1)-tri(1,1)*tri(2,3)
    a(3)=tri(1,1)*tri(2,2)-tri(1,2)*tri(2,1)
    b(1)=tri(2,2)-tri(2,3)
    b(2)=tri(2,3)-tri(2,1)
    b(3)=tri(2,1)-tri(2,2)
    c(1)=tri(1,3)-tri(1,2)
    c(2)=tri(1,1)-tri(1,3)
    c(3)=tri(1,2)-tri(1,1)
    t1=sum(a)
    if(abs(t1)<1d-14) then
        print *, 'the element area is zero. function=trishafun'
        stop
    endif
    shafun=(a+b*x+c*y)/t1
    return
endfunction
    
endsubroutine