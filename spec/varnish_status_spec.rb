require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), "../config.yaml"))

describe 'no directors in server names all healthy' do
  before (:each) do
    VarnishBackendStatus.should_receive(:'`').with("#{CONFIG[:varnishadm]} #{CONFIG[:varnishadm_opts]} backend.list").and_return ("Backend name                   Refs   Admin      Probe\nserver1(1.1.1.1,,80) 1      probe      Healthy 10/10\nserver2(2.2.2.2,,80) 1      probe      Healthy 10/10\nserver3(3.3.3.3,,80) 1      probe      Healthy 10/10\nserver4(4.4.4.4,,80) 1      probe      Healthy 10/10\nserver5(5.5.5.5,,80) 1      probe      Healthy 10/10")
  end

  it "shows the start page" do
    get '/'

    last_response.should be_ok
    last_response.body.should include "status-OK"
    last_response.body.should_not include "status-WARNING"
    last_response.body.should_not include "status-CRITICAL"
  end

  it "returns the json status" do
    get '/internal/status'

    parsed_body = JSON.parse(last_response.body)

    last_response.should be_ok
    parsed_body["application"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server1"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server2"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server3"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server4"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server5"]["status"].should include "OK"
  end  
end

describe 'no directors in server names one unhealthy' do
  before (:each) do
    VarnishBackendStatus.should_receive(:'`').with("#{CONFIG[:varnishadm]} #{CONFIG[:varnishadm_opts]} backend.list").and_return ("Backend name                   Refs   Admin      Probe\nserver1(1.1.1.1,,80) 1      probe      Healthy 10/10\nserver2(2.2.2.2,,80) 1      probe      Healthy 10/10\nserver3(3.3.3.3,,80) 1      probe      Healthy 10/10\nserver4(4.4.4.4,,80) 1      probe      Healthy 10/10\nserver5(5.5.5.5,,80) 1      probe      Sick 2/10")
  end

  it "shows the start page" do
    get '/'

    last_response.should be_ok
    last_response.body.should_not include "status-WARNING"
    last_response.body.should include "status-CRITICAL"
    last_response.body.should include "server5 (5.5.5.5) / SICK"
  end

  it "returns the json status" do
    get '/internal/status'

    parsed_body = JSON.parse(last_response.body)

    last_response.should be_ok
    parsed_body["application"]["status"].should include "CRITICAL"
    parsed_body["application"]["statusDetails"]["server1"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server2"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server3"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server4"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["server5"]["status"].should include "CRITICAL"
  end  
end

describe 'healthy cluster' do
  
  before (:each) do
    VarnishBackendStatus.should_receive(:'`').with("#{CONFIG[:varnishadm]} #{CONFIG[:varnishadm_opts]} backend.list").and_return ("Backend name                   Refs   Admin      Probe\nserver1_pool1(1.1.1.1,,80) 1      probe      Healthy 10/10\nserver2_pool1(2.2.2.2,,80) 1      probe      Healthy 10/10\nserver3_pool2(3.3.3.3,,80) 1      probe      Healthy 10/10\nserver4_pool2(4.4.4.4,,80) 1      probe      Healthy 10/10\nserver5_pool2(5.5.5.5,,80) 1      probe      Healthy 10/10")
  end

  it "shows the start page" do
    get '/'
    
    last_response.should be_ok
    last_response.body.should include "status-OK"
    last_response.body.should_not include "status-WARNING"
    last_response.body.should_not include "status-CRITICAL"
  end

  it "returns the json status" do
    get '/internal/status'

    parsed_body = JSON.parse(last_response.body)
    
    last_response.should be_ok
    parsed_body["application"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["pool1"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["pool2"]["status"].should include "OK"
  end

  it "returns the details for the cluster" do
    get '/internal/details'

    parsed_body = JSON.parse(last_response.body)
    last_response.should be_ok
    parsed_body["pool1"]["backends"].each  do |backend|
      backend["status"].should include "HEALTHY"
      backend["status"].should_not include "SICK"
    end

    parsed_body["pool2"]["backends"].each  do |backend|
      backend["status"].should include "HEALTHY"
      backend["status"].should_not include "SICK"
    end
  end
end

describe 'unhealthy cluster below threshold' do
  before (:each) do
    VarnishBackendStatus.should_receive(:'`').with("#{CONFIG[:varnishadm]} #{CONFIG[:varnishadm_opts]} backend.list").and_return ("Backend name                   Refs   Admin      Probe\nserver1_pool1(1.1.1.1,,80) 1      probe      Healthy 10/10\nserver2_pool1(2.2.2.2,,80) 1      probe      Healthy 10/10\nserver3_pool2(3.3.3.3,,80) 1      probe      Sick 2/10\nserver4_pool2(4.4.4.4,,80) 1      probe      Healthy 10/10\nserver5_pool2(5.5.5.5,,80) 1      probe      Sick 0/10")
  end

  it "shows the start page" do
    get '/'
    
    last_response.should be_ok
    last_response.body.should include "status-OK"
    last_response.body.should include "status-CRITICAL"
    last_response.body.should_not include "status-WARNING"

  end

  it "returns the json status" do
    get '/internal/status'

    parsed_body = JSON.parse(last_response.body)
    
    last_response.should be_ok
    parsed_body["application"]["status"].should include "CRITICAL"
    parsed_body["application"]["statusDetails"]["pool1"]["status"].should include "OK"
    parsed_body["application"]["statusDetails"]["pool2"]["status"].should include "CRITICAL"
  end

  it "returns the details for the cluster" do
    get '/internal/details'

    parsed_body = JSON.parse(last_response.body)
    last_response.should be_ok
    parsed_body["pool1"]["backends"].each  do |backend|
      backend["status"].should include "HEALTHY"
      backend["status"].should_not include "SICK"
    end

    parsed_body["pool2"]["backends"][0]["status"].should_not include "HEALTHY"
    parsed_body["pool2"]["backends"][0]["status"].should include "SICK"

    parsed_body["pool2"]["backends"][1]["status"].should include "HEALTHY"
    parsed_body["pool2"]["backends"][1]["status"].should_not include "SICK"

    parsed_body["pool2"]["backends"][2]["status"].should_not include "HEALTHY"
    parsed_body["pool2"]["backends"][2]["status"].should include "SICK"
  end
end

describe 'unhealthy cluster' do
before (:each) do
    VarnishBackendStatus.should_receive(:'`').with("#{CONFIG[:varnishadm]} #{CONFIG[:varnishadm_opts]} backend.list").and_return ("Backend name                   Refs   Admin      Probe\nserver1_pool1(1.1.1.1,,80) 1      probe      Sick 0/10\nserver2_pool1(2.2.2.2,,80) 1      probe      Sick 0/10\nserver3_pool2(3.3.3.3,,80) 1      probe      Sick 2/10\nserver4_pool2(4.4.4.4,,80) 1      probe      Sick 0/10\nserver5_pool2(5.5.5.5,,80) 1      probe      Sick 0/10")
  end

  it "shows the start page" do
    get '/'
    
    last_response.should be_ok
    last_response.body.should_not include "status-OK"
    last_response.body.should include "status-CRITICAL"
    last_response.body.should_not include "status-WARNING"

  end

  it "returns the json status" do
    get '/internal/status'

    parsed_body = JSON.parse(last_response.body)
    
    last_response.should be_ok
    parsed_body["application"]["status"].should include "CRITICAL"
    parsed_body["application"]["statusDetails"]["pool1"]["status"].should include "CRITICAL"
    parsed_body["application"]["statusDetails"]["pool2"]["status"].should include "CRITICAL"
  end

  it "returns the details for the cluster" do
    get '/internal/details'

    parsed_body = JSON.parse(last_response.body)
    
    last_response.should be_ok
    parsed_body["pool1"]["backends"].each  do |backend|
      backend["status"].should_not include "HEALTHY"
      backend["status"].should include "SICK"
    end

    parsed_body["pool2"]["backends"].each  do |backend|
      backend["status"].should_not include "HEALTHY"
      backend["status"].should include "SICK"
    end
  end
end

describe 'cluster in warning' do
  before (:each) do
    VarnishBackendStatus.should_receive(:'`').with("#{CONFIG[:varnishadm]} #{CONFIG[:varnishadm_opts]} backend.list").and_return ("Backend name                   Refs   Admin      Probe\nserver1_pool1(1.1.1.1,,80) 1      probe      Sick 0/10\nserver2_pool1(2.2.2.2,,80) 1      probe      Healthy 10/10\nserver3_pool2(3.3.3.3,,80) 1      probe      Healthy 10/10\nserver4_pool2(4.4.4.4,,80) 1      probe      Healthy 10/10\nserver5_pool2(5.5.5.5,,80) 1      probe      Sick 0/10")
  end

  it "shows the start page" do
    get '/'
    
    last_response.should be_ok
    last_response.body.should_not include "status-OK"
    last_response.body.should_not include "status-CRITICAL"
    last_response.body.should include "status-WARNING"
  end

  it "returns the json status" do
    get '/internal/status'

    parsed_body = JSON.parse(last_response.body)
    
    last_response.should be_ok
    parsed_body["application"]["status"].should include "WARNING"
    parsed_body["application"]["statusDetails"]["pool1"]["status"].should include "WARNING"
    parsed_body["application"]["statusDetails"]["pool2"]["status"].should include "WARNING"
  end

  it "returns the details for the cluster" do
    get '/internal/details'

    parsed_body = JSON.parse(last_response.body)
    
    last_response.should be_ok

    parsed_body["pool1"]["backends"][0]["status"].should_not include "HEALTHY"
    parsed_body["pool1"]["backends"][0]["status"].should include "SICK"

    parsed_body["pool1"]["backends"][1]["status"].should include "HEALTHY"
    parsed_body["pool1"]["backends"][1]["status"].should_not include "SICK"
    
    parsed_body["pool2"]["backends"][0]["status"].should include "HEALTHY"
    parsed_body["pool2"]["backends"][0]["status"].should_not include "SICK"

    parsed_body["pool2"]["backends"][1]["status"].should include "HEALTHY"
    parsed_body["pool2"]["backends"][1]["status"].should_not include "SICK"

    parsed_body["pool2"]["backends"][2]["status"].should_not include "HEALTHY"
    parsed_body["pool2"]["backends"][2]["status"].should include "SICK"

  end
end
