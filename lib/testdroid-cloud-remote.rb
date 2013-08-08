#!/usr/bin/ruby

require 'stomp'
require 'json'

module Testdroid

	module Cloud	
		class Remote
				# The login username used by the client.
				attr_reader :username 
				
				# The login password used by the client.
				attr_reader :password 
				
				# The stomp endpoint used by the client.
				attr_reader :url 
				
				# The stomp port used by the client.
				attr_reader :port 
				
				# The Stomp connection hash used by the client.
				attr_reader :conn_hash 
				
				#username, password, url, port
				#or
				#stomp connection hash = > see Stomp client init for details
				def initialize(username, password='', url='localhost', port=61613, logger = Logger.new(STDOUT)  )  
					if username.is_a?(Hash)
						@conn_hash = username 
						first_host = @conn_hash[:hosts][0]
						@username = first_host[:login]
						@password = first_host[:passcode]
						@url = first_host[:host]
						@port = first_host[:port] || Connection::default_port(first_host[:ssl])
						@reliable = true
						@logger =  @conn_hash[:logger] 
						if(@logger.nil?) 
							@logger = Logger.new(STDOUT)
							@logger.info("Logger is not defined => output to STDOUT")
						end
						
					else
						# Instance variables  
						@username = username  
						@password = password  
						@url = url
						@port = port
						@logger = logger 
					end
				end
								
				#Open connection to remote server
				def open
					@logger.info( "Connecting #{@url}:#{@port}")
					if @conn_hash 
						@remoteClient = Stomp::Client.new(@conn_hash)
					else 
						@remoteClient = Stomp::Client.new(@username, @password, @url, @port, true)
					end
				end
				#End session - free to device for other use
				def close
					send_command("END");
					sleep 5
					@remoteClient.close
				end
				# wait until device is available 
				def wait_for_connection(build_id, device_id, time_out=0)
					@logger.info("Waiting for device #{device_id}")
					
					queue_name = "/queue/#{build_id}.REMOTE.#{device_id}"
					@remoteClient.subscribe(queue_name, { :ack =>"auto" }, &method(:receiveMsg))
					begin 
						Timeout::timeout(time_out) do
							while @cmdDestination.nil?  do
							sleep 0.3 
							end
						end
						rescue Timeout::Error
						@logger.error("Timeout when waiting device to connect" )
						return nil
					end
				end  
				#Show device connection
				def display  
					@logger.info( "Device(#{@deviceId}) is connected: #{@deviceConnected} reply queue: #{@cmdDestination} " ) 
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
							@logger.info( "Saving binary message #{@screenshotFilename}")
							
							a_file = File.open(@screenshotFilename, "wb") 
							a_file.write(msg.body)
							a_file.close
							@logger.info("file closed")
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
						@logger.info("device connected #{match1[1]}")
						@cmdDestination = msg.headers["reply-to"]
						return
					end 
				end
				
				def checkConn
					if @deviceId.nil? 
						@logger.error("device connected #{match1[1]}")
						return false
					end
					if @cmdDestination.nil? 
						@logger.error("Not connected to device - no reply destination")
						return false
					end
					if @remoteClient.closed? 
						@logger.error("Client is not connected" )

						return false
					end
					return true
				end
				
				
				def get_response
					begin
					# Don't wait longer than 20 seconds to retrieve content
					Timeout::timeout(50) do
						while @response.nil?  do
							sleep 0.3 
						end
					end
					rescue Timeout::Error

						@logger.error("#{Time.now} Timeout when receiving response(50SEC)")

						return nil
					end
					lastResponse =  @response.clone
					@response = nil
					return lastResponse
				end
		end
	end
end  
