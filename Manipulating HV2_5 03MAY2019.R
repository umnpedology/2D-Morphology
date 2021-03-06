##packages - probably more than needed, but just in case
library(raster)
library(sp)
library(rgdal)
library(sf)
library(dplyr)
library(ggplot2)
library(rasterVis)
library(aqp)
library(RColorBrewer)
library(latticeExtra)
library(reshape2)
library(riskyr)

##we are going to create a digital version of the following profile and scaled profile drawing (this is one of Dr. Chien-Lu Ping's (UAF emeritus) drawings from the Happy Valley hillslope from the Argonne C stocks project) - the profile is HV 2.5

##Read in the shapefile. this shapefile was created from the original scaled profile drawing through two steps: 1. created linework in Illustrator, exported as .dxf. Imported into ArcGIS (I'm sure there is a much more efficient workflow in QGIS that can be set up, but just to get this done in the short term I used Arc). 2. exported as shapefile. Note that because of all of that rigamaroll I have to adjust the origin and extent eventually. And...now that I think of it, we can probably just read the .dxf into R directly without exporting to a shapefile.

##Read in shapefile
s1 <- readOGR(".","AAAHV2_5Complete")

##get info
summary(s1)

##quick plot to make sure everything looks good
spplot(s1,z="hz_name")

##shifting to get the origin to zero - this can be cut out with a more efficient "pre" workflow
spshift=shift(s1,-96.9194,485.2414)


extent(spshift)

##generate raster (this will be a 1 x 1 cm grid). the pit drawing is 150cm wide (x) by 100cm deep (y)
r <- raster(xmn=0,xmx=150,ymn=0,ymx=100,ncol=150, nrow=100)
extent(r) <- extent(spshift)

##rasterize the shapefile
rps1 <- rasterize(spshift, r, 'hz_name',fun='first')
###extent(r) <- extent(s1)
##bb <- extent(0,150,0,100)
##extent(r) <- bb
###rp <- rasterize(s1, r, 'hz_name')

##plot it
plot(rps1)

###plot(rp)

###rps=shift(rp,-96.9194,485.2414)

## check that origin is 0,0. it isn't so need to readjust below
origin(rps1)

## set origin (bottom left corner) to 0,0
ori=c(0,0)
origin(rps1)=ori

## now check that origin is at 0,0. It is
origin(rps1)
##plot(rps1)

## check resolution (we want 1 x 1). It isnt.
res(rps1)
rps1

## set extent to 150 in x and 100 in y
ext=extent(matrix(c(0,0,150,100), nrow=2))

## i copied this just so I didn't screw anything up with the original. this can be eliminated on cleanup
rps2=rps1
extent(rps2)=ext

## check extent and resolution - all looks good!
rps2

## plot just for fun
plot(rps2)

## generate RAT
rps2 <- ratify(rps2)
rat <- levels(rps2)[[1]]
###rat$Pixel_Values <- c(1, 2, 3, 4, 5, 6, 7, 8, 9)
###rat$hz_name <- c("Ajj", "Bg", "Bg/Ajj", "Oa", "Oajjf", "Oe","Oi","Wf", "Wf/Cgf")
###rat$ID_char=as.character(rat$ID)

## assign hz_names and data to levels
rps2_levels_hz = structure(list(level = 1:9, hz_name = c("Ajj", "Bg", "Bg/Ajj", "Oa", "Oajjf", "Oe","Oi","Wf", "Wf/Cgf"), bd = c(0.727, 1.102, 1.484, 0.30, 0.167, 0.113,0.096,0, 0.234), SOC = c(14.4, 4.29, 5.0, 32.1, 29.6, 44.1, 48.9, 0, 3.3), icev =c(NA,NA,NA,NA,70.8,NA,NA,100,88.2)), class = "data.frame", .Names = c("level","hz_name","bd", "SOC","icev"), row.names = c(NA, -9L))

## join data to levels
rat <- rat %>% left_join(rps2_levels_hz, by = c("ID" = "level"))

###rps2_levels_bd = structure(list(level = 1:9, descr = c(0.727, 1.102, 1.484, 0.30, 0.167, 0.113,0.096,0, 0.234)), class = "data.frame", .Names = c("level","bd"), row.names = c(NA,-9L))

###rps2_levels_bd

## check that rat looks good, assign to raster levels
rat

###rat2 <- rat %>% left_join(rps2_levels_bd, by = c("ID" = "level"))

###rat2

levels(rps2) = rat

## check that data is in there. looks good
rps2

## plot by horizon name just for fun
levelplot(rps2,att='hz_name')

##DATA MANIPULATION - DEPTH PLOTS OF SOC, BD, ICE
#SOC 
##Deratify to extract SOC values only, convert to matrix, check structure
q=deratify(rps2,'SOC')
q_soc = as.matrix(q)
str(q_soc)

## compute mean SOC for every row (mean of all cell across 150cm width). Note there are some issues here. namely, we are taking the top of the raster (not the soil surface) in each case. I think we really need to start at the soil surface in the future.
soc_all_mean <- apply(q_soc, 1, mean, na.rm=T)
str(soc_all_mean)

## compute sd for every row
soc_all_sd <- apply(q_soc, 1, sd, na.rm=T)
str(soc_all_sd)

##soc_all_mean

## create vector of depths
depths=c(1:100)

##comput high and low bounds (low = mean - 1sd, high = mean + 1sd)
soc_low=soc_all_mean-soc_all_sd
soc_high=soc_all_mean+soc_all_sd

soc_complete=cbind(soc_all_mean,depths,soc_all_sd,soc_low,soc_high)
str(soc_complete)

## plot mean and sd with depth here just to make sure we're on track
plot(soc_complete[,2],soc_complete[,1])
plot(soc_complete[,2],soc_complete[,3])

## convert to data frame so we can plot in lattice
soc_complete.dat=as.data.frame(soc_complete)
str(soc_complete.dat)

## just assigning dummy variables and groups here
soc_complete.dat$variable = "SOC"
soc_complete.dat$group = "HV2-5"
str(soc_complete.dat)

## make lattice plot for SOC
p.1 = xyplot(
  depths ~ soc_all_mean | variable, data=soc_complete.dat,groups = group,lower=soc_low, upper=soc_high, sync.colors=F, alpha=0.5,
  ylim=c(100,-5), layout=c(1,1), ylab='Depth (cm)', scales=list(x=list(relation='free')), strip=strip.custom(bg='grey80'),
  par.settings=list(superpose.line=list(lwd=2,col=c('black'))),
  panel=panel.depth_function,
  prepanel=prepanel.depth_function,
  auto.key=list(columns=1,lines=TRUE, points=FALSE)
)


#BD
##Deratify to extract BD values only, convert to matrix, check structure
q=deratify(rps2,'bd')
q_bd = as.matrix(q)
str(q_bd)

## compute mean bd for every row (mean of all cell across 150cm width). Note there are some issues here. namely, we are taking the top of the raster (not the soil surface) in each case. I think we really need to start at the soil surface in the future.
bd_all_mean <- apply(q_bd, 1, mean, na.rm=T)
str(bd_all_mean)

## compute sd for every row
bd_all_sd <- apply(q_bd, 1, sd, na.rm=T)
str(bd_all_sd)

## create vector of depths
depths=c(1:100)

##comput high and low bounds (low = mean - 1sd, high = mean + 1sd)
bd_low=bd_all_mean-bd_all_sd
bd_high=bd_all_mean+bd_all_sd

bd_complete=cbind(bd_all_mean,depths,bd_all_sd,bd_low,bd_high)
str(bd_complete)

## convert to data frame so we can plot in lattice
bd_complete.dat=as.data.frame(bd_complete)
str(bd_complete.dat)

## just assigning dummy variables and groups here
bd_complete.dat$variable = "bd"
bd_complete.dat$group = "HV2-5"
str(bd_complete.dat)

## make lattice plot for bd
p.2 = xyplot(
  depths ~ bd_all_mean | variable, data=bd_complete.dat,groups = group,lower=bd_low, upper=bd_high, sync.colors=F, alpha=0.5,
  ylim=c(100,-5), layout=c(1,1), ylab='Depth (cm)', scales=list(x=list(relation='free')), strip=strip.custom(bg='grey80'),
  par.settings=list(superpose.line=list(lwd=2,col=c('black'))),
  panel=panel.depth_function,
  prepanel=prepanel.depth_function,
  auto.key=list(columns=1,lines=TRUE, points=FALSE)
)

#ICE VOLUME
##Deratify to extract icev values only, convert to matrix, check structure
q=deratify(rps2,'icev')
q_icev = as.matrix(q)
str(q_icev)

## compute mean icev for every row (mean of all cell across 150cm width). Note there are some issues here. namely, we are taking the top of the raster (not the soil surface) in each case. I think we really need to start at the soil surface in the future.
icev_all_mean <- apply(q_icev, 1, mean, na.rm=T)
str(icev_all_mean)

## compute sd for every row
icev_all_sd <- apply(q_icev, 1, sd, na.rm=T)
str(icev_all_sd)

## create vector of depths
depths=c(1:100)

##comput high and low bounds (low = mean - 1sd, high = mean + 1sd)
icev_low=icev_all_mean-icev_all_sd
icev_high=icev_all_mean+icev_all_sd

icev_complete=cbind(icev_all_mean,depths,icev_all_sd,icev_low,icev_high)
str(icev_complete)

## convert to data frame so we can plot in lattice
icev_complete.dat=as.data.frame(icev_complete)
str(icev_complete.dat)

## just assigning dummy variables and groups here
icev_complete.dat$variable = "icev"
icev_complete.dat$group = "HV2-5"
str(icev_complete.dat)

## make lattice plot for icev
p.3 = xyplot(
  depths ~ icev_all_mean | variable, data=icev_complete.dat,groups = group,lower=icev_low, upper=icev_high, sync.colors=F, alpha=0.5,
  ylim=c(100,-5), layout=c(1,1), ylab='Depth (cm)', scales=list(x=list(relation='free')), strip=strip.custom(bg='grey80'),
  par.settings=list(superpose.line=list(lwd=2,col=c('black'))),
  panel=panel.depth_function,
  prepanel=prepanel.depth_function,
  auto.key=list(columns=1,lines=TRUE, points=FALSE)
)

##COMBINED LATTICE PLOT
c(p.1,p.2,p.3,layout=c(3,1))

## NOW MESSING AROUND WITH C STOCKS
##str(bd_complete.dat)
##str(soc_complete.dat)

## make a new dataframe that contains both soc and bd in order to calculate stocks
stock_complete.dat=soc_complete.dat
stock_complete.dat$bd=bd_complete.dat$bd_all_mean
##str(stock_complete.dat)

## compute slicewise SOC stock in kg SOC / m2
stock_complete.dat$stock=stock_complete.dat$soc_all_mean*stock_complete.dat$bd/10

stock_complete.dat$stocksd=stock_complete.dat$soc_all_sd*stock_complete.dat$bd/10

stock_complete.dat$stock_low=stock_complete.dat$stock-stock_complete.dat$stocksd

stock_complete.dat$stock_high=stock_complete.dat$stock+stock_complete.dat$stocksd

##str(stock_complete.dat)

sum(stock_complete.dat$stock)

## this plots average 1cm stocks (kg/m2) with depth 
p.4 = xyplot(
  depths ~ stock | variable, data=stock_complete.dat,groups = group,sync.colors=F, alpha=0.5,
  ylim=c(100,-5), layout=c(1,1), ylab='Depth (cm)', scales=list(x=list(relation='free')), strip=strip.custom(bg='grey80'),
  par.settings=list(superpose.line=list(lwd=2,col=c('black'))),
  panel=panel.depth_function,
  prepanel=prepanel.depth_function,
  auto.key=list(columns=1,lines=TRUE, points=FALSE)
)

p.4

###PER DYLAN"S PREVIOUS WORK
# convert cell values to matrix
m <- as.matrix(rps2)

# Pr(Hz | depth) via cell counts
# note: equal depths are expanded as columns
p <- apply(m, 1, function(i) {
  i <- factor(i, levels=rat$ID, labels=rat$hz_name)
  tab <- table(i)
  res <- tab / sum(tab)
  return(res)
})

# translate columns -> rows, mirrors depth logic
p <- t(p)

# viz of Pr(Hz | depth)
# about right
#plot of horizon probabilities
matplot(p, type = 'l', lty=1, las=1, lwd=2)

# Shannon Entropy as an index of horizon confusion vs. depth
xyplot(1:100 ~ apply(p, 1, shannonEntropy), type=c('l', 'g'), lwd=2, col='RoyalBlue', asp=1.5, ylim=c(110, -10), ylab='Depth (cm)', xlab='Shannon Entropy')

# convert to data.drame, add depths
p <- as.data.frame(p)
p$top <- 0:(nrow(p)-1)
p$bottom <- p$top + 1

# reshape to long format for plotting
p.long <- melt(p, id.vars=c('top', 'bottom'))

# interesting but hard to read
(plot.2 <- xyplot(top ~ value, data=p.long, groups=variable, ylim=c(110, -10), type='l', par.settings=list(superpose.line=list(lwd=2)), asp=1, auto.key=list(columns=3, lines=TRUE, points=FALSE, cex=0.7), ylab='Depth (cm)', xlab='Pr(Hz | depth)'))

###CALCULATING SLICES OF THE RASTER TO MIMIC SIPRE CORES, CALCULATE STOCKS FOR EACH 10cm SLICE (15 "SLICES" because pit is 150cm wide)

###str(q_soc)
###str(q_bd)

## convert to dataframe
q_soc.dat=as.data.frame(q_soc)
##str(q_soc.dat)

## calculate SOC means for every 10 rows (i.e. a 10cm "slice" through the profile"). this results in 15 columns b/c pit is 150cm wide
soc_agg=t(sapply(seq(1,ncol(q_soc.dat), by=10), function(i) {
  indx <- i:(i+9)
  rowMeans(q_soc.dat[indx[indx <= ncol(q_soc.dat)]],na.rm=T)}))

## calculate BD means for every 10 rows (i.e. a 10cm "slice" through the profile"). this results in 15 columns b/c pit is 150cm wide
q_bd.dat=as.data.frame(q_bd)
bd_agg=t(sapply(seq(1,ncol(q_bd.dat), by=10), function(i) {
  indx <- i:(i+9)
  rowMeans(q_bd.dat[indx[indx <= ncol(q_bd.dat)]],na.rm=T)}))

## calculate 1cm stocks in kg/m2
stock_agg=soc_agg*bd_agg/10
##stock_agg

# calculate total carbon stock for each 10cm vertical "slice" through the profile. there are 15 of them since the pit is 150cm wide
stocks=rowSums(stock_agg,na.rm=T)
##stocks

# display a histogram of the SOC stocks (n=15) for the vertical slices
hist(stocks)

## transpose
stock_agg_t=t(stock_agg)
## convert to dataframe
stock_agg_t.dat=as.data.frame(stock_agg_t)
## compute rowMeans for the average SOC stock for each 1cm increment going down. this is a new column called $ave
stock_agg_t.dat$ave=rowMeans(stock_agg_t.dat,na.rm=T)
str(stock_agg_t.dat)

## add depths in cm 
depths=c(1:100)
stock_agg_t.dat$depth=depths
##str(stock_agg_t.dat)

## plot 1cm SOC stocks (for average of 15 10cm vertical slices across pit) in kg/m2
plot(stock_agg_t.dat$depth,stock_agg_t.dat$ave)

## replace NAs with zeros for cumSums
stock_agg_t.dat[is.na(stock_agg_t.dat)] <- 0
##stock_agg_t.dat

## comput cumsums by column (columns are 10cm wide vertical "slices" through the profile. There are 15 of them.)
mySum = apply(stock_agg_t.dat, 2, cumsum)
str(mySum)

## convert to dataframe
mySum.dat=as.data.frame(mySum)
## add depths
mySum.dat$depth=stock_agg_t.dat$depth
str(mySum.dat)

## plot average cumulative carbon stock with depth for the 15 10cm wide vertical slices
plot(mySum.dat$depth,mySum.dat$ave,type="l",lwd=3,ylim=c(0,55))

## now plot cumulative carbon stocks for each individual slice to showcase variability across pit
for(i in 1:15){
  points(mySum.dat$depth,mySum.dat[,i],type="l",lwd=1,col="grey60",add=T)
}

## just for looks, add grid and overplot average again 
grid(nx = 10, ny = 12, col = "grey90", lty = "dotted",
     lwd = par("lwd"), equilogs = TRUE)
points(mySum.dat$depth,mySum.dat$ave,type="l",lwd=3)


###NOTES
#1. I'm using the terminology "slice" to refer to a verticl cross-section through a pit of defined width (in this case 10cm). We need to change this terminology because "slice" in AQP is in the horizontal dimension, so there is high potential for confusion.

#2. I haven't yet resolved the fact that I'm calculating everything from the top of the raster and not the soil surface. We need to ignore the NAs at the top of some of the slices and start the depth at the soil surface. This means that some of the slices will have a depth less than 100cm but that's just fine. Actually, one perhaps simple and elegant solution would be to take the NAs from the top of the raster and put them on the bottom of the columns that have them. This could be done to the original raster. It would warp the profile in space but would sure make the subsequent data dealings MUCH easier.