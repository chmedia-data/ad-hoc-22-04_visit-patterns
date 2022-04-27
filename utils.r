# options(java.parameters = "-Xmx4g")

library("DBI")
library('ggplot2')
library('chron')
library('stringr')
library('dplyr')
library('reshape2')
library('RColorBrewer')
library('digest')

con = NULL

getDWHCon = function(){

  if(!is.null(con)){
    return(con)
  }

  bigrquery::bq_auth(path="~/.bigquery/trim-mechanism-126723-70f52b319aa4.json")
  con <- dbConnect(
    bigrquery::bigquery(),
    project = "trim-mechanism-126723"
  )

  return(con)
}

sortFactor = function(factorVar,sortVar,decreasing=T){
  if(!any(duplicated(sortVar)) & !any(duplicated(factorVar))){
    lvls = factorVar[order(sortVar,decreasing=decreasing)]
  }else{
    agg = aggregate(var1~var2,data.frame(
      var1=sortVar,
      var2=factorVar
    ),mean)
    lvls = agg$var2[order(agg$var1,decreasing=decreasing)]
  }
  factor(factorVar,levels=lvls,ordered=T)
}

pastelColors= function(var) {
  palette = scale_fill_manual(values = colorRampPalette(brewer.pal(12, "Set3"))(nunique(var)))
  return(palette)
}

getQueryData = function(
  sqlName=NULL,
  sqlString=NULL,
  queryVars=NULL,
  force=F,
  cacheSuffix=''
){
  if(is.null(sqlString)){
    cached = paste0('data/',sqlName,cacheSuffix,'.csv')
  }else{
    sqlDigest = digest(sqlString, algo = "crc32", serialize=F)
    cached = paste0('data/',sqlDigest,cacheSuffix,'.csv')
  }

  # load data
  if( file.exists(cached) & force==F){
    df = read.csv(cached)
  }else{

    con = getDWHCon()

    # load and preprocess query and execute
    if(is.null(sqlString)){
      query=readQuery(sqlName,queryVars)
    }else{
      query = str_interp(sqlString,queryVars)
    }
    df = dbGetQuery(con, query)
    write.csv(df,cached,row.names=F)
  }

  # post process
  names(df) = tolower(names(df))
  for(col in c('title','section','uri','newsroom','tags','variant')){
    if(col %in% names(df)){
      df[,col] = gsub('"','',df[,col])
    }
  }
  for(col in names(df)){
    if( ('time' == col) || grepl('date',col) ){
      df[,col] = as.POSIXct(df[,col])
    }
  }

  return(df)
}


readQuery = function(queryName,queryVars=NULL) {
  s = paste(readLines(paste0('queries/',queryName,'.sql')),collapse='\n')
  s = str_interp(s,queryVars)
}


ggplotly = function(...){
  p = plotly::config(plotly::ggplotly(...),
                     modeBarButtonsToRemove = c('sendDataToCloud','select2d','lasso2d','zoom2d','autoScale2d',
                                                'hoverClosestCartesian','hoverCompareCartesian','toggleSpikelines'),
                     displaylogo = F) %>% plotly::layout(...)
  return(p)
}


to_weekday=function(var){
  day_names = weekdays(as.Date(var+3,origin='1970-01-01'),abbreviate = T)
  levels = weekdays(as.Date(4:10,origin='1970-01-01'),abbreviate = T)
  day_names = factor(day_names,levels=levels,ordered=T)
  return(day_names)
}


to_daytype=function(var){
  day_names = to_weekay(var)
  day_types = ifelse(day_names %in% c('Sat','Sun'),'Weekend','Weekday')
  return(day_types)
}


nunique = function(var){
  return(length(unique(var)))
}


ifnull = function(x,repl){
  return(ifelse(is.na(x) || is.null(x),repl,x))
}


brmCached = function(name,formula,data,chains=4,cores=4,iter=2000,force=F){
  cachedPath = paste0('data/',name,'.rds')
  if(file.exists(cachedPath) & force==F){
    model = readRDS(cachedPath)
  }else{
    model = brm(formula,data,cores=cores,chains=chains,iter=iter)
    saveRDS(model,cachedPath)
  }
  return(model)
}


installDependencies = function(){
  install.packages(c(
    'ggplot2',
    'rJava',
    "bigrquery",
    "DBI",
    'chron',
    'stringr',
    'dplyr',
    'reshape2',
    'RColorBrewer',
    'digest',
    'plotly',
    'knitr',
    'brms',
    'devtools'
  ),repos='https://stat.ethz.ch/CRAN/')
  devtools::install_github("wesm/feather/R")
}

knitr::opts_chunk$set("message"=F)
knitr::opts_chunk$set("warning"=F)
