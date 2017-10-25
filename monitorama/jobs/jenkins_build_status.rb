require 'net/http'
require 'json'

JENKINS_URI = "http://localhost:8080/"

JENKINS_AUTH = {
  'name' => 'murchie',
  'password' => 'commando'
}

SCHEDULER.every '10s' do

  json = getFromJenkins(JENKINS_URI + 'api/json?pretty=true')

  failedJobs = Array.new
  succeededJobs = Array.new
  array = json['jobs']
  array.each {
    |job|

    next if job['color'] == 'disabled'
    next if job['color'] == 'notbuilt'
    next if job['color'] == 'blue'
    next if job['color'] == 'blue_anime'

    jobStatus = '';
    if job['color'] == 'yellow' || job['color'] == 'yellow_anime'
      jobStatus = getFromJenkins(job['url'] + 'lastUnstableBuild/api/json')
    elsif job['color'] == 'aborted' || job['color'] == 'aborted_anime'
      jobStatus = getFromJenkins(job['url'] + 'lastUnsuccessfulBuild/api/json')
    else
      jobStatus = getFromJenkins(job['url'] + 'lastFailedBuild/api/json')
    end

    culprits = jobStatus['culprits']

    culpritName = getNameFromCulprits(culprits)
    if culpritName != ''
       culpritName = culpritName.partition('<').first
    end

    failedJobs.push({ label: job['name'], value: culpritName})
  }

  failed = failedJobs.size > 0

  send_event('jenkinsBuildStatus', { failedJobs: failedJobs, succeededJobs: succeededJobs, failed: failed })
end

def getFromJenkins(path)

  uri = URI.parse(path)
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  if JENKINS_AUTH['name']
    request.basic_auth(JENKINS_AUTH['name'], JENKINS_AUTH['password'])
  end
  response = http.request(request)

  json = JSON.parse(response.body)
  return json
end

def getNameFromCulprits(culprits)
  if culprits.to_s() == ''
       return ''
  end 
  culprits.each {
    |culprit|
    return culprit['fullName']
  }
  return ''
end