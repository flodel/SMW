predict_from_random_forest <- function(Y_M = 1,top.n = 50,YType="RET") {
    library(SDMTools)
    library(randomForest)
    source("SMWutilities.r")
    init_environment()
    
    rf.lst <- list()
    installs.n <- length(sipbInstallDates)
    
    out <-
        matrix(
            NA,nrow = installs.n - Y_M - 13,ncol = 9,dimnames = list(
                sipbInstallDates[1:(installs.n -
                                        Y_M - 13)],c(
                                            "EWLong","RWLong","CWLong","EWMkt","CWMkt","Corr","EWShort","RWShort","CWShort"
                                        )
            )
        )
    
    for (i in 1:11) {
        #load 11 random forests
        load(paste(
            rdata.folder,"rf",Y_M,"M",YType,sipbInstallDates[i],".rdata",sep = ""
        ))
        rf.lst[[i+1]] <- rf1
    }
    
    for (j in 1:(installs.n - 13 - Y_M)) {
        print(j)
        for (i in 1:12) {
            #load 12 random forests
            if (i < 12) {
                rf.lst[[i]] <- rf.lst[[i + 1]]
            } else {
                load(
                    paste(
                        rdata.folder,"rf",Y_M,"M",YType,sipbInstallDates[j + i - 1],".rdata",sep = ""
                    )
                )
                rf.lst[[12]] <- rf1
            }
        }
        load(paste(
            rdata.folder,"xdata",sipbInstallDates[j + 12 - 1 + Y_M + 1],".rdata",sep =
                ""
        ))
        load(paste(
            rdata.folder,"ydata",sipbInstallDates[j + 12 - 1 + Y_M + 1],".rdata",sep =
                ""
        ))
        
        x.df <- xdata
        y.df <- ydata[,c("COMPANY_ID","INSTALLDT",yvar(Y_M))]
        y.df <- y.df[complete.cases(y.df),]
        y.df$COMPANY_ID <- NULL
        y.df$INSTALLDT <- NULL
        
        x.df$COMPANY_ID <- NULL
        x.df$INSTALLDT <- NULL
        x.df$COMPANY <- NULL
        x.df$TICKER <- NULL
        x.df <- x.df[complete.cases(x.df),]
        xy.df <- merge(x.df,y.df,by = "row.names")
        y.df <-
            data.frame(YRet = xy.df[,yvar(Y_M)],row.names = row.names(xy.df))
        x.df <- xy.df
        x.df[,yvar(Y_M)] <- NULL
        x.df$Row.names <- NULL
        
        # get rid of Inf values - this should be in the CreateData script
        idx.inf <- apply(x.df[,6:ncol(x.df)],2,max)==Inf
        for (i in 1:length(idx.inf)){
            if (idx.inf[i]){
                x.df[,i+5]<-ReplInfWithMax(x.df[,i+5])
            }
        }
        
        y.pred <- rep(0,nrow(y.df))
        for (i in 1:12) { # average prediction of last 12 forests
            y.pred <- y.pred + predict(rf.lst[[i]],x.df,type = "response") / 12
        }
        
        sort.idx <- order(y.pred,decreasing = TRUE)[1:top.n]
        yy <- data.frame(pred = y.pred,act = y.df)[sort.idx,]
        out[j,"EWLong"] <- mean(yy[,"YRet"])
        out[j,"RWLong"] <- wt.mean(yy[,"YRet"],1 / x.df$PRCHG_SD3Y[sort.idx])
        out[j,"CWLong"] <-  wt.mean(yy[,"YRet"],x.df$MKTCAP[sort.idx])
        x.mkt.wtd.mean<-apply(x.df[,6:ncol(x.df)],2,wt.mean,wt=x.df$MKTCAP)
        x.mkt.wtd.sd<-apply(x.df[,6:ncol(x.df)],2,wt.sd,wt=x.df$MKTCAP)
        x.mkt.mean<-apply(x.df[,6:ncol(x.df)],2,mean)
        x.mkt.sd<-apply(x.df[,6:ncol(x.df)],2,sd)
        
        x.long.wtd.mean<-apply(x.df[sort.idx,6:ncol(x.df)],2,wt.mean,wt=x.df$MKTCAP[sort.idx])
        x.long.mean<-apply(x.df[sort.idx,6:ncol(x.df)],2,mean)
        
        sort.idx <- order(y.pred,decreasing = FALSE)[1:top.n]
        yy <- data.frame(pred = y.pred,act = y.df)[sort.idx,]
        out[j,"EWShort"] <- mean(yy[,"YRet"])
        out[j,"RWShort"] <- wt.mean(yy[,"YRet"],1 / x.df$PRCHG_SD3Y[sort.idx])
        out[j,"CWShort"] <- sum(wts.cap * yy[,"YRet"])
        x.short.wtd.mean<-apply(x.df[sort.idx,6:ncol(x.df)],2,wt.mean,wt=x.df$MKTCAP[sort.idx])
        x.short.mean<-apply(x.df[sort.idx,6:ncol(x.df)],2,mean)
        
        out[j,"EWMkt"] <- mean(y.df$YRet)
        out[j,"CWMkt"] <- wt.mean(xy.df[,yvar(Y_M)],xy.df$MKTCAP)
        out[j,"Corr"] <- cor(y.pred,y.df$YRet)
    }
    out <- data.frame(out)
    out$CW_LvM <- out$CWLong - out$CWMkt
    out$RWLvCM <- out$RWLong - out$CWMkt
    out$EW_LvM <- out$EWLong - out$EWMkt
    out$CW_LvS <- out$CWLong - out$CWShort
    out$RW_LvS <- out$RWLong - out$RWShort
    out$EW_LvS <- out$EWLong - out$EWShort
    x.stats<-list(x.mkt.wtd.mean=x.mkt.wtd.mean,x.mkt.wtd.sd=x.mkt.wtd.sd,x.mkt.mean=x.mkt.mean,
                  x.mkt.sd=x.mkt.sd,x.long.wtd.mean=x.long.wtd.mean,x.long.mean=x.long.mean,
                  x.short.wtd.mean=x.short.wtd.mean,x.short.mean=x.short.mean)
    Predict<-list(top.n=top.n,sipbInstallDates=sipbInstallDates,Results=out[complete.cases(out),],YType=YType,x.stats)
    save(Predict,
         file = paste0(rdata.folder,"Results",Y_M,"M",top.n,YType,"_",format(Sys.Date(),'%Y%m%d'),".rdata"))
    return(out)
}
