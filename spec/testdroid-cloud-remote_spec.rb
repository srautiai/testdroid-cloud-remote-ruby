require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Testdroid::Cloud::Remote do
  it "should have a username after init" do
    remote = Testdroid::Cloud::Remote.new('username', 'password', 'localhost','61613')
	remote.instance_variable_get('@username').should == 'username'
  end
end
