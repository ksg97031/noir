require "../detector/detector.cr"
require "../analyzer/analyzer.cr"
require "../deliver/*"
require "../output_builder/*"
require "./endpoint.cr"
require "./logger.cr"
require "json"

class NoirRunner
  @options : Hash(Symbol, String)
  @techs : Array(String)
  @endpoints : Array(Endpoint)
  @logger : NoirLogger
  @scope : String
  @send_proxy : String
  @send_req : String
  @send_es : String
  @is_debug : Bool
  @is_color : Bool
  @is_log : Bool

  macro define_getter_methods(names)
    {% for name, index in names %}
      def {{name.id}}
        @{{name.id}}
      end
    {% end %}
  end

  define_getter_methods [options, techs, endpoints, logger]

  def initialize(options)
    @options = options
    @techs = [] of String
    @endpoints = [] of Endpoint
    @send_proxy = options[:send_proxy]
    @send_req = options[:send_req]
    @send_es = options[:send_es]
    @scope = options[:scope]
    @is_debug = str_to_bool(options[:debug])
    @is_color = str_to_bool(options[:color])
    @is_log = str_to_bool(options[:nolog])

    @logger = NoirLogger.new @is_debug, @is_color, @is_log

    if options[:techs].size > 0
      techs_tmp = options[:techs].split(",")
      @logger.info "Setting #{techs_tmp.size} techs from command line."
      techs_tmp.each do |tech|
        @techs << NoirTechs.similar_to_tech(tech)
        @logger.debug "Added #{tech} to techs."
      end
    end
  end

  def run
    puts @techs
  end

  def detect
    detected_techs = detect_techs options[:base], options, @logger
    @techs += detected_techs
    if @is_debug
      @logger.debug("CodeLocator Table:")
      locator = CodeLocator.instance
      locator.show_table
    end
  end

  def analyze
    @endpoints = analysis_endpoints options, @techs, @logger
    optimize_endpoints
    deliver()
  end

  def optimize_endpoints
    @logger.system "Optimizing endpoints."
    tmp = [] of Endpoint
    duplicate = [] of String

    @endpoints.each do |endpoint|
      tiny_tmp = endpoint
      if endpoint.params.size > 0
        tiny_tmp.params = [] of Param
        endpoint.params.each do |param|
          if !param.name.includes? " "
            if @options[:set_pvalue] != ""
              param.value = @options[:set_pvalue]
            end
            tiny_tmp.params << param
          end
        end
      end

      if endpoint.url != "" && !duplicate.includes?(endpoint.method + endpoint.url)
        tmp << tiny_tmp
        duplicate << endpoint.method + endpoint.url
      end
    end

    @endpoints = tmp
  end

  def deliver
    if @send_proxy != ""
      @logger.system "Sending requests with proxy #{@send_proxy}."
      deliver = SendWithProxy.new(@options)
      deliver.run(@endpoints)
    end

    if @send_req != "no"
      @logger.system "Sending requests without proxy."
      deliver = SendReq.new(@options)
      deliver.run(@endpoints)
    end

    if @send_es != ""
      @logger.system "Sending requests to Elasticsearch."
      deliver = SendElasticSearch.new(@options)
      deliver.run(@endpoints, @send_es)
    end
  end

  def report
    case options[:format]
    when "json"
      puts @endpoints.to_json
    when "yaml"
      puts @endpoints.to_yaml
    when "markdown-table"
      builder = OutputBuilderMarkdownTable.new @options
      builder.print @endpoints
    when "httpie"
      builder = OutputBuilderHttpie.new @options
      builder.print @endpoints
    when "curl"
      builder = OutputBuilderCurl.new @options
      builder.print @endpoints
    when "oas2"
      buidler = OutputBuilderOas2.new @options
      buidler.print @endpoints
    when "oas3"
      buidler = OutputBuilderOas3.new @options
      buidler.print @endpoints
    else
      builder = OutputBuilderCommon.new @options
      builder.print @endpoints
    end
  end
end
