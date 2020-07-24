import zipfile
import os
import glob
import json


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

def process_mos(mospath):
    print(f'Processing MOS: {mospath}')

    # read in the results.json to parse the building characteristics
    r_json_name = os.path.join(os.path.dirname(mospath), '../results.json')
    new_mospath = os.path.join(os.path.dirname(mospath), '../../../../../loads/')
    if not os.path.exists(new_mospath):
        os.makedirs(new_mospath)
    if os.path.exists(r_json_name):
        print('loading json')
        r_json = json.loads(open(r_json_name, 'rt').read())
        building_type = r_json['create_doe_prototype_building']['building_type']
        climate_zone = r_json['create_doe_prototype_building']['climate_zone'].split('-')[2]
        vintage = r_json['create_doe_prototype_building']['template']
        with open(mospath, 'rt') as f:
            data = f.read()
            data = data.replace("{{BUILDINGTYPE}}", building_type)
            data = data.replace("{{CLIMATEZONE}}", climate_zone)
            data = data.replace("{{VINTAGE}}", vintage)

            new_file = os.path.join(new_mospath, f'{building_type}-{vintage}-{climate_zone}.mos')
            with open(new_file, 'wt') as f2:
                f2.write(data)



    else:
        raise Exception(f'Could not find results.json in dir: {os.path.dirname(mospath)}')


#         print(data)
#
#     fin = open("data.txt", "rt")
#     #read file contents to string
#     data = fin.read()
#     #replace all occurrences of the required string
#     data = data.replace('pyton', 'python')
#     #close the input file
#     fin.close()
#     #open the input file in write mode
#     fin = open("data.txt", "wt")
#     #overrite the input file with the resulting data
#     fin.write(data)
    return None


def process_directory(path):
    if mos_exists(path):
        process_mos(mos_exists(path))
    else:
        # find if there is a data_point.zip
        zipfilename = os.path.join(path, 'data_point.zip')
        if os.path.exists(zipfilename):
            print(f"found zip: {zipfilename}")
            with zipfile.ZipFile(zipfilename, 'r') as zip_ref:
                # create path to zip to
                zip_to_path = os.path.join(os.path.dirname(zipfilename), 'datapoint')
                zip_ref.extractall(zip_to_path)
        else:
            print(f"No ZIP: {zipfilename}")

    # now process the MOS file -- check that it exists again
    if mos_exists(path):
        process_mos(mos_exists(path))


# main block
sims = glob.glob('./pat-project/localResults/*/eplustbl.html')
for sim in sims:
    process_directory(os.path.dirname(sim))

