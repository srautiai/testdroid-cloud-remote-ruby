#!/usr/bin/ruby

require 'stomp'
require 'json'

module Testdroid

	module Cloud	
		class Remote 
			def initialize(username, password, url, port)  
					# Instance variables  
					@username = username  
					@password = password  
					@url = url
					@port = port
					
				end  
				#Open connection to remote server
				def open
					puts "Connecting #{@url}:#{@port}"
					@remoteClient = Stomp::Client.new(@username, @password, @url, @port, true)
				end
				#End session - free to device for other use
				def close
					send_command("END");
					sleep 5
					@remoteClient.close
				end
				# wait until device is available 
				def wait_for_connection(build_id, device_id, time_out=0)
					puts "Waiting for device #{device_id}"
					queue_name = "/queue/#{build_id}.REMOTE.#{device_id}"
					@remoteClient.subscribe(queue_name, { :ack =>"auto" }, &method(:receiveMsg))
					begin 
						Timeout::timeout(time_out) do
							while @cmdDestination.nil?  do
							sleep 0.3 
							end
						end
						rescue Timeout::Error
						$stderr.puts "Timeout when waiting device to connect" 
						return nil
					end
				end  
				#Show device connection
				def display  
					puts "Device(#{@deviceId}) is connected: #{@deviceConnected} reply queue: #{@cmdDestination} "  
				end  
				#Touch device screen on coordinates
				def touch(x,y) 
					return if !checkConn
					send_command("TOUCH #{x}, #{y}");
				end
				#Drag from position to other with steps and duration
				def drag(startx,starty,endx,endy,steps = 10, duration=500) 
					return if !checkConn
					send_command("DRAG #{startx}, #{starty}, #{endx}, #{endy}, #{steps}, #{duration}");
				end
				#Special drag - startXY,sleep,endXY,sleep,end2XY
				def drag_m(startx,starty,durationDrag,endx,endy, durationStall, end2x,end2y) 
					return if !checkConn
					send_command("DRAG_M #{startx}, #{starty}, #{durationDrag}, #{endx}, #{endy}, #{durationDrag}, #{end2x}, #{end2y}");
				end
				#Reboot device
				def reboot
					return if !checkConn
					send_command("REBOOT");
				end
				#Executes an adb shell command and returns the result
				def shell_cmd(shell_cmd)
					return if !checkConn
					send_command("SHELL #{shell_cmd}");
					return get_response
				end
				#am  start -n command: am start -n com.bitbar.testdroid/.BitbarSampleApplicationActivity
				def start_activity(activity)
					return if !checkConn
					send_command("START_ACTIVITY #{activity}");
				end
				#Get device properties from device
				def device_properties()
					return if !checkConn
					send_command("REQUEST_PROPERTIES")
					return get_response
				end
				#Take screenshot and store into file system
				def take_screenshot(filename = "screenshot1.png")
					return if !checkConn
					@screenshotFilename = filename
					send_command("SCREENSHOT")
					get_response
				end
				
				private
				def send_command(monkeyCommand)
					@remoteClient.publish(@cmdDestination, monkeyCommand ,{'persistent'=>'false', 'amq-msg-type'=>'text'})
				end
				def receiveMsg(msg)
				
					if !@cmdDestination.nil?
						if !msg.headers["content-length"].nil?
							puts "Saving binary message #{@screenshotFilename}"
							
							a_file = File.open(@screenshotFilename, "wb") 
							a_file.write(msg.body)
							a_file.close
							puts "File closed"
							@response  = @screenshotFilename
							
							
							return
						end
						#Parse JSON response - TODO: add rescue
						@response = JSON.parse( msg.body )
				
						return;
					end
					if msg.body =~ /^DEVICE_CONNECTED\s\w*/
								
						@deviceConnected = true
						match1 = msg.body.match /^DEVICE_CONNECTED\s(\w*)/
						@deviceId = match1[1]
						puts "device connected #{match1[1]}"
						@cmdDestination = msg.headers["reply-to"]
						return
					end 
				end
				
				def checkConn
					if @deviceId.nil? 
						$stderr.puts "Not connected to device" 
						return false
					end
					if @cmdDestination.nil? 
						$stderr.puts "Not connected to device - no reply destination" 
						return false
					end
					if @remoteClient.closed? 
						$stderr.puts "Client is not connected" 
						return false
					end
					return true
				end
				
				
				def get_response
					begin
					# Don't wait longer than 20 seconds to retrieve content
					Timeout::timeout(20) do
						while @response.nil?  do
							sleep 0.3 
						end
					end
					rescue Timeout::Error
						$stderr.puts "Timeout when receiving response" 
						return nil
					end
					lastResponse =  @response.clone
					@response = nil
					return lastResponse
				end
		end
	end
end  

if __FILE__ == $0
remote = Testdroid::Cloud::Remote.new('','', 'localhost', 61613)

remote.open
remote.wait_for_connection('ABCDE','016B732C1900701A')
remote.display
dev_prop = remote.device_properties
if dev_prop.nil? 
	remote.close
	abort "Error receiving"
	
end
puts "X: #{dev_prop['display.height']}"
puts "Y: #{dev_prop['display.width']}"

remote.touch(22,34)
sleep 5
remote.drag(22,134, 323,133)
sleep 5
remote.drag_m(240,134,1000, 1,134, 2000, 10,134 )
remote.take_screenshot("screenshot12.png")
puts "Run shell command"
i_output = remote.shell_cmd("input text abcd\n")
#puts("Text input output: #{i_output['output']}")
puts "Run 2nd shell command"
ls_output = remote.shell_cmd("ls")
#puts("LS output: #{ls_output['output']}")

dump_output = remote.shell_cmd("dumpsys")
#puts("LS output: #{dump_output['output']}")


remote.close
puts "End"
end
