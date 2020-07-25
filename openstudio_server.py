# Class for accessing and downloading data from OpenStudio Server

import requests
import re

class OpenStudioServerAPI(object):
    def __init__(self, host, port):
        self.host = host
        self.port = port

    def alive(self):
        """Check if the OpenStudio server is alive and active"""
        r = self.machine_status()
        if r['status']['awake'] is not None:
            return True
        else:
            return False

    @property
    def host_url(self):
        return f"{self.host}:{self.port}"

    def machine_status(self):
        """Retrieve the stats"""
        r = requests.get(f"{self.host_url}status.json")
        return r.json()

    def get_analysis_status(self, analysis_id, analysis_type):
        """Get the status of the analysis to determine if the data need to be downloaded"""
        status = False
        r = requests.get(f"{self.host_url}analyses/{analysis_id}/status.json")
        if r.status_code == 200:
            if r.json()['analysis']['analysis_type'] == analysis_type:
                status = r.json()['analysis']['status']

        return status

    def get_analysis_results(self, analysis_id):
        """Return the high level analysis results"""
        analysis = None
        r = requests.get(f"{self.host_url}analyses/{analysis_id}/analysis_data.json")
        if r.status_code == 200:
            analysis = r.json()

        return analysis

    def get_datapoint(self, datapoint_id):
        """Return the detailed results of a datapoint"""
        datapoint = None
        r = requests.get(f"{self.host_url}data_points/{datapoint_id}.json")
        if r.status_code == 200:
            datapoint = r.json()

        return datapoint

    def download_datapoint_report(self, datapoint_id, report_name, save_directory = '.'):
        """Download a datapoint report that was generated upon completion of the simulations"""
        downloaded = False
        file_path_and_name = None
        payload = {"filename": report_name}

        # filename is the report file_path_and_name
        local_filename = f"{save_directory}/data_point.zip"
        url = f"{self.host_url}data_points/{datapoint_id}/download_result_file"
        with requests.get(url, params=payload, stream=True) as r:
            r.raise_for_status()
            with open(local_filename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        downloaded = True

        return downloaded, local_filename

