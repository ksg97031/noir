require "../../models/analyzer"
require "json"

class AnalyzerDjango < Analyzer
  def analyze
    result = [] of Endpoint
    url_prefix = ""
    root_django_urls_list = search_root_django_urls_list()
    root_django_urls_list.each do |root_django_urls|      
      django_urls_list = search_django_urls_list(root_django_urls)
      django_urls_list.each do |django_urls|
        # TODO: Check support method in view files
        result.concat(get_endpoints(django_urls))
      end
    end

    # Static files
    Dir.glob("#{@base_path}/static/**/*") do |file|
      next if File.directory?(file)
      relative_path = file.sub("#{@base_path}/static/", "")
      @result << Endpoint.new("#{@url}/#{relative_path}", "GET")
    end
    
    result
  end

  def search_root_django_urls_list() : Array(DjangoUrls)
    root_django_urls_list = [] of DjangoUrls
    Dir.glob("#{base_path}/**/*") do |file|
      spawn do
        next if File.directory?(file)
        if file.ends_with? ".py"
          content = File.read(file)
          content.scan(/\s*ROOT_URLCONF\s*=\s*['"]([^'"\\]*)['"]/) do |match|
            next if match.size != 2
            filepath = "#{base_path}/#{match[1].gsub(".", "/")}.py"
            if File.exists? filepath
              root_django_urls_list << DjangoUrls.new("", filepath)
            end
          end
        end
      end
      Fiber.yield
    end
    
    root_django_urls_list.uniq
  end

  def search_django_urls_list(django_urls : DjangoUrls) : Array(DjangoUrls)
    django_urls_list = [django_urls] of DjangoUrls

    content = File.read(django_urls.filepath)
    content.scan(/urlpatterns\s*=\s*\[(.*)\]/m) do |match|
      next if match.size != 2
      match[1].scan(/[url|path]\s*\(\s*r?['"]([^'"\\]*)['"]\s*,\s*(.*)\s*\)/) do |url_match|          
        next if url_match.size != 3
        url = url_match[1]
        controller = url_match[2]

        filepath = nil
        controller.scan(/include\s*\(\s*['"]([^'"\\]*)['"]/) do |include_pattern_match|
          next if include_pattern_match.size != 2
          filepath = "#{base_path}/#{include_pattern_match[1].gsub(".", "/")}.py"
          
          if File.exists?(filepath)
            #django_urls = DjangoUrls.new("#{django_urls.prefix}/#{url}".gsub("//","/"), filepath)
            new_django_urls = DjangoUrls.new("#{django_urls.prefix}#{url}", filepath)
            internal_django_urls_list = search_django_urls_list(new_django_urls)
            django_urls_list.concat(internal_django_urls_list)
          end
        end
      end
    end

    django_urls_list
  end

  def get_endpoints(django_urls : DjangoUrls) : Array(Endpoint)
    endpoints = [] of Endpoint    
    content = File.read(django_urls.filepath)    
    content.scan(/urlpatterns\s*=\s*\[(.*)\]/m) do |match|
      next if match.size != 2
      match[1].scan(/[url|path]\s*\(\s*r?['"]([^'"\\]*)['"]\s*,\s*(.*)\s*\)/) do |url_match|          
        next if url_match.size != 3
        url = url_match[1]
        endpoints << Endpoint.new("#{django_urls.prefix}#{url}", "GET")
      end
    end
    
    endpoints
  end

  # Currently unused
  def search_view_files(django_urls : DjangoUrls) : Array(DjangoView)
    view_files = [] of DjangoView
    import_packges = {} of String => String
    content = File.read(django_urls.filepath)    

    content.each_line do |line|
      if line.starts_with? "from"
        line.scan(/from\s*([^'"\s\\]*)\s*import\s*([^'"\s\\]*)/) do |match|
          next if match.size != 3
          import_packges[match[2]] = match[1]
        end      
      elsif line.starts_with? "import"
        line.scan(/import\s*([^'"\s\\]*)/) do |match|
          next if match.size != 2
          import_packges[match[1]] = match[0]
        end
      end
    end

    url_base_path = File.dirname(django_urls.filepath)
    content.scan(/urlpatterns\s*=\s*\[(.*)\]/m) do |match|
      next if match.size != 2
      match[1].scan(/[url|path]\s*\(\s*r?['"]([^'"\\]*)['"]\s*,\s*(.*)\s*\)/) do |url_match|          
        next if url_match.size != 3
        url = url_match[1]
        controller = url_match[2].split(",")[0]

        # TODO: check if controller is a function or a class
        next if controller.includes? "("        

        if controller.count(".") == 1
          class_name, method_name = controller.split(".")
          from = url_base_path
          if import_packges.has_key? class_name
            from = import_packges[class_name]
            if from.starts_with? "."
              from = "#{url_base_path}#{from.gsub(".", "/")}"
            end
            # TODO: search in other case
          end

          next if from == nil
          filepath = from + class_name + ".py"     
          if File.exists?(filepath)
            view_files << DjangoView.new("#{django_urls.prefix}#{url}", filepath, method_name)
          end     
        end          
      end
    end

    view_files
  end
  
  def mapping_to_path(content : String)
    paths = Array(String).new
    if content.includes?("re_path(r")
      content.strip.split("re_path(r").each do |path|
        if path.includes?(",")
          path = path.split(",")[0]
          path = path.gsub(/['"]/, "")
          path = path.gsub(/ /, "")
          path = path.gsub(/\^/, "")
          paths.push("/#{path}")
        end
      end
    elsif content.includes?("path(")
      content.strip.split("path(").each do |path|
        if path.includes?(",")
          path = path.split(",")[0]
          path = path.gsub(/['"]/, "")
          path = path.gsub(/ /, "")
          paths.push("/#{path}")
        end
      end
    elsif content.includes?("register(r")
      content.strip.split("register(r").each do |path|
        if path.includes?(",")
          path = path.split(",")[0]
          path = path.gsub(/['"]/, "")
          path = path.gsub(/ /, "")
          paths.push("/#{path}")
        end
      end
    end

    paths
  end
end

def analyzer_django(options : Hash(Symbol, String))
  instance = AnalyzerDjango.new(options)
  instance.analyze
end

struct DjangoUrls
  include JSON::Serializable
  property prefix, filepath

  def initialize(@prefix : String, @filepath : String)
  end
end

struct DjangoView
  include JSON::Serializable
  property prefix, filepath, name

  def initialize(@prefix : String, @filepath : String, @name : String)
  end
end