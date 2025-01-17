require "../../models/analyzer"

class AnalyzerCsAspNetMvc < Analyzer
  def analyze
    # Static Analysis
    locator = CodeLocator.instance
    route_config_file = locator.get("cs-apinet-mvc-routeconfig")

    if File.exists?("#{route_config_file}")
      File.open("#{route_config_file}", "r", encoding: "utf-8", invalid: :skip) do |file|
        maproute_check = false
        maproute_buffer = ""

        file.each_line do |line|
          if line.includes? ".MapRoute("
            maproute_check = true
            maproute_buffer = line
          end

          if line.includes? ");"
            maproute_check = false
            if maproute_buffer != ""
              buffer = maproute_buffer.gsub(/[\r\n]/, "")
              buffer = buffer.gsub(/\s+/, "")
              buffer.split(",").each do |item|
                if item.includes? "url:"
                  url = item.gsub(/url:/, "").gsub(/"/, "")
                  @result << Endpoint.new("/#{url}", "GET")
                end
              end

              maproute_buffer = ""
            end
          end

          if maproute_check
            maproute_buffer += line
          end
        end
      end
    end

    @result
  end
end

def analyzer_cs_aspnet_mvc(options : Hash(Symbol, String))
  instance = AnalyzerCsAspNetMvc.new(options)
  instance.analyze
end
