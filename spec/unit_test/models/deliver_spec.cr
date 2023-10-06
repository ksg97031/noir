require "../../../src/models/deliver.cr"
require "../../../src/options.cr"

describe "Initialize" do
  options = default_options
  options[:base] = "noir"
  options[:send_proxy] = "http://localhost:8090"

  it "Deliver" do
    object = Deliver.new options
    object.proxy.should eq("http://localhost:8090")
  end

  it "Deliver with headers" do
    options[:send_with_headers] = "X-API-Key: abcdssss"
    object = Deliver.new options
    object.headers["X-API-Key"].should eq("abcdssss")
  end
end