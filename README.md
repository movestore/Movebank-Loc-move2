# Movebank (move2)

MoveApps

Github repository: github.com/movestore/Movebank-Loc-move2

## Description
Download movement tracks that are stored in a study on Movebank. From within the study, it is possible to select specific animals and sensor types, define a time range, and include outliers. You may also downsample your data to a selected temporal resolution and core attributes only. The downloaded data are ordered by track and time, and locations without coordinates (empty points or missing latitude/longitude) are removed. Duplicated records, i.e. entries with the same track ID and timestamp will cause errors, as an animal cannot be at the same time in two places, and therefore are not allowed. If present in the data set, the duplicated timestamp entry with least columns containing NAs is retained. Attributes containing only NAs, ie empty will be removed from the data set. (Tip: Add multiple Movebank Apps to the beginning of your workflow to download movement tracks from more than one Movebank study.)

## Documentation
This App allows the direct download of animal movement data that are stored on [Movebank](www.movebank.org) for which you have access [permissions](https://www.movebank.org/cms/movebank-content/permissions-and-sharing). Those data can be the start of workflows that then filter, visualise and/or analyse them. You will view and select the data through an interactive interface (See settings).  

:warning: For large datasets, data transfer might take a long time. Use the options above to reduce the size of the request to only download the necessary data. After running the App, you can "Pin" your workflow to this App so that it will not need to repeat the download when rerunning subsequent Apps in the workflow.

:warning: Note that Movebank Apps can be repeatedly added to Workflows and data are appended to each other. This way, it is possible to jointly analyse data from different user accounts and/or studies. All Movebank Apps in a workflow must use the same option for the *Attribute that will define and identify the tracks*; otherwise the data cannot be combined and the App stops with an error.

:warning: This App is set up in a way to repeatedly retry data download (for up to 30 min) in case Movebank is down. This is helpful to avoid failing scheduled workflow runs.

### Application scope
#### Generality of App usability
This App was developed for any taxonomic group.

#### Required data properties
The App works for any Movebank study that contains location data of at least one location sensor type (e.g. GPS, Argos, radio transmitter) for which the Movebank account used has download permission. Data without deployments (i.e. not associated with an animal) cannot be downloaded.

### Input type
none (as the first App of a workflow) or `move2::move2_loc` (output of a previous Movebank App, to which the downloaded data are appended)

### Output type
`move2::move2_loc`

### Artefacts
`citation_metadata.csv`: table with one row per attribute containing, where available in the study, the study ID, study name, taxon IDs, principal investigator, contact person, citation, license terms, license type, and the date of download.

### Settings 

For this App we created a special interactive interface that will walk you though the following steps:     

**Step 1. Movebank Login.** Provide your Movebank account credentials, or select an account for which you have already provided credentials. Account information will be saved within MoveApps, however these credentials are *not* passed on when you share MoveApps workflows. Click "Next".

**Step 2. Studies.** Here you will see a list of summary information for studies in Movebank. By default, the list is filtered to studies for which the account selected in Step 1 has download access. You may also filter the list to only those studies for which you are a Collaborator or Data Manager, or only open access studies. Also, only studies that contain location data are selected by default. For each study, the number of animals, the number of locations (events), sensor types, license, and the date of the first and most recent location are provided. Choose a study and click "Next". 

In some cases, you will be asked to read and agree to a license agreement set by the data owner before proceeding. The license terms you have accepted are recorded in the artifact `citation_metadata.csv` that you can download after the App has run. 

If you uncheck "I have download access", you may discover studies of interest for which you do not have access permissions. In this case, you can [contact the owner](https://www.movebank.org/cms/movebank-content/access-data#request_to_use_data_in_movebank) to describe your proposed use and make a data-sharing request.

If you receive a message "No data are available for download", this may be because you do not have access, because there are no data in the study, or because the data in the study have not been associated with animals. If you are a Data Manager for the study, you can [add data](https://www.movebank.org/cms/movebank-content/add-data) or [deployments](https://www.movebank.org/cms/movebank-content/upload-qc#add_deployments) for the study in Movebank. Contact support@movebank.org for assistance.  

**Step 3. Animals.** Here you will see a list of summary information for animals in the study. By default no animals are selected. Animals can be selected and deselected from the list. Click on the "-" above to select all animals. You can sort the animals or seach for them in the seach field. For help evaluating available data, the animal name and nickname, species, ring ID, number of locations (events), number of deployments, sensor types, and the date of the first and most recent location are provided for each animal. Confirm your choices and click "Next". At least one animal has to be selected.

**Step 4. Options.** Here you have additional options to choose which data for the selected study and animal/s will be accessed. 
* *Start and End Date (optional)*: Define a start and/or end timestamp if you want to restrict access to a specific time range. If the start date lies after the last deployed location of the study, or the end date before the first one, the App logs an error stating the study's date and returns no data.
* *Sensor Selection (at least 1 sensor must be selected)*: If multiple location sensor types are present in the study, you can select which to include. (*Tip:* Different accuracy or sampling rates between sensor types can affect appropriate settings for subsequent Apps. You can create separate workflows or workflow instances to run sensor-specific analysis.) 
* *Data Resolution (optional)*: By default, data will be downloaded in full resolution, meaning that all data records meeting your other selection criteria will be downloaded. Alternatively, you can select to thin the data to one location per specified interval (e.g. one per 6 hours), retaining the first record of each interval. Intervals are aligned to the clock (e.g. 00:00, 06:00, 12:00, 18:00), so the first location of each track usually falls into an incomplete interval and is therefore removed; a track consisting of a single location is kept as is. The data are downloaded in full resolution, and thinned afterwards to the users selection. Note that no additional locations are interpolated at possible gaps. 
* *Attribute that will define and identify the tracks (required)*: The user can choose by which attribute the tracks should be defined. The options are (a) Animal ID (individual local identified), (b) Deployment ID (either user defined or number generated by movebank) or (c) the combination of animal ID and deployment ID (separated by an underscore).
* *Argument Minimisation (optional)*: To reduce dataset size, you can choose to restrict the downloaded event attributes to a minimum set: animal ID, tag ID, deployment ID, sensor type, timestamp, latitude and longitude (plus [visible](http://vocab.nerc.ac.uk/collection/MVB/current/MVB000209/) when outliers are excluded). Track-level attributes such as species, sex or deployment details are always downloaded in full, regardless of this option. Consider whether you will need additional event information (e.g. altitude, speed, temperature) for subsequent steps of your analysis.
* *Include Outliers (optional)*: You can select to include records flagged as outliers in Movebank. We strongly recommend that you leave this unchecked. Only select it when you are familiar with the data, for example, if you want to ignore filtering steps taken in Movebank to apply your own filtering methods in subsequent steps of your workflow. We recommend flagging outliers in Movebank ([see instructions](https://www.movebank.org/cms/movebank-content/deployments-and-outliers#mark_outliers)), where options are available to review data and flag records manually or using filters.
* *Download most recent data (optional)*: Option to select download of data of a certain number of days before NOW. This option only makes sense for data with life feed into Movebank. If this option is chosen, “start date” and “end date” will be ignored.
* *Fast data reduction profiles (optional)*: Movebank provides fast, reduced data download options that you can select to use here. By default they are deselected. It is possible to select (a) download of the full track in resolution of 1 location per day or (b) download of the complete tracks of the last 30 days (last 30 days of the track, independently of when they ended). Note that selected Start and End Dates, as well as "Download most recent data", will be ignored when a profile is selected. Click "Next"

**Step 5. Overview.** Here you are provided with a summary of all selections from steps 1-4. Review your selections. To make changes, click "Back", or select "Finish" to confirm and proceed. This summary is also helpful to remind you of your selections later: select the "i" button of this App and then "Settings" to see this overview or make changes at any time.

### Changes in output data
No changes

### Errors and null handling
Please always check the overview in step 5.

**Input data:** none required. If input data are provided, they must use the same *Attribute that will define and identify the tracks* as this App; otherwise the App logs *"The downloaded data cannot be combined with the input data: the track ID column differs"* and returns NULL. Select the same option in all Movebank Apps of the workflow.

**Animals and time range:** Selected Animals without data meeting the other selection criteria (sensor type, time range, outlier setting) are simply absent from the returned data set; no warning is given for them. If none of the selected Animals has data to download, the App logs an error message stating that no data are available for the selected animals, sensors and time range, and returns NULL, which stops the workflow. The same happens if the selected time range lies completely outside the study's deployment period (*"Your start timestamp is set after the last deployed location of the study"* / *"Your end timestamp is set before the first deployment location of the study"*). Check the first/last location dates shown in steps 2 and 3 and adjust the Start/End Date or the "Download most recent data" setting.

**Movebank unavailable:** If Movebank cannot be reached, the App retries for up to 30 minutes and then returns NULL with an error message in the log. Requests that cannot succeed by waiting (no data for the selection, too many animals for one request) fail immediately with a message.

**Renamed or new animals:** Beware that changes of Animal names in your Movebank study will lead to errors in scheduled runs that include data download from Movebank. For solving this issue, go back to the Movebank App settings and reselect the correct Animals. If you selected all Animals of the study, all will be automatically selected, when names change or new individuals are added to the study.

:warning: This App does not check for records with timestamps that are in the future. Such obviously wrong timestamps are retained, and may cause errors or unexpected results in later steps of your workflow. They can be flagged as outliers in Movebank by a Data Manager for the study ([see instructions](https://www.movebank.org/cms/movebank-content/deployments-and-outliers#mark_outliers)) or filtered in subsequent steps of your workflow, e.g., with the [Remove Outliers App](https://github.com/movestore/RemoveOutliers). Such timestamps can represent erroneous values provided by the tag or be caused by incorrectly defining the field format when data were imported to Movebank (a Data Manager for the study can review and reimport data if needed following [these instructions](https://www.movebank.org/cms/movebank-content/upload-qc#fix_incorrectly_mapped_values)).

### Technical details
* The download uses `move2::movebank_download_study()`; the study information for the time-range check comes from `move2::movebank_download_study_info()`, the available sensor types from `move2::movebank_retrieve(entity_type = "tag_type")`. Credentials are stored for the session with `move2::movebank_store_credentials()` (keyring backend `env`).
* Every Movebank request is wrapped in a retry loop (`retry_with_backoff()` in `RFunction.R`): retries every minute for the first 10 minutes, then every 5 minutes, up to 30 minutes in total. Errors that indicate a data or request problem rather than downtime (no data found, no deployed data, request URL too long) are not retried.
* Thinning uses `move2::mt_filter_per_interval(criterion = "first")`; duplicate removal `move2::mt_filter_unique(criterion = "first")` after ordering the duplicates by their number of missing values; combining with input data `move2::mt_stack(.track_combine = "rename")`.
* Timestamps are handled in UTC. The time-range check compares the selected dates with the first/last deployed location of the whole study, not of the selected animals.
* All processing is done on the whole downloaded data set at once; runtime is dominated by the Movebank transfer and increases with the number of locations requested.
