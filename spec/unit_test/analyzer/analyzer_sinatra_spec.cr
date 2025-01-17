require "../../../src/analyzer/analyzers/analyzer_sinatra.cr"
require "../../../src/options"

describe "mapping_to_path" do
  options = default_options()
  instance = AnalyzerSinatra.new(options)

  it "line_to_param - param[]" do
    line = "param['id']"
    instance.line_to_param(line).name.should eq("id")
  end

  it "line_to_param - params[]" do
    line = "params['id']"
    instance.line_to_param(line).name.should eq("id")
  end

  it "line_to_param - headers[]" do
    line = "headers['x-token']"
    instance.line_to_param(line).name.should eq("x-token")
  end

  it "line_to_param - request.env" do
    line = "request.env[\"x-token\"]"
    instance.line_to_param(line).name.should eq("x-token")
  end
end
