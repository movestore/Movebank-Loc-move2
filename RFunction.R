library('move2')
library('keyring')
library('lubridate')

# remains to update: 

# 1. the setting duplicates handling shall give only either "first" or "last" (in second mt_filter_unique), now it is not used and set to "last" fix --> activated

# 2. EURING_1 und EURING_3 options shall be added, but as they dont work and the frontend does not allow it for selection, not yet --> probably temporary bug, now it works

# 3. add fix for deployment_id (to be named from indivdual_local_identifier and tag_local_identifier) - there should be some code from Bart --> fixed

# 4. select animals - should be changed with Clemens: animals==0 for all animals also in future added ones (make ticket that this info shall be written somewhere or additinal check-box) --> made ticket

rFunction = function(data=NULL, username,password,study,select_sensors,incl_outliers=FALSE,minarg=FALSE,animals=NULL,thin=FALSE,thin_numb=6,thin_unit="hours",timestamp_start=NULL,timestamp_end=NULL,duplicates_handling="first",event_reduc=NULL, ...) {

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
  } else #download if any sensor given
  {
    arguments[["sensor_type_id"]] <- select_sensors
    
    sensorInfo <- movebank_retrieve(entity_type="tag_type")
    select_sensors_name <- sensorInfo$name[which(as.numeric(sensorInfo$id) %in% select_sensors)]
    logger.info(paste("You have selected to download locations of these selected sensor types:",paste(select_sensors_name,collapse=", ")))
    
    #include outliers
    if (incl_outliers==TRUE) 
    {
      logger.info ("Also locations marked as outliers in Movebank (visible=FALSE) will be downloaded. Note that this may lead to unexpected results.")
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
    # NOTE ANNE: "EURING_01" and "EURING_03" work, but the attributes have to be named, attributes="all" does  not work, nor timestamp start/end. 
    
    if (!is.null(event_reduc))
    {
      arguments[["event_reduction_profile"]] <- event_reduc #can have values "EURING_01" or "EURING_03"
      # ToDo: see if this "ignoring time settings" is needed or can be solved were else
      if(!is.null(timestamp_start)){
        arguments["timestamp_start"] <- NULL
        logger.info(paste0("timestamp_start cannot be used in combination with the setting ",event_reduc))
      }
      if(!is.null(timestamp_end)){
        arguments["timestamp_end"] <- NULL
        logger.info(paste0("timestamp_end cannot be used in combination with the setting ",event_reduc))
      }
      
      # attributes=all does not work, a vector is needed
      if(!minarg){
        if(length(select_sensors)==1){
          arguments[["attributes"]] <- movebank_retrieve(entity_type = "study_attribute", study_id = study, sensor_type_id = select_sensors)$short_name
        }
        if(length(select_sensors)>1){
          arguments[["attributes"]] <- unique(unlist(lapply(select_sensors, function(x){
            movebank_retrieve(entity_type = "study_attribute", study_id = study, sensor_type_id = x)$short_name
          })))
        }
      }  
    }
       
    if (length(animals)==0)
    {
      anims <- movebank_download_deployment(study)$individual_local_identifier #is that always available??
      logger.info(paste("no animals set, using full study with the following all animals:",paste(as.character(anims),collapse=", ")))
      # arguments[["individual_local_identifier"]] <- NULL
    } else
    {
      logger.info(paste("selected to download",length(animals), "animals:", paste(as.character(animals),collapse=", ")))
      arguments[["individual_local_identifier"]] <- as.character(animals)
    }

    #download
    locs <- do.call(movebank_download_study,arguments)
  
    # quality check: cleaved, time ordered, non-emtpy, non-duplicated
    if(!mt_is_track_id_cleaved(locs))
    {
      logger.info("Your data set was not grouped by individual/track. We regroup it for you.")
      locs <- locs |> dplyr::arrange(mt_track_id(locs))
    }
    
    if (!mt_is_time_ordered(locs))
    {
      logger.info("Your data is not time ordered (within the individual/track groups). We reorder the locations for you.")
      locs <- locs |> dplyr::arrange(mt_track_id(locs),mt_time(locs))
    }
    
    if(!mt_has_no_empty_points(locs))
    {
      logger.info("Your data included empty points. We remove them for you.")
      locs <- dplyr::filter(locs, !sf::st_is_empty(locs))
    }

    # rename track_id column to always combination of individual+tag so it is consistent and informative across studies. Used same naming as in "mt_read()"
    # suggestion form Bart: maybe better use "animalName (dep_id:358594)" because it could happen that the same indiv gets tagged with the same tag in 2 different years. If using "indv_tag", tracks could get merged together that are actually different deployments
    # ToDo: decide on column name e.g. "individual_name_deployment_id" and renaming e.g. "indivName (deploy_id:084728)"
    locs <- locs |> mutate_track_data(individual_name_deployment_id = paste0(mt_track_data(locs)$individual_local_identifier ," (deploy_id:",mt_track_data(locs)$deployment_id,")")) # "deploy_id" or some other abbreviation that makes sense
    idcolumn <- mt_track_id_column(locs) # need to get track id column before changing it
    locs <- mt_as_event_attribute(locs,"individual_name_deployment_id") ## bug: this function turns the track data table into a data.frame. Bart is looking into it. But this should not cause any errors downstream.
    locs <- mt_set_track_id(locs, "individual_name_deployment_id")
    locs <- mt_as_track_attribute(locs,idcolumn)
  
    # remove duplicates without user interaction, start with select most-info row, then last (or first)
    if (!mt_has_unique_location_time_records(locs))
    {
      n_dupl <- length(which(duplicated(paste(mt_track_id(locs),mt_time(locs)))))
      logger.info(paste("Your data has",n_dupl, "duplicated location-time records. We removed here those with less info and then select the first if still duplicated."))
      locs <- mt_filter_unique(locs,criterion="subsets")
      locs <- mt_filter_unique(locs,criterion=duplicates_handling)
    }
    
    #thinning to first location of given intervals (thus, resulting time lag can be shorter some times)
    if (thin==TRUE) 
    {
      logger.info(paste("Your data will be thinned as requested to one location per",thin_numb,thin_unit))
      locs <- mt_filter_per_interval(locs,criterion="first",unit=paste(thin_numb,thin_unit))
      #locs <- locs[!duplicated(paste(mt_track_id(locs),round_date(mt_time(locs), paste0(thin_numb," ",thin_unit)))),]
    }
    
    # combine with other input data (move2!)
    if (!is.null(data)) result <- mt_stack(data,locs,.track_combine="rename") else result <- locs
    # mt_stack(...,track_combine="rename") #check if only renamed at duplication; read about and test track_id_repair
  }
  return(result)
}
