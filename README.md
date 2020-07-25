# Prototype Loads

This project uses OpenStudio's Prototype Buildings to generate the loads of various building types, vintages, and 
locations that can be exported to CSV or to Modelica through a .mos file.

The structure of this repository is as follows. Note that several of the files are located in multiple places (e.g.,
measures, weather files), so make sure to update the correct files.

* measures - The main measures for the analysis. Update these measures and then have PAT 'check for updates'
* pat-project - The PAT project that contains the setup to run the full factorial of Prototype buildings.
* seeds - These models get replaced but a seed model is required for PAT.
* weather - These weather files get replaced by the OpenStudio Prototype measure; however, PAT requires a starting weather file.
* loads - This is the location of the post processed loads that can be imported into Modelica.
* post-process.py - Script that post processes the results of the PAT simulations and places them in the loads folder. 

** These data have not been validated! Use caution and please inform us if there is something amiss **

## Instructions

The list below are the steps to run the OpenStudio simulations and post process the results. The analysis requires running 
a local (or remote) instance of the OpenStudio Analysis Framework (aka OpenStudio Server). 

* Start an instance of OpenStudio Analysis Framework see [section below](#starting-openstudio-analysis-framework).
* Open the `pat-project` in OpenStudio's Parametric Analysis Tool (PAT). The initial data was created with PAT Version 3.0.1.
* Run the simulations in PAT. Note that PAT can be closed after the simulations start but make sure to save on exit to update the pat.json with the server URL.
* Run `python post-process.py` this will:
    * Download the data_point.zip for each of the completed simulation
    * Extract the zip file
    * Parse the results.json and update the modelica.mos with the building type, climate zone, and vintage
    * Save the post processed modelica.mos file into the loads folder.

### Updating Measures

Updating measures requires the user to update the PAT measures. Note that the OpenStudio DOE Prototype Building and
the OpenStudio Results are downloaded from the BCL and do not have a version in the /measures folder.
 
* Update the /measure measure of interest (e.g., export_modelica_loads)
* Launch PAT
* Open this repos PAT project (pat-project)
* Set the measure working directory in `Window -> Set MyMeasures Directory` to this repos /measures path. (Make sure that you do not assign the PAT projects measures directory.)
* Click on the "Check for Updates" in PATs measure list 

## Starting OpenStudio Analysis Framework

* Install [Docker CE](https://docs.docker.com/install/)
* Clone [OpenStudio Server](https://github.com/nrel/openstudio-server). This repo was created with the develop branch which was on Version 3.0.1.

```bash
git clone https://github.com/NREL/OpenStudio-server.git
```

* Build the docker containers

```bash
cd <root-of-openstudio-server-checkout>
docker-compose build
```

* Launch the containers (include number of workers if planning on scaling)

```bash
docker-compose up
```

```bash
OS_SERVER_NUMBER_OF_WORKERS=n docker-compose up
```

* Scale the number of workers (from n above, if desired)

```bash
docker-compose scale worker=n
```

## Technical Implementation



# References

* [Brian L. Ball, Nicholas Long, Katherine Fleming, Chris Balbach & Phylroy Lopez (2020) An open source analysis framework for large-scale building energy modeling, Journal of Building Performance Simulation, 13:5, 487-500, DOI: 10.1080/19401493.2020.1778788](https://www.tandfonline.com/doi/full/10.1080/19401493.2020.1778788)

 