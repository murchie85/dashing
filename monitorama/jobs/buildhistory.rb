require 'csv'
require 'net/http'
require 'json'

#constants
JOB_STATUS_HISTORY_FILENAME = 'job_status_history.csv'
NUMBER_SAMPLES_IN_HISTORY = 100
JENKINS_BUILD_STATUS_HISTORY_URI = URI.parse("http://localhost:8080/")

#Trim thresholds (widget display)
MAX_FILENAME_LENGTH = 30
FILENAME_TAIL_LENGTH = 20


#array of all unit test jobs to be processed
$jenkins_jobs_to_be_tracked = [
  'Junit-demo',
  'HELLOGIT',
  'TEST',
  'extractParms',
  'Selenium-test'
]


###################################################################################
# Sub routines
###################################################################################

#helper function that trims file names
#for long filenames, this function keeps all chars up to the 
#trim length, inserts an ellipsis and then keeps the "tail" of the file name
def trim_filename(filename)
  filename_length = filename.length
  
  #trim 'n' splice if necessary
  if filename_length > MAX_FILENAME_LENGTH
    filename = filename.to_s[0..MAX_FILENAME_LENGTH] + '...' + filename.to_s[(filename_length - FILENAME_TAIL_LENGTH)..filename_length]
  end
  
  return filename
end


#this helper function loads the CSV file and creates a JSON message containing build status history info
def get_build_status_json_from_csv_file
  build_status_history = Hash.new
  
  jenkins_job_entries = Array.new
  
  job_index = 0
  CSV.foreach(JOB_STATUS_HISTORY_FILENAME) do |job_status_history_row|
    
    #extract job name
    job_name = job_status_history_row[0]
    
    #create object for Jenkins job
    job_history_entry = Hash.new
    job_history_entry["job_name"] = trim_filename(job_name)
    
    job_status_entries = Array.new

    #iterate across status values for the job_status_history_row
    for status_index in 1 ... job_status_history_row.size
      job_status_item = job_status_history_row[status_index]
      job_status_entries << {"status" => job_status_item}
    end
    
    job_history_entry.merge!("build_status" => job_status_entries)
    
    jenkins_job_entries << job_history_entry
   
    #increment job index
    job_index = job_index + 1
  end  
  
  build_status_history.merge!("jenkins_jobs" => jenkins_job_entries)
end

# This function appends a new set of job status into to the working file
# and trims any old data.
# latest_jenkins_job_status_map is a hash containing Jenkins job name & most recent Jenkins status value )
def update_job_status_history_csv_file(latest_jenkins_job_status_map)
  job_status_history = Array.new

  #check if file exists - if not, create a RAM structure
  if (File.file?(JOB_STATUS_HISTORY_FILENAME) == false)
    #build array
    $jenkins_jobs_to_be_tracked.each do |job_name|
      job_entry = Array.new
      job_entry.push job_name
      
      job_status_history.push job_entry
    end
    
  else
    job_status_history = CSV.read(JOB_STATUS_HISTORY_FILENAME)
    
    #clean out source file
    File.delete(JOB_STATUS_HISTORY_FILENAME)    
  end
  
  #loop through rows of job status info and process
  job_index = 0

  job_status_history.each do |job_status_history_row|
   
    #extract job name
    job_name = job_status_history_row[0]
   
    #check if we need to trim the job status history
    if (job_status_history_row.size > NUMBER_SAMPLES_IN_HISTORY)
      #delete old history item
      job_status_history_row.delete_at(1)
      
      #append new status value to end of row
      job_status_history_row << latest_jenkins_job_status_map[job_name]
    else
      #less than a full set of status history - simply append the new status info
      job_status_history_row << latest_jenkins_job_status_map[job_name] 
      
      job_index = job_index + 1
    end
    
    #write out data to file
    out_file = File.new(JOB_STATUS_HISTORY_FILENAME, "a")
    element_index = 1
    
    job_status_history_row.each do |element|
      out_file << element 
      
      if (element_index == job_status_history_row.length)
        out_file << "\n"
      else
        out_file << ","
      end
      
      element_index = element_index + 1
    end
    out_file.close
  end  
end

#this helper function searches through the jobs entries looking for a specific name
# extracting the build status if found  
def search_for_job_in_full_job_list_json(json_summary, job_name, job_status_hash_table)
  json_summary["jobs"].each do |job_entry|
    if (job_entry["name"] == job_name)
      
      #push new entry into hash table
      job_status_entry = {job_entry["name"] => job_entry["color"]}
      job_status_hash_table.merge!(job_status_entry)
    else
      #print "No match [#{job_entry}]\n"
    end
  end
end


  
SCHEDULER.every '60s', :first_in => 0 do

  num_jobs = $jenkins_jobs_to_be_tracked.count()
  if num_jobs == 0
    raise 'Number of jobs is zero - you must monitor at least one job!'
  end

  if NUMBER_SAMPLES_IN_HISTORY == 0
    raise 'Number of samples in history is zero - you must have at least one sample!'
  end  
   
  #Fetch job status info from Jenkins (full job list)
  http = Net::HTTP.new(JENKINS_BUILD_STATUS_HISTORY_URI.host, JENKINS_BUILD_STATUS_HISTORY_URI.port)
  request = Net::HTTP::Get.new("/api/json?tree=jobs[name,color]")

  response = http.request(request)
  build_info = JSON.parse(response.body)

  $most_recent_jenkins_status_map = Hash.new

  #Search for specific jobs within overall job list
  $jenkins_jobs_to_be_tracked.each do |jenkins_job_name|
    search_for_job_in_full_job_list_json(build_info, jenkins_job_name, $most_recent_jenkins_status_map)
  end

  print "Updating job status history (file) ...\n"
  update_job_status_history_csv_file($most_recent_jenkins_status_map)

  print "loading job status history ...\n"
  $build_status_history_json = get_build_status_json_from_csv_file
 
  print "Sending event to build history widget ...\n"
  send_event('buildhistory', $build_status_history_json)

end