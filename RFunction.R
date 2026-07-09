library('move2')
library('keyring')
library('lubridate')
library("dplyr")
library("sf")
library("xml2")
library("purrr")
library("vctrs")
library("rlang")
library("tidyselect")


## ToDo: find correct way of doing this: names(new1) <- make.names(names(new1),allow_=TRUE)


### helper function for while loop to pull data from movebank

retry_with_backoff <- function(expr,
                               check_var = NULL,       # optional: name (string) of variable whose existence signals success
                               timeout = 1800,          # total time to keep trying (seconds)
                               label = "Movebank",      # human-readable name for log messages, e.g. "Movebank"
                               initial_wait = 2,        # seconds before backoff kicks in at all
                               short_backoff = 600,     # seconds after which backoff switches to long interval
                               short_sleep = 60,        # sleep interval during short backoff phase
                               long_sleep = 300,        # sleep interval during long backoff phase
                               envir = parent.frame()) {
  
  expr <- substitute(expr)
  time0 <- Sys.time()
  elapsed <- 0
  succeeded <- FALSE
  last_error <- NULL
  
  is_success <- function() {
    if (!is.null(check_var)) exists(check_var, envir = envir, inherits = FALSE) else succeeded
  }
  
  while (elapsed < timeout & !is_success()) {
    
    # backoff schedule based on elapsed time
    if (elapsed > initial_wait & elapsed <= short_backoff) Sys.sleep(short_sleep)
    if (elapsed > short_backoff) Sys.sleep(long_sleep)
    
    logger.info(paste0("Try ", label, " access at: ", Sys.time()))
    
    tryCatch({
      eval(expr, envir = envir)
      succeeded <- TRUE   # only reached if eval() didn't error
    }, error = function(e) {
      last_error <<- conditionMessage(e)
    })
    
    elapsed <- as.numeric(difftime(Sys.time(), time0, units = "secs"))
  }
  
  if (!is_success()) {
    error_msg <- paste0(
      "Tried to access ", label, " for ", timeout / 60, " minutes, no successful response. ",
      label, " seems to be currently down. Try again later. ",
      "Original error: ", if (!is.null(last_error)) last_error else geterrmessage()
    )
    logger.error(error_msg)
    stop(error_msg, call. = FALSE)
  }
  
  if (!is.null(check_var)) return(get(check_var, envir = envir, inherits = FALSE))
  invisible(TRUE)  # side-effect-only call succeeded; nothing meaningful to return
}


rFunction = function(data=NULL, username,password,study,select_sensors,incl_outliers=FALSE,minarg=FALSE,animals=NULL,thin=FALSE,thin_numb=6,thin_unit="hours",timestamp_start=NULL,timestamp_end=NULL, event_reduc=NULL, lastXdays=NULL, trackid="indv", ...) {
  
  options("keyring_backend"="env")
  
  tryCatch(
    retry_with_backoff({
        movebank_store_credentials(username,password)
    }, #label = "Movebank credential storage"
    ),
    error = function(e) {message("Failed to access Movebank: ", conditionMessage(e))}
  )    
  
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
          
          sensorInfo <- tryCatch(
            retry_with_backoff({
          sensorInfo <- movebank_retrieve(entity_type="tag_type")
            }, check_var = "sensorInfo"#, label = "Movebank"
          ),
          error = function(e) {
            message("Failed to to access Movebank: ", conditionMessage(e))
            NULL
          }
          )
          
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
            arguments[["attributes"]] <- c("tag_local_identifier","individual_local_identifier","deployment_id","sensor_type_id")
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
          
          if(!is.null(lastXdays)){
            timestamp_start <- now(tzone="UTC") - days(lastXdays)
            arguments[["timestamp_start"]]  <-  timestamp_start ## why sometimes there are 2 square brackets and sometimes just one?
            arguments["timestamp_end"]  <-  NULL
            logger.info(paste0("data will be downloaded starting from: ", timestamp_start, " this is ",lastXdays, " before now. If timestamp_start or timestamp_end are set, these values will be ignored"))
          }
          
          #event reduction profiles EURING: 1-quick daily location, 3-all location of the last 30 days
          #todo: test what happens if timestamp_start and timestamp_end are set,
          # note: this setting does not seem to work at all (with or without timestamp_start/end), please ask Bart
          # NOTE ANNE: "EURING_01" and "EURING_03" work, but the attributes have to be named, attributes="all" does  not work, nor timestamp start/end. 
          
          if (!is.null(event_reduc) & length(event_reduc)>0)
          {
            logger.info(paste("You have selected to use the event reduction profile",event_reduc,"for fast download from Movebank. EURING_01 indicates download of 1 location per day for the full selected tracks, EURING_03 download of the last 30 days of data for each selected individual track (starting at the last position)."))
            
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
                attr_sdy <- tryCatch(
                  retry_with_backoff({
                attr_sdy <- movebank_retrieve(entity_type = "study_attribute", study_id = study, sensor_type_id = select_sensors)$short_name
                  }, check_var = "attr_sdy"),
                error = function(e) {
                  message("Failed to access Movebank: ", conditionMessage(e))
                  NULL
                }
                )
                
                arguments[["attributes"]] <- attr_sdy
              }
              if(length(select_sensors)>1){
                attr_sdy <- tryCatch(
                  retry_with_backoff({
                attr_sdy <- unique(unlist(lapply(select_sensors, function(x){
                  movebank_retrieve(entity_type = "study_attribute", study_id = study, sensor_type_id = x)$short_name
                })))
                  }, check_var = "attr_sdy"),
                error = function(e) {
                  message("Failed to access Movebank: ", conditionMessage(e))
                  NULL
                }
                )
                arguments[["attributes"]] <- attr_sdy
              }
            }
          } else logger.info("You have selected to NOT use a fast reduction profile download. Start and end timestamps will be used if defined above.")
          
          if (length(animals)==0)
          {
          logger.info("All individuals of this study have been selected to be downloaded")
          } else
          {
            logger.info(paste("selected to download",length(animals), "animals:", paste(as.character(animals),collapse=", ")))
            arguments[["individual_local_identifier"]] <- as.character(animals)
          }
          
          ##check timestamp end and start to be within range of data
         if(!is.null(arguments$timestamp_start) | !is.null(arguments$timestamp_end)){
           stdyi <- tryCatch(
            retry_with_backoff({
          stdyi <- movebank_download_study_info(study_id=study)
            }, check_var = "stdyi"),
          error = function(e) {
            message("Failed to access Movebank: ", conditionMessage(e))
            NULL
          })
               
          if(!is.null(arguments$timestamp_start) & as.POSIXct(arguments$timestamp_start, "%Y%m%d%H%M%OS", tz="UTC") > stdyi$timestamp_last_deployed_location){
              result <- NULL
              logger.error(paste0("Your start timestamp is set after the last deployed location of the study (",stdyi$timestamp_last_deployed_location,"). No data will be downloaded."))
          } else if(!is.null(arguments$timestamp_end) & as.POSIXct(arguments$timestamp_end, "%Y%m%d%H%M%OS", tz="UTC") < stdyi$timestamp_first_deployed_location){
            result <- NULL
              logger.error(paste0("Your end timestamp is set before the first deployment location of the study (",stdyi$timestamp_first_deployed_location,"). No data will be downloaded."))

          }
         }else{
          
          #download
          locs <- tryCatch(
            retry_with_backoff({
          locs <- do.call(movebank_download_study,arguments)
            }, check_var = "locs"),
          error = function(e) {
            message("Failed to access Movebank: ", conditionMessage(e))
            NULL
          }
          )
          # quality check: cleaved, time ordered, non-emtpy, non-duplicated (dupl get removed further down in the code)
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
            emptylocs <- dplyr::filter(locs, sf::st_is_empty(locs))
            logger.info(paste0("Your data included empty points (",nrow(emptylocs),"). We remove them for you."))
            locs <- dplyr::filter(locs, !sf::st_is_empty(locs))
          }
          ## for some reason, sometimes either lat or long are NA, as one still has a value it does not get removed with the excluding empty, here is what I came up with:
          crds <- sf::st_coordinates(locs)
          rem <- unique(c(which(is.na(crds[,1])),which(is.na(crds[,2]))))
          if(length(rem)>0){
            locs <- locs[-rem,]
          }
          
          
          # ## AFTER DISCUSSING WITH SARAH AND OTHERS, WE HAVE DECIDED TO LET THE USER DECIDE WHICH SHOULD BE THEIR TRACK ID, INDIVIDUAL NAME, DEPLOYMENT ID, OR COMBI OF BOTH.
          # # rename track_id column to always combination of individual+tag so it is consistent and informative across studies. Used same naming as in "mt_read()"
          # # suggestion form Bart: maybe better use "animalName (dep_id:358594)" because it could happen that the same indiv gets tagged with the same tag in 2 different years. If using "indv_tag", tracks could get merged together that are actually different deployments
          # # ToDo: decide on column name e.g. "individual_name_deployment_id" and renaming e.g. "indivName (deploy_id:084728)"
          # locs <- locs |> mutate_track_data(individual_name_deployment_id = paste0(mt_track_data(locs)$individual_local_identifier ," (deploy_id:",mt_track_data(locs)$deployment_id,")")) # "deploy_id" or some other abbreviation that makes sense
          # idcolumn <- mt_track_id_column(locs) # need to get track id column before changing it
          # locs <- mt_as_event_attribute(locs,"individual_name_deployment_id")
          # locs <- mt_set_track_id(locs, "individual_name_deployment_id")
          # locs <- mt_as_track_attribute(locs,all_of(idcolumn)) # when changing the track_id column, the previous one stays in the event table, but gets removed from track table (which makes sense), but putting it back as in this case it will always work
          
          # trackid=c("indv","deploy","indv_deploy")
          if(trackid=="indv"){ #  "individual_local_identifier"
            if(mt_track_id_column(locs)=="individual_local_identifier"){locs <- locs}else{
              locs <- mt_set_track_id(locs, "individual_local_identifier")
              # "deployment_id" moves to the event table, probably could somehow get it back to the track table, but not sure its worth the effort
              if(!mt_is_track_id_cleaved(locs)){locs <- locs |> dplyr::arrange(mt_track_id(locs))}
              if(!mt_is_time_ordered(locs)){locs <- locs |> dplyr::arrange(mt_track_id(locs),mt_time(locs))}
            }
          }
          if(trackid=="deploy"){ #deployment_id
            if(mt_track_id_column(locs)=="deployment_id"){locs <- locs}else{
              idcolumn <- mt_track_id_column(locs) # need to get track id column before changing it
              locs <- mt_set_track_id(locs, "deployment_id")
              locs <- mt_as_track_attribute(locs,all_of(idcolumn)) # when changing the track_id column, the previous one stays in the event table, but gets removed from track table (which makes sense), but putting it back as in this case it will always work
              if(!mt_is_track_id_cleaved(locs)){locs <- locs |> dplyr::arrange(mt_track_id(locs))}
              if(!mt_is_time_ordered(locs)){locs <- locs |> dplyr::arrange(mt_track_id(locs),mt_time(locs))}
            }
          }
          if(trackid=="indv_deploy"){
            idcolumn <- mt_track_id_column(locs) # need to get track id column before changing it
            locs <- locs |> mutate_track_data(individual_name_deployment_id = paste0(mt_track_data(locs)$individual_local_identifier ,"_",mt_track_data(locs)$deployment_id))
            locs <- mt_set_track_id(locs, "individual_name_deployment_id")
            locs <- mt_as_track_attribute(locs,all_of(idcolumn)) # when changing the track_id column, the previous one stays in the event table, but gets removed from track table (which makes sense), but putting it back as in this case it will always work
            if(!mt_is_track_id_cleaved(locs)){locs <- locs |> dplyr::arrange(mt_track_id(locs))}
            if(!mt_is_time_ordered(locs)){locs <- locs |> dplyr::arrange(mt_track_id(locs),mt_time(locs))}
          }
          
          # remove duplicates without user interaction, start with select most-info row
          if (!mt_has_unique_location_time_records(locs))
          {
            n_dupl <- length(which(duplicated(paste(mt_track_id(locs),mt_time(locs)))))
            logger.info(paste("Your data has",n_dupl, "duplicated location-time records. We removed here those with less info and then select the first if still duplicated."))
            ## this piece of code keeps the duplicated entry with least number of columns with NA values
            locs <- locs %>%
              mutate(n_na = rowSums(is.na(pick(everything())))) %>%
              arrange(n_na) %>%
              mt_filter_unique(criterion='first') %>% # this always needs to be "first" because the duplicates get ordered according to the number of columns with NA. 
              dplyr::arrange(mt_track_id()) %>%
              dplyr::arrange(mt_track_id(),mt_time())
          }
          
          #thinning to first location of given time windows (thus, resulting time lag can be shorter some times)
          # here was the error that tracks are not grouped
          if (thin==TRUE) 
          {
            logger.info(paste("Your data will be thinned as requested to one location per",thin_numb,thin_unit))
            #order as suggested by error message (done by dplyr before, did not work???)
            locs <- locs[order(mt_track_id(locs),mt_time(locs)),]
            locs <- mt_filter_per_interval(locs,criterion="first",unit=paste(thin_numb,thin_unit))
            locs <- locs %>% group_by(mt_track_id()) %>% slice(if(n()>1) -1 else 1) %>% ungroup ## the thinning happens within the time window, so the 1st location is mostly off. After the 1st location the intervals are regular if the data allow for it. If track endsup only with one location, this one is retained
            locs <-  locs %>% select (-c(`mt_track_id()`)) # this column gets added when using group_by()
          } 
          
          #make names
          # names(locs) <- make.names(names(locs),allow_=TRUE)
          mt_track_id(locs) <- make.names(mt_track_id(locs),allow_=TRUE)
          
          # combine with other input data (move2!)
          if (!is.null(data)){
            if (!st_crs(data)==st_crs(locs)){
              locs <- st_transform(locs, st_crs(data))
              logger.info(paste0("The new data sets to combine has a different projection. It has been re-projected, and now the combined data set is in the '",st_crs(data)$input,"' projection."))
            }
            result <- mt_stack(data,locs,.track_combine="rename") ## mt_stack(...,track_combine="rename") #check if only renamed at duplication; read about and test track_id_repair
            
            ## unlisting track data columns of class list
            if(any(sapply(mt_track_data(result), is_bare_list))){
              ## reduce all columns were entry is the same to one (so no list anymore)
              result <- result |> mutate_track_data(across(
                where( ~is_bare_list(.x) && all(purrr::map_lgl(.x, function(y) 1==length(unique(y)) ))), 
                ~do.call(vctrs::vec_c,purrr::map(.x, head,1))))
              if(any(sapply(mt_track_data(result), is_bare_list))){
                ## transform those that are still a list into a character string
                result <- result |> mutate_track_data(across(
                  where( ~is_bare_list(.x) && any(purrr::map_lgl(.x, function(y) 1!=length(unique(y)) ))), 
                  ~unlist(purrr::map(.x, paste, collapse=","))))
              }
            }
          }else{
            result <- locs
            ## unlisting track data columns of class list
            if(any(sapply(mt_track_data(result), is_bare_list))){
              ## reduce all columns were entry is the same to one (so no list anymore)
              result <- result |> mutate_track_data(across(
                where( ~is_bare_list(.x) && all(purrr::map_lgl(.x, function(y) 1==length(unique(y)) ))), 
                ~do.call(vctrs::vec_c,purrr::map(.x, head,1))))
              if(any(sapply(mt_track_data(result), is_bare_list))){
                ## transform those that are still a list into a character string
                result <- result |> mutate_track_data(across(
                  where( ~is_bare_list(.x) && any(purrr::map_lgl(.x, function(y) 1!=length(unique(y)) ))), 
                  ~unlist(purrr::map(.x, paste, collapse=","))))
              }
            }
          }
          
          ## remove all attributes that contain NAs in all rows
          na_cols <- result %>%
            select(where(~ all(is.na(.)))) %>% 
            select_track_data(where(~ all(is.na(.))))
          naevnt <- names(na_cols)
          natrk <- names(mt_track_data(na_cols))
          naevnt <- naevnt[!naevnt %in% c(mt_track_id_column(result), mt_time_column(result),"geometry")]
          natrk <- natrk[!natrk %in% c(mt_track_id_column(result))]
          
          if(length(naevnt)>=1){
            logger.info(paste0("The event attributes: ",paste0(naevnt, collapse = ", ")," have been removed as they only contained NAs.")) 
          }
          if(length(natrk)>=1){
            logger.info(paste0("The track attributes: ",paste0(natrk, collapse = ", ")," have been removed as they only contained NAs.")) 
          }
          
          result <- result %>%
            select(where(~ !all(is.na(.)))) %>% 
            select_track_data(where(~ !all(is.na(.))))
          
        }
        }
     
  
  if(!is.null(result)){
    ## create file with metadata for download
    attrList <- c("study_id", "name", "taxon_ids", "principal_investigator_name", "contact_person_name", "citation", "license_terms", "license_type")
    metadata <- result %>% mt_track_data() %>% select(any_of(attrList)) %>% distinct(.keep_all = TRUE)
    metadata$download_date <- Sys.Date()
    metadata_csv <- data.frame(names(metadata),t(metadata))
    if(nrow(metadata)>=1){
      write.table(metadata_csv,appArtifactPath("citation_metadata.csv"), row.names = F, col.names=F)
    }
  }
  
  if(is.null(result)){
    logger.error("No data has been downloaded, check your settings and the logs for messages that might indicate where the problem is.")
  } else {
    return(result)
  }
  
}
