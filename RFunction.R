library('move2')
library('keyring')
library('lubridate')

## The parameter "data" is reserved for the data object passed on from the previous app

# to display messages to the user in the log file of the App in MoveApps
# one can use the function from the logger.R file:
# logger.fatal(), logger.error(), logger.warn(), logger.info(), logger.debug(), logger.trace()

rFunction = function(data=NULL, username,password,study,animals=NULL,select_sensors,incl_outliers=FALSE,minarg=FALSE,handle_duplicates=TRUE,timestamp_start=NULL,timestamp_end=NULL,event_reduc=NULL,thin=FALSE,thin_numb=6,thin_unit="hours", ...) {
  
  options("keyring_backend"="env")
  movebank_store_credentials(username,password)
  
  arguments <- list()
  
  arguments[["study_id"]] <- study
  
  #sensor types
  if (is.null(select_sensors))
  {
    logger.info("The selected study does not contain any location sensor data. No data will be downloaded (NULL output) by this App.")
    result <- NULL
  } else if (length(select_sensors)==0)
  {
    logger.info("Either the selected study does not contain any location sensor data or you have deselected all available location sensors. No data will be downloaded (NULL output) by this App.")
    result <- NULL
  } else #download only if sensor given
  {
    arguments[["sensor_type_id"]] <- select_sensors
    
    sensorInfo <- movebank_retrieve(entity_type="tag_type")
    select_sensors_name <- sensorInfo$name[which(as.numeric(sensorInfo$id) %in% select_sensors)]
    logger.info(paste("You have selected to download locations of these selected sensor types:",paste(select_sensors_name,collapse=", ")))
    
    #include outliers
    if (incl_outliers==TRUE) 
    {
      logger.info ("You have selected to download also locations marked as outliers in Movebank (visible=FALSE). Note that this may lead to unexpected results.")
    } else 
    {
      arguments[["remove_movebank_outliers"]] <- TRUE
      logger.info ("Only data that were not marked as outliers previously are downloaded (default).")
    }
    
    #todo: try out with study that has not tag_loc_id or id_loc_id
    if (minarg==TRUE) 
    {
      arguments[["attributes"]] <- c("tag_local_identifier","individual_local_identifier","deployment_id")
      logger.info("You have selected to only include the minimum set of event attributes: timestamp, track_id and the location. The track attributes will be fully included.")
    }
  
    if (exists("timestamp_start") && !is.null(timestamp_start)) {
      logger.info(paste0("timestamp_start is set and will be used: ", timestamp_start))
      arguments["timestamp_start"] = timestamp_start
      #arguments["timestamp_start"] = paste(substring(as.character(timestamp_start),c(1,6,9,12,15,18,21),c(4,7,10,13,16,19,23)),collapse="")
      #arguments["timestamp_start"] = as.POSIXct(as.character(timestamp_start),format="%Y-%m-%dT%H:%M:%OSZ")
    } else {
      logger.info("timestamp_start not set.")
    }
    
    if (exists("timestamp_end") && !is.null(timestamp_end)) {
      logger.info(paste0("timestamp_end is set and will be used: ", timestamp_end))
      arguments["timestamp_end"] = timestamp_end
      #arguments["timestamp_end"] = paste(substring(as.character(timestamp_end),c(1,6,9,12,15,18,21),c(4,7,10,13,16,19,23)),collapse="")
      #arguments["timestamp_end"] = as.POSIXct(as.character(timestamp_end),format="%Y-%m-%dT%H:%M:%OSZ")
    } else {
      logger.info("timestamp_end not set.")
    }
    
    #event reduction profiles EURING: 1-quick daily location, 3-all location of the last 30 days
    #todo: test what happens if timestamp_start and timestamp_end are set,
    # note: this setting does not seem to work at all (with or without timestamp_start/end), please ask Bart
    #if (!is.null(event_reduc))
    #{
    #  arguments[["event_reduction_profile"]] <- event_reduc #can have values "EURING_01" or "EURING_03"
    #}
  
    #todo: select animals - muessen wir mit Clemens aendern! --> animals==0 nicht erlaubt, dann nur else-Teil nötig
    if (length(animals)==0)
    {
      anims <- movebank_download_deployment(study)$individual_local_identifier #is that always available??
      logger.info(paste("no animals set, using full study with the following all animals:",paste(as.character(anims),collapse=", ")))
    } else
    {
      logger.info(paste("selected to download",length(animals), "animals:", paste(as.character(animals),collapse=", ")))
      if (length(animals)==1) arguments[["individual_local_identifier"]] <- as.character(animals)
      if (length(animals)>1) arguments[["individual_local_identifiers"]] <- as.character(animals)
    }

    #download
    locs <- do.call(movebank_download_study,arguments)
  
    # add fix for deployment_id -> code from Bart
    #locs$individual_tags
    # mt_set_track_id ...
    # if minarg need deployment_id (possibly delete afterwards)
    
    # quality check: cleaved, time ordered, non-emtpy, non-duplicated. update by mt_filter_unique 
    # Q: any other functions to cleave/order? --> Anne asking Bart
    
    # select only non-duplicated locs in two steps, no user interaction
    # 1. select row with most info, test with stork data (fall download_modus in daten drin ist)
    # 2. raussuchen: specific download_modus
    # 3. first
    #mt_filter_per_interval()

    #thinning
    if (thin==TRUE) 
    {
      logger.info(paste("Your data will be thinned as requested to one location per",thin_numb,thin_unit))
      locs <- locs[!duplicated(paste(mt_track_id(locs),round_date(mt_time(locs), paste0(thin_numb," ",thin_unit)))),]
    }
    
    
    # combine with other input data (move2!)
    if (!is.null(data)) result <- mt_stack(data,locs,.track_combine="rename") else result <- locs
    # mt_stack(...,track_combine="rename") #check if only renamed at duplication; read about and test track_id_repair
  }
  # provide my result to the next app in the MoveApps workflow
  return(result)
}
