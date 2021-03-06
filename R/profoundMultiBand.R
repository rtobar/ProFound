profoundMultiBand=function(inputlist=NULL, dir='', segim=NULL, mask=NULL, iters_det=6, iters_tot=0, detectbands='r', multibands=c('u','g','r','i','z'), magzero=0, gain=NULL, bandappend=multibands, totappend='t', colappend='c', grpappend='g', dotot=TRUE, docol=TRUE, dogrp=TRUE, deblend=FALSE, groupstats=FALSE, ...){
  
  # v1.1 of the multiband function
  # Written and maintained by Aaron Robotham (inspired by scripts by Soheil Koushan and Simon Driver)
  # This should only be sourced, for *any* modifications contact Aaron Robotham
  
  # The most important thing is that all of the input images must be pixel matched via SWarp or magwarp etc
  # detectbands and multibands are the names of the target bands, which should be the names of the images ignoring the .fits ending
  # By default Simon's script names them as u.fits and g.fits etc, hence the literal bands naming
  # detectbands can be a vector of target detection bands for stacking
  # multibands is by default a vector of all SDSS optical bands
  # You can select whether to do total and/or colour photometry with dotot and docol
  # magzero must be matched to the number of bands in multibands (which reflects the magzero in each respectively), or one value which is then recycled
  # bandappend are the band names to use as the extra tag attached to the column names in the cat_tot and cat_col outputs (by default this is linked to multibands)
  # totappend and colapped is just the extra tag attached to the column names in the cat_tot and cat_col outputs
  
  timestart=proc.time()[3]
  
  call=match.call()
  
  dots=list(...)
  
  dotsignoredetect=c('iters', 'sky', 'skyRMS', 'deblend', 'plot', 'stats', 'haralickstats')
  dotsignoremulti=c('skycut', 'pixcut', 'tolerance', 'ext', 'sigma', 'smooth', 'iters', 'sky', 'skyRMS', 'plot', 'stats', 'redosegim', 'roughpedestal', 'haralickstats')
  
  if(length(dots)>0){
  dotsdetect=dots[! names(dots) %in% dotsignoredetect]
  dotsmulti=dots[! names(dots) %in% dotsignoremulti]
}else{
  dotsdetect={}
  dotsmulti={}
}
  
  # Restrict outselves to data actually present (no matter what is asked for)
  
  if(is.null(inputlist)){
    presentbands=unlist(strsplit(list.files(dir), split='.fits'))
  }else{
    if(length(inputlist)!=length(multibands)){
      stop('inputlist is not the same length as multibands!')
    }
    presentbands=multibands
  }
  
  if(multibands[1]=='get'){
    multibands=presentbands
  }
  
  if(detectbands[1]=='get'){
    detectbands=presentbands
  }
  if(detectbands[1]=='all'){
    detectbands=multibands
  }
  detectbands=detectbands[detectbands %in% presentbands]
  
  if(bandappend[1]=='get'){
    bandappend=presentbands
  }
  
  if(length(iters_tot)==1){
    iters_tot=rep(iters_tot, length(multibands))
  }
  
  if(length(iters_tot)!=length(iters_tot)){
    stop('Length of iters_tot must equal length of multibands!')
  }
  
  if(length(magzero)==1){
    magzero=rep(magzero, length(multibands))
  }
  
  if(length(magzero)!=length(multibands)){
    stop('Length of magzero must equal length of multibands!')
  }
  
  if(length(gain)==1){
    gain=rep(gain, length(multibands))
  }
  
  if(is.null(gain)==FALSE & length(gain)!=length(multibands)){
    stop('Length of gain must equal length of multibands!')
  }
  
  #if(dogrp & boundstats==FALSE){
  #  stop('If dogrp=TRUE than boundstats=TRUE must also be set!')
  #}
  
  magzero=magzero[which(multibands %in% presentbands)]
  magzero=magzero[!is.na(magzero)]
  bandappend=bandappend[which(multibands %in% presentbands)]
  bandappend=bandappend[!is.na(bandappend)]
  if(!is.null(gain)){
    gain=gain[which(multibands %in% presentbands)]
    gain=gain[!is.na(gain)]
  }
  multibands=multibands[which(multibands %in% presentbands)]
  multibands=multibands[!is.na(multibands)]
  
  # Some safety checks
  
  if(!is.null(gain)){
    if(length(unique(c(length(multibands), length(magzero), length(bandappend), length(gain))))!=1){
      stop('multibands, magzero, bandappend and gain are not all the same length - they must be!')
    }
  }else{
    if(length(unique(c(length(multibands), length(magzero), length(bandappend))))!=1){
      stop('multibands, magzero and bandappend are not all the same length - they must be!')
    }
  }
  if(!is.null(inputlist)){
    if(length(unique(c(length(multibands),length(inputlist))))!=1){
      stop('inputlist does not match the length of multibands - it must be!')
    }
  }
  
  message(paste('*** Will use',paste(detectbands,collapse=''),'for source detection ***'))
  if(!is.null(segim)){
    message('*** Will use provided segim for detection statistics ***')
  }
  
  if(dotot | docol | dogrp){
    message(paste('*** Will use',paste(multibands,collapse=''),'for multi band photometry ***'))
    message(paste('*** Magzero:',paste(multibands,magzero,sep='=', collapse=' '),' ***'))
    if(!is.null(gain)){
      message(paste('*** Gain:',paste(multibands,gain,sep='=', collapse=' '),' ***'))
    }else{
      message('*** Gain: not specified for any bands, so shot-noise will be ignored ***')
    }
    
    if(dotot){
      message('*** Will compute total multi band photometry ***')
    }
    if(docol){
      message('*** Will compute isophotal colour multi band photometry ***')
    }
    if(dogrp){
      message('*** Will compute grouped segment multi band photometry ***')
    }
  }
  
  if(length(detectbands)==1){
    
    # If only one band is specified for detection then we skip the stacking part
    
    message(paste('*** Currently processing single detection band',detectbands,'***'))
    if(is.null(inputlist)){
      detect=readFITS(paste0(dir,detectbands,'.fits'))
    }else{
      detect=inputlist[[which(multibands==detectbands)]]
    }
    temp_magzero=magzero[multibands==detectbands]
    
    # pro_detect=profoundProFound(image=detect, segim=segim, mask=mask, skycut=skycut, pixcut=pixcut, tolerance=tolerance, ext=ext, sigma=sigma, smooth=smooth, iters=iters_det, magzero=temp_magzero, verbose=verbose, boundstats=boundstats, groupstats=(groupstats | dogrp), groupby=groupby, haralickstats=haralickstats, ...)
    
    pro_detect=do.call("profoundProFound", c(list(image=detect, segim=segim, mask=mask, iters=iters_det, magzero=temp_magzero, deblend=FALSE, groupstats=(groupstats | dogrp)), dotsdetect))
    
  }else{
  
    # Multiple detection bands requested, so we prepare lists for stacking
    
    detect_image=list()
    detect_sky=list()
    detect_skyRMS=list()
    detect_magzero={}
    
    for(i in 1:length(detectbands)){
      
      # Loop around detection bands
      
      message(paste('*** Currently processing detection band',detectbands[i],'***'))
      
      if(is.null(inputlist)){
        detect=readFITS(paste0(dir,detectbands[i],'.fits'))
      }else{
        detect=inputlist[[which(multibands==detectbands[i])]]
      }
      temp_magzero=magzero[multibands==detectbands[i]]
      
      # Run ProFound on current detection band with input parameters
      
      # pro_detect=profoundProFound(image=detect, segim=segim, mask=mask, skycut=skycut, pixcut=pixcut, tolerance=tolerance, ext=ext, sigma=sigma, smooth=smooth, iters=iters_det, magzero=temp_magzero, verbose=verbose, ...)
      
      pro_detect=do.call("profoundProFound", c(list(image=detect, segim=segim, mask=mask, iters=iters_det, magzero=temp_magzero, deblend=FALSE, groupstats=FALSE), dotsdetect))
      
      # Append to lists for stacking
      
      detect_image=c(detect_image,list(pro_detect$image))
      detect_sky=c(detect_sky,list(pro_detect$sky))
      detect_skyRMS=c(detect_skyRMS,list(pro_detect$skyRMS))
      detect_magzero=c(detect_magzero, temp_magzero)
    }
    
    # Grab the current header
    
    header=pro_detect$header
    
    # Delete and clean up
    
    rm(detect)
    rm(pro_detect)
    gc()
    
    # Stack!!!
    # We first stack the image then the sky.
    
    detect_image_stack=profoundMakeStack(image_list=detect_image, sky_list=detect_sky, skyRMS_list=detect_skyRMS, magzero_in=detect_magzero, magzero_out=detect_magzero[1])
    detect_sky_stack=profoundMakeStack(image_list=detect_sky, skyRMS_list=detect_skyRMS, magzero_in=detect_magzero, magzero_out=detect_magzero[1])
    
    # Delete and clean up
    
    rm(detect_image)
    rm(detect_skyRMS)
    gc()
    
    message('*** Currently processing stacked detection image ***')
    
    # For reference we run ProFound with the stacked sky added back in, passing it the stacked sky too.
    
    #pro_detect=profoundProFound(image=detect_image_stack$image+detect_sky_stack$image, segim=segim, mask=mask, header=header, skycut=skycut, pixcut=pixcut, tolerance=tolerance, ext=ext, sigma=sigma,  smooth=smooth, iters=iters_det, magzero=detect_magzero[1], sky=detect_sky_stack$image, skyRMS=detect_image_stack$skyRMS, redosky=FALSE, verbose=verbose, boundstats=boundstats, groupstats=(groupstats | dogrp), groupby=groupby, haralickstats=haralickstats, ...)
    
    pro_detect=do.call("profoundProFound", c(list(image=detect_image_stack$image+detect_sky_stack$image, segim=segim, mask=mask, header=header, iters=iters_det, magzero=detect_magzero[1], sky=detect_sky_stack$image, skyRMS=detect_image_stack$skyRMS, redosky=FALSE, deblend=FALSE, groupstats=(groupstats | dogrp)), dotsdetect))
    
    # Delete and clean up
    
    rm(detect_image_stack)
    rm(detect_sky_stack)
    gc()
  }
  
  pro_detect$call=NULL
  
  # Create base total and colour photometry catalogues

  cat_tot=NULL
  cat_col=NULL
  cat_grp=NULL
  
  if(dotot | docol | dogrp){
    
    if(dotot){
      cat_tot=data.frame(segID=pro_detect$segstats$segID)
    }
    
    if(docol){
      cat_col=data.frame(segID=pro_detect$segstats$segID)
    }
    
    if(dogrp){
      cat_grp=data.frame(groupID=pro_detect$group$groupsegID$groupID)
    }
    
    for(i in 1:length(multibands)){
      
      # Loop around multi bands
      
      message(paste('*** Currently processing multi band',multibands[i],'***'))
      
      if(is.null(inputlist)){
        multi=readFITS(paste0(dir,multibands[i],'.fits'))
      }else{
        multi=inputlist[[i]]
      }
      
      if(dotot){
        
        # Compute total multi band photometry, allowing some extra dilation via the iters_tot argument
        
        # pro_multi_tot=profoundProFound(image=multi, segim=pro_detect$segim, mask=mask, magzero=magzero[i], gain=gain[i], boundstats=boundstats, groupstats=FALSE, iters=iters_tot[i], verbose=verbose, ...)
        
        pro_multi_tot=do.call("profoundProFound", c(list(image=multi, segim=pro_detect$segim, mask=mask, magzero=magzero[i], gain=gain[i], groupstats=FALSE, iters=iters_tot[i], deblend=deblend, redosegim=FALSE, roughpedestal=FALSE), dotsmulti))
        
        # Append column names and concatenate cat_tot together
        
        setnames(pro_multi_tot$segstats, paste0(names(pro_multi_tot$segstats), '_', bandappend[i], totappend))
        cat_tot=cbind(cat_tot, pro_multi_tot$segstats)
        
      }
      
      if(docol){
        
        # Compute colour multi band photometry
        # If we have already run the total photometry then we use the sky and skyRMS computed there for speed
        
        if(dotot){
          #pro_multi_col=profoundProFound(image=multi, segim=pro_detect$segim_orig, mask=mask, sky=pro_multi_tot$sky, skyRMS=pro_multi_tot$skyRMS, redosky=FALSE, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, boundstats=boundstats, groupstats=FALSE, iters=0, verbose=verbose, ...)$segstats
          
          pro_multi_col=do.call("profoundProFound", c(list(image=multi, segim=pro_detect$segim_orig, mask=mask, sky=pro_multi_tot$sky, skyRMS=pro_multi_tot$skyRMS, redosky=FALSE, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, groupstats=FALSE, iters=0, deblend=FALSE, redosegim=FALSE, roughpedestal=FALSE), dotsmulti))$segstats
        }else{
          #pro_multi_col=profoundProFound(image=multi, segim=pro_detect$segim_orig, mask=mask, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, boundstats=boundstats, groupstats=FALSE, iters=0, verbose=verbose, ...)$segstats
          
          pro_multi_col=do.call("profoundProFound", c(list(image=multi, segim=pro_detect$segim_orig, mask=mask, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, groupstats=FALSE, iters=0, deblend=FALSE, redosegim=FALSE, roughpedestal=FALSE), dotsmulti))$segstats
        }
        
        # Append column names and concatenate cat_col together
        
        setnames(pro_multi_col, paste0(names(pro_multi_col), '_', bandappend[i], colappend))
        cat_col=cbind(cat_col, pro_multi_col)
      }
      
      if(dogrp){
        
        # Compute group multi band photometry
        # If we have already run the total photometry then we use the sky and skyRMS computed there for speed
        
        if(dotot){
        #   # pro_multi_grp=profoundProFound(image=multi, segim=pro_detect$group$groupim, mask=mask, sky=pro_multi_tot$sky, skyRMS=pro_multi_tot$skyRMS, redosky=FALSE, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, boundstats=boundstats, groupstats=FALSE, iters=0, verbose=verbose, ...)$segstats
        #   
          pro_multi_grp=do.call("profoundProFound", c(list(image=multi, segim=pro_detect$group$groupim, mask=mask, sky=pro_multi_tot$sky, skyRMS=pro_multi_tot$skyRMS, redosky=FALSE, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, groupstats=FALSE, iters=iters_tot[i], deblend=FALSE, redosegim=FALSE, roughpedestal=FALSE), dotsmulti))$segstats
        }else{
        #   # pro_multi_grp=profoundProFound(image=multi, segim=pro_detect$group$groupim, mask=mask, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, boundstats=boundstats, groupstats=FALSE, iters=0, verbose=verbose, ...)$segstats
        #   
          pro_multi_grp=do.call("profoundProFound", c(list(image=multi, segim=pro_detect$group$groupim, mask=mask, magzero=magzero[i], gain=gain[i], objects=pro_detect$objects, groupstats=FALSE, iters=iters_tot[i], deblend=FALSE, redosegim=FALSE, roughpedestal=FALSE), dotsmulti))$segstats
        }
        
        # Append column names and concatenate cat_grp together
        names(pro_multi_grp)[1]='groupID'
        setnames(pro_multi_grp, paste0(names(pro_multi_grp), '_', bandappend[i], grpappend))
        cat_grp=cbind(cat_grp, pro_multi_grp)
      }
    }
  }
  
  # Return all of the things!
  
  output=list(pro_detect=pro_detect, cat_tot=cat_tot, cat_col=cat_col, cat_grp=cat_grp, detectbands=detectbands, multibands=multibands, call=call, date=date(), time=proc.time()[3]-timestart)
  class(output)='profoundmulti'
  invisible(output)
}
