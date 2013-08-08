#!/usr/bin/ruby
gem 'testdroid-cloud', '= 0.1.3'
gem 'testdroid-cloud-remote', '= 0.1.4'
require 'testdroid-cloud'
require 'testdroid-cloud-remote'
require 'logger'
#require 'testdroid-cloud-remote'

def test_run(username,password,apk_filename, project_name, device_id, logger)
	begin 
		
		cloud = Testdroid::Cloud::Client.new(username, password)
		cloud.logger =  logger
		#cloud.authorize
		user =  cloud.get_user
		if(user.nil?) 
			abort("Could not login ")
		end

		projects = user.projects()
		if(projects.list().nil?)
			puts "cant find project"
			return
		end
		#List of projects
		for project in projects.list()
			puts "Project: #{project.name}"
		end
		
		#Get project
		remoteProject = user.projects().list().detect {|p| p.name == project_name }
		if(remoteProject.nil?) 
			abort("Could not find project #{remoteProject}")
		end
		#ret = projects.get(remoteProject.id).uploadAPK(apk_filename)
		ret = "22"
		if(ret.nil?) 
			abort("Could not upload apk: #{apk_filename}")
		end
		#puts ret
		devices = user.devices()
		#List of Devices
		for device in devices.list()
			puts "Device name: #{device.user_name} ID: #{device.id} #{device.serial_id}"
			
		end
		
		#Run project - run using just one device (multiple devices can be used device_id='1232323,434234,53535')
		run =  remoteProject.run(nil, false, device_id ) 
		#device runs are created async..have to wait until ready
		sleep 2
		device_runs =  projects.get(remoteProject.id).runs.get(run.id).device_runs.list()
		if(device_runs.nil?) 
			abort("Couldn't find device_runs!!")
		end
		
		return [run.id, device_runs]
	end
end
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
	
	
	dev_prop = remote_conn.device_properties
	if dev_prop.nil? 
		remote_conn.close
		abort "Error receiving"
		
	end
	d_puts device_run_id,"Screen resolution #{dev_prop['display.height']}x#{dev_prop['display.width']}"
	
	#Shell command
	ls_reply = remote_conn.shell_cmd("ls")
	d_puts device_run_id, "Console output: #{ls_reply['output']}"
	remote_conn.touch(22,34)
	
	remote_conn.drag(22,134, 323,133)
	sleep 5
	d_puts device_run_id, "Drag and touch complete"
	#Clear logcat
	remote_conn.shell_cmd("logcat -c")
	#Start activity
	remote_conn.start_activity("com.bitbar.testdroid.html5/.SampleActivity")
	#Shell command logcat (-d option needs to be used logcat command dumps content and exists)
	log_output = remote_conn.shell_cmd("logcat -v time -d")
	
	if !log_output.nil?
		d_puts(device_run_id,"log output: #{log_output['output']}")
	else
		d_puts device_run_id,"No logcat output"
	end
	#Normal drag
	d_puts device_run_id,"Normal drag"
	remote_conn.drag(240,134, 1,134, 9, 200)
	sleep 5
	1.times do |nro|
		d_puts device_run_id,"Take screenshot"
		remote_conn.take_screenshot("#{device_run_id}_screenshot#{nro}.png")
	end
	#Special drag command
	d_puts device_run_id,"Special drag "
	remote_conn.drag_m(240,134,123, 1,134,111, 9, 200)
	d_puts device_run_id,"closing connection"
	#remote.reboot
	remote_conn.close
end

if ARGV.length == 5
	username =  ARGV[0]
	password =ARGV[1]
	apk_filename = ARGV[2]
	project_name = ARGV[3]
	device_id = ARGV[4]
	log_file = File.open('/tmp/remote.log', File::WRONLY | File::APPEND | File::CREAT)
	logger = Logger.new(log_file)
	run_data = test_run(username, password, apk_filename, project_name, device_id, logger)
	
	
	if(run_data.nil?) 
		abort("Test didn't start succesfully")
	end
	device_runs = run_data[1]
	threads = []
		
	 # Createa a new thread for every device run
	for device_run in device_runs
		threads << Thread.new(device_run) { |d_run|

		control_device('your_username', 'your_password',"cloud.testdroid.com", d_run.id,run_data[0])
	}
	
	end

	threads.each { |aThread|  aThread.join }
	puts "Done"
	log_file.close
else
  STDOUT.puts <<-EOF
Please provide parameters

Usage:
  remote_control.rb <username> <password> <apk filename> <project name> <device  id>
EOF
end











