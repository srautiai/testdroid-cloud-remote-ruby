
gem 'testdroid-cloud-remote', '= 0.1.5'
gem 'testdroid-api-client', '= 0.0.3'
require 'testdroid-api-client'
require 'testdroid-cloud-remote'
require 'logger'

def d_puts(device, msg)
        puts Time.now
        puts "device:#{device} \t #{msg}"
end
def control_device(username, password,host, device_run_id, run_id, logger )
	
	stomp_hash = {
    :hosts => [
      	{:login => username, :passcode => password, :host => host, :port => 61612, :ssl => true},
    	],
    	:parse_timeout => 150,
    	:logger => logger
  	}

	#remote_conn = Testdroid::Cloud::Remote.new(username,password, host, 61613)
	remote_conn = Testdroid::Cloud::Remote.new(stomp_hash)
	
	
	if(remote_conn.nil?) 
		abort("Could not connect remote controller host")
	end
	
	d_puts device_run_id,"Connecting.."
	remote_conn.open
	d_puts device_run_id,"waiting for connection..run:#{run_id} device_run:#{device_run_id}"
	remote_conn.wait_for_connection(run_id, device_run_id)
	
	remote_conn.touch(37,261)
	sleep 2
	remote_conn.touch(37,290)
	sleep 2
	remote_conn.touch(37,320)
	
	sleep 2
	remote_conn.drag(22,134, 323,133)
	sleep 5
	d_puts device_run_id, "Drag and touch complete"
	
	d_puts device_run_id,"Normal drag"
	remote_conn.drag(240,134, 1,134, 9, 200)

	sleep 5
	1.times do |nro|
		d_puts device_run_id,"Take screenshot"
		remote_conn.take_screenshot("#{device_run_id}_screenshot#{nro}.tiff")
	end
	
	d_puts device_run_id,"closing connection"
	
	remote_conn.close
end

def launch_ios_run 
	
	#client = TestdroidAPI::Client.new('admin@localhost', 'admin', 'http://localhost:8080/testdroid-cloud')
	client = TestdroidAPI::Client.new('myaccount', 'mypassword')
 	user = client.authorize
 	projects_list = user.projects.list
	ios_project = nil
	while(ios_project == nil) 
		ios_project = projects_list.detect { |proj| proj.type == "IOS" }
		projects_list = projects_list.next_page
	end
 	
 	ios_project.files.uploadApplication('/Users/sakari/BitbarIOSSample.ipa')
 	ios_project.run('new run')
  	sleep 2
 	running_run = ios_project.runs.list.first
	running_run.device_runs.list.first.device['id']
	return [ running_run.device_runs.list.first.id, running_run.id]
end

if ARGV.length == 0
	
	log_file = File.open('/tmp/remote.log', File::WRONLY | File::APPEND | File::CREAT)
	logger = Logger.new(log_file)
	
	params = launch_ios_run
    control_device('myaccount', 'mypassword',"cloud.testdroid.com", params[0],params[1], logger)
	
	puts "Done"
	log_file.close
else
  STDOUT.puts <<-EOF


Usage:
  control_ios.rb
EOF
end











