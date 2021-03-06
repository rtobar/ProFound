.interp.2d=function(x, y, obj){
    if(length(x)>1e6){rembig=TRUE}else{rembig=FALSE}
    xobj = obj$x
    yobj = obj$y
    zobj = obj$z
    nx = length(xobj)
    ny = length(yobj)
    lx = approx(xobj, 1:nx, x, rule = 2)$y
    if(rembig){
      rm(x)
      invisible(gc())
    }
    ly = approx(yobj, 1:ny, y, rule = 2)$y
    if(rembig){
      rm(y)
      invisible(gc())
    }
    lx1 = floor(lx)
    ly1 = floor(ly)
    ex = lx - lx1
    if(rembig){
      rm(lx)
      invisible(gc())
    }
    ey = ly - ly1
    if(rembig){
      rm(ly)
      invisible(gc())
    }
    ex[lx1 == nx] = 1
    ey[ly1 == ny] = 1
    lx1[lx1 == nx] = nx - 1
    ly1[ly1 == ny] = ny - 1
    temp=rep(0,length(lx1))
    temp=zobj[cbind(lx1, ly1)] * (1 - ex) * (1 - ey)
    temp=temp+zobj[cbind(lx1 + 1, ly1)] * ex * (1 - ey)
    temp=temp+zobj[cbind(lx1, ly1 + 1)] * (1 - ex) * ey
    temp=temp+zobj[cbind(lx1 + 1, ly1 + 1)] * ex * ey
    invisible(temp)
}

.subgrid=function(dim=c(100,100), grid=c(10,10)){
  xhimult=ceiling(dim[1]/grid[1])
  yhimult=ceiling(dim[2]/grid[2])
  xhipix=xhimult*grid[1]
  yhipix=yhimult*grid[2]
  expandlen=xhipix*yhipix
  gridlen=prod(grid)
  tempgrid=matrix(0,expandlen,3)
  tempgrid[,1]=rep(rep(1:grid[1],each=grid[2]),times=expandlen/gridlen)+rep(rep(seq(0,(xhimult-1)*grid[1],by=grid[1]),each=gridlen),times=yhimult)
  tempgrid[,2]=rep(rep(1:grid[2],times=grid[1]),times=expandlen/gridlen)+rep(rep(seq(0,(yhimult-1)*grid[2],by=grid[2]),each=gridlen),each=xhimult)
  tempgrid[,3]=rep(1:(xhimult*yhimult),each=gridlen)
  tempgrid=tempgrid[tempgrid[,1]<=dim[1] & tempgrid[,2]<=dim[2],]
  #tempmat=matrix(0,dim[1],dim[2])
  tempgrid=tempgrid[order(tempgrid[,2],tempgrid[,1]),3]
  #tempmat[]=tempgrid[,3]
  invisible(tempgrid)
}

.interp.2d.akima=function (x, y, z, xo, yo, ncp = 0, extrap = FALSE, duplicate = "error", 
    dupfun = NULL){
    if (!(all(is.finite(x)) && all(is.finite(y)) && all(is.finite(z)))) 
        stop("missing values and Infs not allowed")
    if (is.null(xo)) 
        stop("xo missing")
    if (is.null(yo)) 
        stop("yo missing")
    if (ncp > 25) {
        ncp <- 25
        cat("ncp too large, using ncp=25\n")
    }
    drx <- diff(range(x))
    dry <- diff(range(y))
    if (drx == 0 || dry == 0) 
        stop("all data collinear")
    if (drx/dry > 10000 || drx/dry < 1e-04) 
        stop("scales of x and y are too dissimilar")
    n <- length(x)
    np <- length(xo)
    if (length(yo) != np) 
        stop("length of xo and yo differ")
    if (length(y) != n || length(z) != n) 
        stop("Lengths of x, y, and z do not match")
    xy <- paste(x, y, sep = ",")
    i <- match(xy, xy)
    if (duplicate == "user" && !is.function(dupfun)) 
        stop("duplicate=\"user\" requires dupfun to be set to a function")
    if (duplicate != "error") {
        centre <- function(x) {
            switch(duplicate, mean = mean(x), median = median(x), 
                user = dupfun(x))
        }
        if (duplicate != "strip") {
            z <- unlist(lapply(split(z, i), centre))
            ord <- !duplicated(xy)
            x <- x[ord]
            y <- y[ord]
            n <- length(x)
        }
        else {
            ord <- (hist(i, plot = FALSE, freq = TRUE, breaks = seq(0.5, 
                max(i) + 0.5, 1))$counts == 1)
            x <- x[ord]
            y <- y[ord]
            z <- z[ord]
            n <- length(x)
        }
    }
    else if (any(duplicated(xy))) 
        stop("duplicate data points")
    zo <- rep(0, np)
    storage.mode(zo) <- "double"
    miss <- !extrap
    misso <- seq(miss, np)
    if (extrap & ncp == 0) 
        warning("Cannot extrapolate with linear option")
    ans <- .Fortran("idbvip", as.integer(1), as.integer(ncp), 
        as.integer(n), as.double(x), as.double(y), as.double(z), 
        as.integer(np), x = as.double(xo), y = as.double(yo), 
        z = zo, integer((31 + ncp) * n + np), double(8 * n), 
        misso = as.logical(misso), PACKAGE = "akima")
    temp <- ans[c("x", "y", "z", "misso")]
    temp$z[temp$misso] <- NA
    temp[c("x", "y", "z")]
}

.quickclip=function(flux){
  sel=magclip(flux, estimate='lo')$x
  invisible(list(sky=median(sel, na.rm=TRUE), skyRMS=sd(sel, na.rm=TRUE)))
}

profoundSkyEst=function(image=NULL, objects=NULL, mask=NULL, cutlo=cuthi/2, cuthi=sqrt(sum((dim(image)/2)^2)), skycut='auto', clipiters=5, radweight=0, plot=FALSE, ...){
  radweight=-radweight
  xlen=dim(image)[1]
  ylen=dim(image)[2]
  tempref=as.matrix(expand.grid(1:xlen,1:ylen))
  xcen=xlen/2; ycen=ylen/2
  temprad=sqrt((tempref[,1]-xcen)^2+(tempref[,2]-ycen)^2)
  #Keep only pixels inside the radius bounds given by cutlo and cuthi
  if(!is.null(mask)){
    keep=temprad>=cutlo & temprad<=cuthi & mask==0
  }else{
    keep=TRUE
  }
  if(!is.null(objects)){
    keep=temprad>=cutlo & temprad<=cuthi & objects==0 & keep
  }
  tempref=tempref[keep,]
  tempval=image[tempref]
  temprad=temprad[keep]
  clip=magclip(tempval, sigma=skycut, estimate='lo')
  tempval=tempval[clip$clip]
  temprad=temprad[clip$clip]
  #Find the running medians for the data
  tempmedian=magrun(x=temprad,y=tempval,ranges=NULL,binaxis='x',Nscale=T)
  if(plot){magplot(density(tempval),...)}
  tempylims=tempmedian$ysd
  tempy=tempmedian$y
  #Calculate worst case sky error- the sd of the medians calculated
  skyerr=sd(tempy, na.rm=TRUE)
  #Gen weights to use for weighted mean sky finding. This also weights by separation from the object of interest via radweight
  weights=1/((tempmedian$x^radweight)*(tempylims[,2]-tempylims[,1])/2)^2
  #Find the weighted mean of the medians
  sky=sum(tempy*weights)/(sum(weights))
  #Now we iterate until no running medians are outside the 1-sigma bound of the sky
  select=tempylims[,1]<=sky & tempylims[,2]>=sky
  Nselect=length(which(select))
  Nselect_old=0
  while(Nselect!=Nselect_old){
    Nselect_old=length(which(select))
    newtempy=tempy[select]
    newweights=weights[select]
    sky=sum(newtempy*newweights)/(sum(newweights))
    select=tempylims[,1]<=sky & tempylims[,2]>=sky
    Nselect=length(which(select))
  }
  #Find the number of running medians that agree with the final sky within error bounds (max=10)
  Nnearsky=length(which(select))
  if(Nnearsky>=1){
    skyRMS=mean((tempylims[select,2]-tempylims[select,1])/2)*sqrt(mean(tempmedian$Nbins[select]))
  }else{
    skyRMS=mean((tempylims[,2]-tempylims[,1])/2)*sqrt(mean(tempmedian$Nbins))
  }
  if(plot){
    lines(seq(sky-5*skyRMS, sky+5*skyRMS, len=1e3), dnorm(seq(sky-5*skyRMS, sky+5*skyRMS, len=1e3), mean=sky, sd=skyRMS), col='red')
    abline(v=c(sky-skyerr,sky,sky+skyerr),lty=c(3,1,3),col='blue')
    abline(v=c(sky-skyRMS,sky+skyRMS),lty=2,col='red')
    legend('topleft', legend=c('Sky Data', 'Sky Level', 'Sky RMS'), lty=1, col=c('black','blue','red'))
  }
  invisible(list(sky=sky,skyerr=skyerr,skyRMS=skyRMS,Nnearsky=Nnearsky,radrun=tempmedian))
}

profoundSkyEstLoc=function(image=NULL, objects=NULL, mask=NULL, loc=dim(image)/2, box=c(100,100), skytype='median', skyRMStype='quanlo', sigmasel=1, skypixmin=prod(box)/2, boxadd=box/2, boxiters=0, doclip=TRUE, shiftloc = FALSE, paddim = TRUE, plot=FALSE, ...){
  if(!is.null(objects) | !is.null(mask)){
    # if(!is.null(objects)){
    #   tempobj=magcutout(image=objects, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image==0
    #   tempobj[is.na(tempobj)]=0
    # }else{
    #   tempobj=TRUE
    # }
    # if(!is.null(mask)){
    #   tempmask=magcutout(image=mask, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image==0
    #   tempmask[is.na(tempmask)]=1
    # }else{
    #   tempmask=TRUE
    # }
    skyN=0
    iterN=0
    tempcomb={}
    while(skyN<skypixmin & iterN<=boxiters){
      if(!is.null(objects)){
        tempcomb=magcutout(image=objects, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image==0
        if(!is.null(mask)){
          tempcomb=tempcomb+(magcutout(image=mask, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image==0)
        }
      }else{
        tempcomb=magcutout(image=mask, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image==0
      }
      tempcomb[is.na(tempcomb)]=FALSE
      tempcomb=which(tempcomb)
      skyN=length(tempcomb)
      box=box+boxadd
      iterN=iterN+1
    }
    box=box-boxadd #since one too many boxadds will have occurred when it terminates

    if(skyN>0){
      select=magcutout(image, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image[tempcomb]
    }else{
      select=NA
    }
  }else{
    select=magcutout(image, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image
  }
  if(plot){
    image=magcutout(image, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image
    imout=magimage(image, ...)
    if(!is.null(mask)){
      contour(x=imout$x, y=imout$y, magcutout(mask, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image, add=T, col='red', drawlabels = FALSE, zlim=c(0,1), nlevels = 1)
    }
    if(!is.null(objects)){
      contour(x=imout$x, y=imout$y, magcutout(objects, loc=loc, box=box, shiftloc=shiftloc, paddim=paddim)$image, add=T, col='blue', drawlabels = FALSE, zlim=c(0,1), nlevels = 1)
    }
  }
  if(doclip){
    suppressWarnings({clip=magclip(select, sigmasel=sigmasel, estimate = 'lo')$x})
  }else{
    clip=select
  }
  
  if(skytype=='median'){
    skyloc=median(clip, na.rm=TRUE)
  }else if(skytype=='mean'){
    skyloc=mean(clip, na.rm=TRUE)
  }else if(skytype=='mode'){
    temp=density(clip, na.rm=TRUE)
    skyloc=temp$x[which.max(temp$y)]
  }
  
  if(skyRMStype=='quanlo'){
    temp=clip-skyloc
    temp=temp[temp<0]
    skyRMSloc=abs(as.numeric(quantile(temp, pnorm(-sigmasel)*2, na.rm=TRUE)))/sigmasel
  }else if(skyRMStype=='quanhi'){
    temp=clip-skyloc
    temp=temp[temp>0]
    skyRMSloc=abs(as.numeric(quantile(temp, (pnorm(sigmasel)-0.5)*2, na.rm=TRUE)))/sigmasel
  }else if(skyRMStype=='quanboth'){
    temp=clip-skyloc
    templo=temp[temp<0]
    temphi=temp[temp>0]
    skyRMSloclo=abs(as.numeric(quantile(templo, pnorm(-sigmasel)*2, na.rm=TRUE)))/sigmasel
    skyRMSlochi=abs(as.numeric(quantile(temphi, (pnorm(sigmasel)-0.5)*2, na.rm=TRUE)))/sigmasel
    skyRMSloc=(skyRMSloclo+skyRMSlochi)/2
  }else if(skyRMStype=='sd'){
    skyRMSloc=sqrt(.varwt(clip, wt=1, xcen=skyloc))
  }
  
  invisible(list(val=c(skyloc, skyRMSloc), clip=clip))
}

profoundMakeSkyMap=function(image=NULL, objects=NULL, mask=NULL, box=c(100,100), grid=box, skytype='median', skyRMStype='quanlo', sigmasel=1, skypixmin=prod(box)/2, boxadd=box/2, boxiters=0, doclip=TRUE, shiftloc = FALSE, paddim = TRUE, cores=1){
  xseq=seq(grid[1]/2,dim(image)[1],by=grid[1])
  yseq=seq(grid[2]/2,dim(image)[2],by=grid[2])
  tempgrid=expand.grid(xseq, yseq)
  registerDoParallel(cores=cores)
  i=NULL
  tempsky=foreach(i = 1:dim(tempgrid)[1], .combine='rbind')%dopar%{
    profoundSkyEstLoc(image=image, objects=objects, mask=mask, loc=as.numeric(tempgrid[i,]), box=box, skytype=skytype, skyRMStype=skyRMStype, sigmasel=sigmasel, skypixmin=skypixmin, boxadd=boxadd, boxiters=boxiters, doclip=doclip, shiftloc=shiftloc, paddim=paddim)$val
  }
  tempmat_sky=matrix(tempsky[,1],length(xseq))
  tempmat_skyRMS=matrix(tempsky[,2],length(xseq))
  tempmat_sky[is.na(tempmat_sky)]=median(tempmat_sky, na.rm = TRUE)
  tempmat_skyRMS[is.na(tempmat_skyRMS)]=median(tempmat_skyRMS, na.rm = TRUE)
  invisible(list(sky=list(x=xseq, y=yseq, z=tempmat_sky), skyRMS=list(x=xseq, y=yseq, z=tempmat_skyRMS)))
}

profoundMakeSkyGrid=function(image=NULL, objects=NULL, mask=NULL, box=c(100,100), grid=box, type='bicubic', skytype='median', skyRMStype='quanlo', sigmasel=1, skypixmin=prod(box)/2, boxadd=box/2, boxiters=0, doclip=TRUE, shiftloc = FALSE, paddim = TRUE, cores=1){
  if(length(image)>1e6){rembig=TRUE}else{rembig=FALSE}
  if(rembig){
    invisible(gc())
  }
  if(!requireNamespace("akima", quietly = TRUE)){
    if(type=='bicubic'){
      stop('The akima package is needed for bicubic interpolation to work. Please install it from CRAN.', call. = FALSE)
    }
    if(type=='bilinear'){
      useakima=FALSE
    }
  }else{
    useakima=TRUE
  }
  
  xseq=seq(grid[1]/2,dim(image)[1],by=grid[1])
  yseq=seq(grid[2]/2,dim(image)[2],by=grid[2])
  tempgrid=expand.grid(xseq, yseq)
  registerDoParallel(cores=cores)
  i=NULL
  tempsky=foreach(i = 1:dim(tempgrid)[1], .combine='rbind')%dopar%{
    profoundSkyEstLoc(image=image, objects=objects, mask=mask, loc=as.numeric(tempgrid[i,]), box=box, skytype=skytype, skyRMStype=skyRMStype, sigmasel=sigmasel, skypixmin=skypixmin, boxadd=boxadd, boxiters=boxiters, doclip=doclip, shiftloc=shiftloc, paddim=paddim)$val
  }
  
  xseq=c(-grid[1]/2,xseq,max(xseq)+grid[1]/2)
  yseq=c(-grid[2]/2,yseq,max(yseq)+grid[2]/2)
  
  tempmat_sky=matrix(0,length(xseq),length(yseq))
  tempmat_sky[2:(length(xseq)-1),2:(length(yseq)-1)]=tempsky[,1]
  tempmat_sky[is.na(tempmat_sky)]=median(tempmat_sky, na.rm = TRUE)
  
  tempmat_skyRMS=matrix(0,length(xseq),length(yseq))
  tempmat_skyRMS[2:(length(xseq)-1),2:(length(yseq)-1)]=tempsky[,2]
  tempmat_skyRMS[is.na(tempmat_skyRMS)]=median(tempmat_skyRMS, na.rm = TRUE)
  
  tempmat_sky[1,]=tempmat_sky[2,]*2-tempmat_sky[3,]
  tempmat_sky[length(xseq),]=tempmat_sky[length(xseq)-1,]*2-tempmat_sky[length(xseq)-2,]
  tempmat_sky[,1]=tempmat_sky[,2]*2-tempmat_sky[,3]
  tempmat_sky[,length(yseq)]=tempmat_sky[,length(yseq)-1]*2-tempmat_sky[,length(yseq)-2]
  
  tempmat_skyRMS[1,]=tempmat_skyRMS[2,]*2-tempmat_skyRMS[3,]
  tempmat_skyRMS[length(xseq),]=tempmat_skyRMS[length(xseq)-1,]*2-tempmat_skyRMS[length(xseq)-2,]
  tempmat_skyRMS[,1]=tempmat_skyRMS[,2]*2-tempmat_skyRMS[,3]
  tempmat_skyRMS[,length(yseq)]=tempmat_skyRMS[,length(yseq)-1]*2-tempmat_skyRMS[,length(yseq)-2]
  
  if(rembig){
    invisible(gc())
  }
  
  if(dim(tempmat_sky)[1]>1){
    
    #expand out map here!! and then use akima::bilinear function
    
    bigridx=rep(1:dim(image)[1]-0.5,times=dim(image)[2])
    bigridy=rep(1:dim(image)[2]-0.5,each=dim(image)[1])
    
    if(type=='bilinear'){
      #The below seems fastest and uses least memory for linear. Still need akima!
      if(useakima){
        tempgrid=expand.grid(xseq, yseq)
        temp_bi_sky=.interp.2d.akima(x=tempgrid[,1], y=tempgrid[,2], z=as.numeric(tempmat_sky),xo=bigridx, yo=bigridy)$z
        temp_bi_skyRMS=.interp.2d.akima(x=tempgrid[,1], y=tempgrid[,2], z=as.numeric(tempmat_skyRMS),xo=bigridx, yo=bigridy)$z
      }else{
        temp_bi_sky=.interp.2d(bigridx, bigridy, list(x=xseq, y=yseq, z=tempmat_sky))
        temp_bi_skyRMS=.interp.2d(bigridx, bigridy, list(x=xseq, y=yseq, z=tempmat_skyRMS))
      }
      #temp_bi_sky=akima::bilinear(xseq, yseq, tempmat_sky, bigridx, bigridy)$z
      #temp_bi_skyRMS=akima::bilinear(xseq, yseq, tempmat_skyRMS, bigridx, bigridy)$z
    }else if(type=='bicubic'){
      temp_bi_sky=akima::bicubic(xseq, yseq, tempmat_sky, bigridx, bigridy)$z
      temp_bi_skyRMS=akima::bicubic(xseq, yseq, tempmat_skyRMS, bigridx, bigridy)$z
    }
    
    if(rembig){
      rm(bigridx)
      rm(bigridy)
      invisible(gc())
    }
  
    temp_bi_sky=matrix(temp_bi_sky, dim(image)[1])
    temp_bi_skyRMS=matrix(temp_bi_skyRMS, dim(image)[1])
  }else{
    temp_bi_sky=matrix(tempmat_sky[1,1], dim(image)[1], dim(image)[2])
    temp_bi_skyRMS=matrix(tempmat_skyRMS[1,1], dim(image)[1], dim(image)[2])
  }
  
  invisible(list(sky=temp_bi_sky, skyRMS=temp_bi_skyRMS))
}

#Alas, the quick function does not appear to be quicker than the current profoundMakeSkyGrid function. Oh well, worth try.

.profoundQuickSky=function(image, box=c(100,100)){
  tempIDs=.subgrid(dim(image), grid=box)
  tempDT=data.table(flux=as.numeric(image), subset=tempIDs)
  setkey(tempDT, subset)
  flux=NULL
  invisible(tempDT[,.quickclip(flux),by=subset])
}
