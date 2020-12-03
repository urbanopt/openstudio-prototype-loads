# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require 'erb'

# start the measure
class ExportModelicaLoads < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Export Modelica Loads'
  end

  def description
    return 'Use the results from the EnergyPlus simulation to generate a load file for use in Modelica. This will create a MOS and a CSV file of the heating, cooling, and hot water loads.'
  end

  def modeler_description
    return ''
  end

  def log(str)
    puts "#{Time.now}: #{str}"
  end

  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # this measure does not require any user arguments, return an empty list
    return args
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # To use the built-in error checking we need the model...
    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    result << OpenStudio::IdfObject.load('Output:Variable,,Site Mains Water Temperature,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Variable,,Site Outdoor Air Drybulb Temperature,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Variable,,Site Outdoor Air Relative Humidity,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Meter,Cooling:Electricity,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Meter,Heating:Electricity,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Meter,Heating:Gas,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Meter,InteriorLights:Electricity,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Meter,Fans:Electricity,hourly;').get
    result << OpenStudio::IdfObject.load('Output:Meter,InteriorEquipment:Electricity,hourly;').get # Joules
    result << OpenStudio::IdfObject.load('Output:Meter,ExteriorLighting:Electricity,hourly;').get # Joules
    result << OpenStudio::IdfObject.load('Output:Meter,Electricity:Facility,hourly;').get # Joules
    result << OpenStudio::IdfObject.load('Output:Meter,Gas:Facility,hourly;').get # Joules
    result << OpenStudio::IdfObject.load('Output:Meter,Heating:EnergyTransfer,hourly;').get  # Joules
    result << OpenStudio::IdfObject.load('Output:Meter,WaterSystems:EnergyTransfer,hourly;').get  # Joules
    # these variables are used for the modelica export.
    result << OpenStudio::IdfObject.load('Output:Variable,*,Zone Predicted Sensible Load to Setpoint Heat Transfer Rate,hourly;').get  # watts according to e+
    result << OpenStudio::IdfObject.load('Output:Variable,*,Water Heater Total Demand Heat Transfer Rate,hourly;').get # Watts

    return result
  end

  def extract_timeseries_into_matrix(sqlfile, data, variable_name, key_value = nil, default_if_empty=0)
    log "Executing query for #{variable_name}"
    column_name = variable_name
    if key_value
      ts = sqlfile.timeSeries('RUN PERIOD 1', 'Hourly', variable_name, key_value)
      # ts = sqlfile.timeSeries('RUN PERIOD 1', 'Zone Timestep', variable_name, key_value)
      column_name += "_#{key_value}"
    else
      ts = sqlfile.timeSeries('RUN PERIOD 1', 'Hourly', variable_name)
      # ts = sqlfile.timeSeries('RUN PERIOD 1', 'Zone Timestep', variable_name)
    end
    log 'Iterating over timeseries'
    column = [column_name.delete(':').delete(' ')] # Set the header of the data to the variable name, removing : and spaces

    if ts.empty?
      log "No time series for #{variable_name}:#{key_value}... defaulting to #{default_if_empty}"
      # needs to be data.size-1 since the column name is already stored above (+=)
      column += [default_if_empty] * (data.size-1)
    else
      ts = ts.get if ts.respond_to?(:get)
      ts = ts.first if ts.respond_to?(:first)

      start = Time.now
      # Iterating in OpenStudio can take up to 60 seconds with 10min data. The quick_proc takes 0.03 seconds.
      # for i in 0..ts.values.size - 1
      #   log "... at #{i}" if i % 10000 == 0
      #   column << ts.values[i]
      # end

      quick_proc = ts.values.to_s.split(',')

      # the first and last have some cleanup items because of the Vector method
      quick_proc[0] = quick_proc[0].gsub(/^.*\(/, '')
      quick_proc[-1] = quick_proc[-1].delete(')')
      column += quick_proc

      log "Took #{Time.now - start} to iterate"
    end

    log 'Appending column to data'

    # append the data to the end of the rows
    if column.size == data.size
      data.each_index do |index|
        data[index] << column[index]
      end
    end

    log "Finished extracting #{variable_name}"
  end

  def create_new_variable_sum(data, new_var_name, include_str, options=nil)
    var_info = {
        name: new_var_name,
        var_indexes: []
    }
    data.each_with_index do |row, index|
      if index.zero?
        # Get the index of the columns to add
        row.each do |c|
          if c.include? include_str
            var_info[:var_indexes] << row.index(c)
          end
        end

        # add the new var to the header row
        data[0] << var_info[:name]
      else
        # sum the values
        sum = 0
        var_info[:var_indexes].each do |var|
          temp_v = row[var].to_f
          if options.nil?
            sum += temp_v
          elsif options[:positive_only] && temp_v > 0
            sum += temp_v
          elsif options[:negative_only] && temp_v < 0
            sum += temp_v
          end
        end

        # Also round the data here, because we don't need 10 decimals
        data[index] << sum.round(1)
      end
    end
  end

  def run(runner, user_arguments)
    super(runner, user_arguments)

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # use the built-in error checking
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    # create a new csv with the values and save to the reports directory.
    # assumptions:
    #   - all the variables exist
    #   - data are the same length

    # initialize the rows with the header
    log 'Starting to process Timeseries data'
    # Initial header row
    rows = [
      ['Date Time', 'Month', 'Day', 'Day of Week', 'Hour', 'Minute', 'SecondsFromStart']
    ]

    # just grab one of the variables to get the date/time stamps
    # ts = sqlFile.timeSeries('RUN PERIOD 1', 'Zone Timestep', 'Cooling:Electricity')
    ts = sqlFile.timeSeries('RUN PERIOD 1', 'Hourly', 'Cooling:Electricity')
    unless ts.empty?
      ts = ts.first
      dt_base = nil
      # Save off the date time values
      ts.dateTimes.each_with_index do |dt, index|
        runner.registerInfo("My index is #{index}")
        dt_base = DateTime.parse(dt.to_s) if dt_base.nil?
        dt_current = DateTime.parse(dt.to_s)
        rows << [
          DateTime.parse(dt.to_s).strftime('%m/%d/%Y %H:%M'),
            dt.date.monthOfYear.value,
            dt.date.dayOfMonth,
            dt.date.dayOfWeek.value,
            dt.time.hours,
            dt.time.minutes,
            dt_current.to_time.to_i - dt_base.to_time.to_i
        ]
      end
    end

    # add in the other variables by columns -- should really pull this from the report variables defined above
    extract_timeseries_into_matrix(sqlFile, rows, 'Site Outdoor Air Drybulb Temperature', 'Environment', 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Site Outdoor Air Relative Humidity', 'Environment', 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Heating:Electricity', nil, 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Heating:Gas', nil, 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Cooling:Electricity', nil, 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Electricity:Facility', nil, 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Gas:Facility', nil, 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'Heating:EnergyTransfer', nil, 0)
    extract_timeseries_into_matrix(sqlFile, rows, 'WaterSystems:EnergyTransfer', nil, 0)

    # get all zones and save the names for later use in aggregation.
    tz_names = []
    model.getThermalZones.each do |tz|
      tz_names << tz.name.get if tz.name.is_initialized
      extract_timeseries_into_matrix(sqlFile, rows, 'Zone Predicted Sensible Load to Setpoint Heat Transfer Rate', tz_names.last, 0)
      extract_timeseries_into_matrix(sqlFile, rows, 'Water Heater Heating Rate', tz_names.last, 0)
    end

    # sum up a couple of the columns and create a new columns
    create_new_variable_sum(rows, 'TotalSensibleLoad', 'ZonePredictedSensibleLoadtoSetpointHeatTransferRate')
    create_new_variable_sum(rows, 'TotalCoolingSensibleLoad', 'ZonePredictedSensibleLoadtoSetpointHeatTransferRate', negative_only: true)
    create_new_variable_sum(rows, 'TotalHeatingSensibleLoad', 'ZonePredictedSensibleLoadtoSetpointHeatTransferRate', positive_only: true)
    create_new_variable_sum(rows, 'TotalWaterHeating', 'WaterHeaterHeatingRate')

    # convert this to CSV object
    File.open('./building_loads.csv', 'w') do |f|
      rows.each do |row|
        f << row.join(',') << "\n"
      end
    end

    # covert the row data into the format needed by modelica
    modelica_data = [['seconds', 'cooling', 'heating', 'waterheating']]
    seconds_index = nil
    total_water_heating_index = nil
    total_cooling_sensible_index = nil
    total_heating_sensible_index = nil
    peak_cooling = 0
    peak_heating = 0
    peak_water_heating = 0
    rows.each_with_index do |row, index|
      if index.zero?
        seconds_index = row.index('SecondsFromStart')
        total_cooling_sensible_index = row.index('TotalCoolingSensibleLoad')
        total_heating_sensible_index = row.index('TotalHeatingSensibleLoad')
        total_water_heating_index = row.index('TotalWaterHeating')
      else
        new_data = [
          row[seconds_index],
          row[total_cooling_sensible_index],
          row[total_heating_sensible_index],
          row[total_water_heating_index]
        ]

        modelica_data << new_data

        # store the peaks
        peak_cooling = row[total_cooling_sensible_index] if row[total_cooling_sensible_index] < peak_cooling
        peak_heating = row[total_heating_sensible_index] if row[total_heating_sensible_index] > peak_heating
        peak_water_heating = row[total_water_heating_index] if row[total_water_heating_index] > peak_water_heating
      end
    end

    File.open('./modelica.mos', 'w') do |f|
      f << "#1\n"
      f << "#Heating and Cooling Model loads from OpenStudio Prototype Buildings\n"
      f << "#  Building Type: {{BUILDINGTYPE}}\n"
      f << "#  Climate Zone: {{CLIMATEZONE}}\n"
      f << "#  Vintage: {{VINTAGE}}\n"
      f << "#  Simulation ID (for debugging): {{SIMID}}\n"
      f << "#  URL: https://github.com/urbanopt/openstudio-prototype-loads\n"
      f << "\n"
      f << "#First column: Seconds in the year (loads are hourly)\n"
      f << "#Second column: cooling loads in Watts (as negative numbers).\n"
      f << "#Third column: space heating loads in Watts\n"
      f << "#Fourth column: water heating in Watts\n"
      f << "\n"
      f << "#Peak space cooling load = #{peak_cooling} Watts\n"
      f << "#Peak space heating load = #{peak_heating} Watts\n"
      f << "#Peak water heating load = #{peak_water_heating} Watts\n"
      f << "double tab1(8760,4)\n"
      modelica_data.each_with_index do |row, index|
        next if index.zero?
        f << row.join(';') << "\n"
      end
    end

    # Find the total runtime for energyplus and save it into a registerValue
    total_time = -999
    location_of_file = ['../eplusout.end', './run/eplusout.end']
    first_index = location_of_file.map {|f| File.exist?(f)}.index(true)
    if first_index
      match = File.read(location_of_file[first_index]).to_s.match(/Elapsed.Time=(.*)hr(.*)min(.*)sec/)
      total_time = match[1].to_i * 3600 + match[2].to_i * 60 + match[3].to_f
    end

    runner.registerValue('energyplus_runtime', total_time, 'sec')
    runner.registerValue('peak_cooling_load', peak_cooling, 'W')
    runner.registerValue('peak_heating_load', peak_heating, 'W')
    runner.registerValue('peak_water_heating', peak_water_heating, 'W')

    return true
  ensure
    sqlFile.close if sqlFile
  end
end

# register the measure to be used by the application
ExportModelicaLoads.new.registerWithApplication
