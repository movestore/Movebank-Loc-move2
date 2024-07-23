# Movebank (move2)

MoveApps

Github repository: github.com/movestore/Movebank-Loc-move2

## Description
Download movement tracks that are stored in a study on Movebank. From within the study, it is possible to select specific animals and sensor types, define a time range, and include outliers. You may also downsample your data to a selected temporal resolution and core attributes only. Records with the same track ID and timestamp can cause errors, for example by requiring an animal to be in two places at the same time, and therefore are not allowed. If present in the data set, the duplicated timestamp entry with least columns containing NAs is retained. (Tip: Add multiple Movebank Apps to the beginning of your workflow to download movement tracks from more than one Movebank study.) 

## Documentation (need to update for move2!)
This App allows the direct download of animal movement data that are stored on [Movebank](www.movebank.org) for which you have access [permissions](https://www.movebank.org/cms/movebank-content/permissions-and-sharing). Those data can be the start of workflows that then filter, visualise and/or analyse them. You will view and select the data through an interactive interface.  

**Step 1. Movebank Login.** Provide your Movebank account credentials, or select an account for which you have already provided credentials. Account information will be saved within MoveApps, however these credentials are *not* passed on when you share MoveApps workflows. Select "Next".

**Step 2. Studies.** Here you will see a list of summary information for studies in Movebank. By default, the list is filtered to studies for which the account selected in Step 1 has download access. You may also filter the list to only those studies for which you are a Collaborator or Data Manager. For each study, the number of animals, the number of locations (events), and the date of the first and most recent location are provided. Choose a study and select "Next". 

In some cases, you will be asked to read and agree to a license agreement set by the data owner before proceeding.

If you uncheck "I have download access", you may discover studies of interest for which you do not have access permissions. In this case, you can [contact the owner](https://www.movebank.org/cms/movebank-content/access-data#request_to_use_data_in_movebank) to describe your proposed use and make a data-sharing request.

If you receive a message "No data are available for download", this may be because you do not have access, because there are no data in the study, or because the data in the study have not been associated with animals. If you are a Data Manager for the study, you can [add data](https://www.movebank.org/cms/movebank-content/add-data) or [deployments](https://www.movebank.org/cms/movebank-content/upload-qc#add_deployments) for the study in Movebank. Contact support@movebank.org for assistance.  

**Step 3. Animals.** Here you will see a list of summary information for animals in the study. By default the no animals are selected. Animals can be selected and deselected from the list. For help evaluating available data, the animal name and nickname, species, ring ID, number of locations (events), number of deployments, and the date of the first and most recent location are provided for each animal. Confirm your choices and select "Next". At least one animal has to be selected.

**Step 4. Options.** Here you have additional options to choose which data for the selected study and animal/s will be accessed. 
* *Start and End Date (optional)*: Define a start and/or end timestamp if you want to restrict access to a specific time range.
* *Download locations from the last X days (optional)*: "X" is the number of days before NOW that should be downloaded. This option only makes sense for data with life feed into Movebank. If this option is chosen, “start date” and “end date” will be ignored.
* *Sensor Selection (at least 1 sensor must be selected)*: If multiple location sensor types are present in the study, you can select which to include. (*Tip:* Different accuracy or sampling rates between sensor types can affect appropriate settings for subsequent Apps. You can create separate workflows or workflow instances to run sensor-specific analysis.) Note: It is "possible" to deselect all sensors, but that will lead to empty output of the App and show an error in your workflow. Always select at least 1 sensor!
* *Include Outliers (optional)*: You can select to include records flagged as outliers in Movebank. We strongly recommend that you leave this unchecked. Only select this when you are familiar with the data, for example, if you want to ignore filtering steps taken in Movebank to apply your own filtering methods in subsequent steps of your workflow. We recommend flagging outliers in Movebank ([see instructions](https://www.movebank.org/cms/movebank-content/deployments-and-outliers#mark_outliers)), where options are available to review data and flag records manually or using filters.
* *Data Resolution (required)*: By default, data will be accessed in full resolution, meaning that all data records meeting your other selection criteria will be accessed. Alternatively, you can select to restrict data access to a specified number of locations per second, minute, hour, day, or week (retaining the first record/s per interval).
* *Attribute that will define and identify the tracks (required)*: the user can choose by which attribute the tracks should be defined. The options are (a) Animal ID (individual local identified), (b) Deployment ID (either user defined or number generated by movebank) or (c) combination of animal id and deployment id (separated by an underscore).
* *Argument Minimisation (optional)*: To reduce dataset size, you can choose to restrict data access to a minimum number of core data attributes: animal ID, timestamp, latitude, longitude, species, sensor type, and visible ([visible](http://vocab.nerc.ac.uk/collection/MVB/current/MVB000209/)=false indicates outliers). Consider whether you will need additional information from the dataset for subsequent steps of your analysis.
* *Fast data reduction profiles (optional)*: Movebank provides fast, reduced data download options that you can select to use here. By default they are deselected. It is possible to select (a) download of the full track in resolution of 1 location per day or (b) download of the complete tracks of the last 30 days. Note that selected Start and End Dates will be overwritten by this option.

**Step 5. Overview.** Here you are provided with a summary of all selections from steps 1-4. Review your selections. To make changes, select "Back", or select "Finish" to confirm and proceed. This summary is also helpful to remind you of your selections later: select the "i" button of this App and then "Settings" to see this overview or make changes at any time.

:warning: For large datasets, data transfer might take a long time. Use the options above to reduce the size of the request to only the necessary data. After running the App, you can "Pin" your workflow to this App so that it will not need to repeate the download when rerunning subsequent Apps in the workflow.

:warning: Note that Movebank Apps can be repeatedly added to Workflows and data are appended to each other. This way, it is possible to jointly analyse data from different user accounts and/or studies.


### Input data
none or 
move2_loc

### Output data
move2_loc

### Artefacts
none

### Settings 
none

### Most common errors
Please always check the overview in step 5.

Beware that changes of Animal names in your Movebank study will lead to errors in scheduled runs that include data download from Movebank. For solving this issue, go back to the Movebank App settings and reselect the correct Animals.

### Null or error handling
**Data:** If one or more Animals are selected but without data meeting the other selection criteria, then they are omitted from the return dataset with a warning only. However, if all selected Animals have no data to download then NULL is returned, leading to an error.

:warning: If the dataset contains records with timestamps that are in the future, a warning is given. Records with this obviously wrong timestamp are retained, and may cause errors or unexpected results in later steps of your workflow. These can be flagged as outliers in Movebank by a Data Manager for the study ([see instructions](https://www.movebank.org/cms/movebank-content/deployments-and-outliers#mark_outliers)) or filtered in subsequent steps of your workflow, e.g., with the [Remove Outliers App](https://github.com/movestore/RemoveOutliers). Such timestamps can represent erroneous values provided by the tag or be caused by incorrectly defining the field format when data were imported to Movebank (a Data Manager for the study can review and reimport data if needed following [these instructions](https://www.movebank.org/cms/movebank-content/upload-qc#fix_incorrectly_mapped_values)).

