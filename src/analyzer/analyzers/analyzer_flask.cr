require "../../models/analyzer"

class AnalyzerFlask < Analyzer
  REGEX_PYTHON_VARIABLE_NAME = "[a-zA-Z_][a-zA-Z0-9_]*"
  HTTP_METHOD_NAMES = ["get", "post", "put", "patch", "delete", "head", "options", "trace"]
  INDENT_SPACE_SIZE = 4

  def analyze
    blueprint_prefix_map = {} of String => String
    Dir.glob("#{base_path}/**/*.py") do |path|
      next if File.directory?(path)
      File.open(path, "r", encoding: "utf-8", invalid: :skip) do |file|
        file.each_line do |line|
          # [TODO] We should be cautious about instance name changes.
          match = line.match /(#{REGEX_PYTHON_VARIABLE_NAME})\s*=\s*Flask\s*\(/
          if !match.nil?
            flask_instance_name = match[1]
            if !blueprint_prefix_map.has_key? flask_instance_name
              blueprint_prefix_map[flask_instance_name] = ""
            end
          end

          # https://flask.palletsprojects.com/en/2.3.x/blueprints/#nesting-blueprints
          match = line.match /(#{REGEX_PYTHON_VARIABLE_NAME})\s*=\s*Blueprint\s*\(/
          if !match.nil?
            prefix = ""
            blueprint_instance_name = match[1]            
            param_codes = line.split("Blueprint", 2)[1]
            prefix_match = param_codes.match /url_prefix\s=\s['"](['"]*)['"]/
            if !prefix_match.nil? && prefix_match.size == 2
              prefix = prefix_match[1]
            end

            if !blueprint_prefix_map.has_key? blueprint_instance_name
              blueprint_prefix_map[blueprint_instance_name] = prefix
            end
          end
        end
      end
    end    

    Dir.glob("#{base_path}/**/*.py") do |path|
      next if File.directory?(path)
      source = File.read(path, encoding: "utf-8", invalid: :skip) 
      lines = source.split "\n"

      line_index = 0
      while line_index < lines.size
        line = lines[line_index]
        blueprint_prefix_map.each do |flask_instance_name, prefix|
          line.scan(/@#{flask_instance_name}\.route\(['"]([^'"]*)['"](.*)/) do |match|        
            if match.size > 0
              route_path = match[1]
              extra_params = match[2]

              if !prefix.ends_with? "/" && !route_path.starts_with? "/"
                prefix = "#{prefix}/"
              end

              # https://flask.palletsprojects.com/en/2.3.x/quickstart/#http-methods
              methods_match = extra_params.match /methods\s*=\s*(.*)/
              if !methods_match.nil? && methods_match.size == 2
                declare_methods = methods_match[1].downcase
                HTTP_METHOD_NAMES.each do |method_name|
                  if declare_methods.includes? method_name
                    result << Endpoint.new("#{@url}#{prefix}#{route_path}", method_name.upcase)
                  end
                end
              else
                result << Endpoint.new("#{@url}#{prefix}#{route_path}", "GET")
              end
            end
          end
        end
        line_index += 1
      end
    end
    Fiber.yield

    result
  end

  def parse_function_or_class(content : String)
    lines = content.split("\n")

    # Skip decorator
    line_index = 0
    while line_index < lines.size
      decorator_match = lines[line_index].match /\s*@/
      if !decorator_match.nil?
        line_index += 1
      else
        function_or_class_declaration = lines[line_index].match /\s*(def |class )/i
        if !function_or_class_declaration.nil?
          lines = lines[line_index..]
          break
        end
      end
    end

    indent_size = 0
    if lines.size > 0
      while indent_size < lines[0].size && lines[0][indent_size] == ' '
        # Only spaces, no tabs
        indent_size += 1
      end

      indent_size += INDENT_SPACE_SIZE
    end

    if indent_size > 0
      double_quote_open, single_quote_open = [false] * 2
      double_comment_open, single_comment_open = [false] * 2
      end_index = lines[0].size + 1
      lines[1..].each do |line|
        line_index = 0
        clear_line = line
        while line_index < line.size
          if line_index < line.size - 2
            if !single_quote_open && !double_quote_open
              if !double_comment_open && line[line_index..line_index + 2] == "'''"
                single_comment_open = !single_comment_open
                line_index += 3
                next
              elsif !single_comment_open && line[line_index..line_index + 2] == "\"\"\""
                double_comment_open = !double_comment_open
                line_index += 3
                next
              end
            end
          end

          if !single_comment_open && !double_comment_open
            if !single_quote_open && line[line_index] == '"' && line[line_index - 1] != '\\'
              double_quote_open = !double_quote_open
            elsif !double_quote_open && line[line_index] == '\'' && line[line_index - 1] != '\\'
              single_quote_open = !single_quote_open
            elsif !single_quote_open && !double_quote_open && line[line_index] == '#' && line[line_index - 1] != '\\'
              clear_line = line[..(line_index - 1)]
              break
            end
          end

          # [TODO] Remove comments on codeblock
          line_index += 1
        end

        open_status = single_comment_open || double_comment_open || single_quote_open || double_quote_open
        if clear_line[0..(indent_size - 1)].strip == "" || open_status
          end_index += line.size + 1
        else
          break
        end
      end

      end_index -= 1
      return content[..end_index].strip
    end

    nil
  end
end

def analyzer_flask(options : Hash(Symbol, String))
  instance = AnalyzerFlask.new(options)
  instance.analyze
end
