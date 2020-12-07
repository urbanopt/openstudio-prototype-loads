import zipfile
import os
import glob
import json

from openstudio_server import OpenStudioServerAPI

def mos_exists(path):
    mos = glob.glob(f'{path}/datapoint/*/modelica.mos')
    if mos and len(mos) == 1:
        return mos[0]
        # just return the mos
    elif mos and len(mos) > 1:
        raise Exception(f"There are more than one mos file in {path}")
    else:
        # no mos file found
        return None

def process_mos(id, mospath):
    print(f'[{id}] Processing MOS: {mospath}')

    # read in the results.json to parse the building characteristics
    r_json_name = os.path.join(os.path.dirname(mospath), '../results.json')
    new_mospath = os.path.join(os.path.dirname(mospath), '../../../../../loads/')
    if not os.path.exists(new_mospath):
        os.makedirs(new_mospath)
    if os.path.exists(r_json_name):
        r_json = json.loads(open(r_json_name, 'rt').read())
        building_type = r_json['create_doe_prototype_building']['building_type']
        climate_zone = r_json['create_doe_prototype_building']['climate_zone'].split('-')[2]
        vintage = r_json['create_doe_prototype_building']['template'].replace(' ', '_')
        with open(mospath, 'rt') as f:
            data = f.read()
            data = data.replace("{{BUILDINGTYPE}}", building_type)
            data = data.replace("{{CLIMATEZONE}}", climate_zone)
            data = data.replace("{{VINTAGE}}", vintage)
            data = data.replace("{{SIMID}}", id)

            new_file = os.path.join(new_mospath, f'{building_type}-{vintage}-{climate_zone}.mos')
            with open(new_file, 'wt') as f2:
                f2.write(data)
    else:
        raise Exception(f'Could not find results.json in dir: {os.path.dirname(mospath)}')

    return None


def process_directory(id, path):
    if mos_exists(path):
        process_mos(id, mos_exists(path))
    else:
        raise Exception(f"Could not find a valid MOS file in {path}")


# main block
# get the analysis id out of the pat.json (make sure that you "saved" the pat project after you started simulations)
pat_json = json.loads(open(os.path.join('pat-project', 'pat.json'), 'rt').read())
analysis_id = pat_json['analysisID']
remote_url = pat_json['remoteSettings']['remoteServerURL']

print(f"Remove server is {remote_url}")
protocol, host, port = remote_url.split(':')
host = f"{protocol}:{host}"
port.replace('/', '')
oss = OpenStudioServerAPI(host, port)

if not oss.alive():
    raise Exception("The OpenStudio Server host is not up, please start to download datapoints")

# use the pat_json to look at all the datapoints
sims = oss.get_analysis_results(analysis_id)
for sim in sims['data']:
    if sim['status'] == 'completed' and sim['status_message'] == 'completed normal':
        print(f"[{sim['_id']}] Simulation complete with name {sim['name']}")

        # check if the data_point has been downloaded
        zipfilename = os.path.join('pat-project', 'localResults', sim['_id'], 'data_point.zip')
        if os.path.exists(zipfilename):
            print(f"[{sim['_id']}] Datapoint already downloaded")
        else:
            print(f"[{sim['_id']}] Downloading data_point.zip into {os.path.dirname(zipfilename)}")
            # verify that the dir exists, PAT truncates after 160 datapoints, so need to manually add
            if not os.path.exists(os.path.dirname(zipfilename)):
                os.makedirs(os.path.dirname(zipfilename))
            oss.download_datapoint_report(sim['_id'], 'data_point.zip', f'./{os.path.dirname(zipfilename)}')
            if not os.path.exists(zipfilename):
                raise Exception(f"{sim['_id']} Could not find download data_point zipfile, download may have failed")

        # check if the zip has been extracted by looking for the datapoint directory
        unzip_path = os.path.join(os.path.dirname(zipfilename), 'datapoint')
        if not os.path.exists(unzip_path):
            try:
                with zipfile.ZipFile(zipfilename, 'r') as zip_ref:
                    zip_ref.extractall(unzip_path)
            except zipfile.BadZipFile:
                raise Exception(f"Could not process ZipFile: {unzip_path}")

        # now process the directory to cleanup the mos file
        process_directory(sim['_id'], os.path.dirname(zipfilename))
