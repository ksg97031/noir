require "../../utils/utils.cr"
require "../../models/analyzer"

class AnalyzerJsp < Analyzer
  def analyze
    # Source Analysis
    begin
      Dir.glob("#{base_path}/**/*") do |path|
        next if File.directory?(path)

        relative_path = get_relative_path(base_path, path)

        if File.exists?(path) && File.extname(path) == ".jsp"
          File.open(path, "r", encoding: "utf-8", invalid: :skip) do |file|
            params_query = [] of Param

            file.each_line do |line|
              if line.includes? "request.getParameter"
                match = line.strip.match(/request.getParameter\("(.*?)"\)/)
                if match
                  param_name = match[1]
                  params_query << Param.new(param_name, "", "query")
                end
              end

              if line.includes? "${param."
                match = line.strip.match(/\$\{param\.(.*?)\}/)
                if match
                  param_name = match[1]
                  params_query << Param.new(param_name, "", "query")
                end
              end
            rescue
              next
            end
            result << Endpoint.new("#{url}/#{relative_path}", "GET", params_query)
          end
        end
      end
    rescue e
      logger.debug e
    end
    Fiber.yield

    result
  end

  def allow_patterns
    ["$_GET", "$_POST", "$_REQUEST", "$_SERVER"]
  end
end

def analyzer_jsp(options : Hash(Symbol, String))
  instance = AnalyzerJsp.new(options)
  instance.analyze
end
