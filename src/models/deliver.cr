require "./logger"

class Deliver
  @logger : NoirLogger
  @options : Hash(Symbol, String)
  @is_debug : Bool
  @is_color : Bool
  @is_log : Bool
  @proxy : String
  @headers : Hash(String, String) = {} of String => String
  @matchers : Array(String) = [] of String
  @filters : Array(String) = [] of String

  def initialize(options : Hash(Symbol, String))
    @options = options
    @is_debug = str_to_bool(options[:debug])
    @is_color = str_to_bool(options[:color])
    @is_log = str_to_bool(options[:nolog])
    @proxy = options[:send_proxy]
    @logger = NoirLogger.new @is_debug, @is_color, @is_log

    if options[:send_with_headers] != ""
      headers_tmp = options[:send_with_headers].split("::NOIR::HEADERS::SPLIT::")
      @logger.system "Setting headers from command line."
      headers_tmp.each do |header|
        if header.includes? ":"
          @logger.debug "Adding '#{header}' to headers."
          splited = header.split(":")
          @headers[splited[0]] = splited[1].gsub(/\s/, "")
        end
      end
      @logger.info_sub "#{@headers.size} headers added."
    end

    @matchers = options[:use_matchers].split("::NOIR::MATCHER::SPLIT::")
    @matchers.delete("")
    if @matchers.size > 0
      @logger.system "#{@matchers.size} matchers added."
    end

    @filters = options[:use_filters].split("::NOIR::FILTER::SPLIT::")
    @filters.delete("")
    if @filters.size > 0
      @logger.system "#{@filters.size} filters added."
    end
  end

  def apply_all(endpoints : Array(Endpoint))
    result = endpoints
    @logger.debug "Matchers: #{@matchers}"
    @logger.debug "Filters: #{@filters}"

    if @matchers.size > 0
      @logger.system "Applying matchers"
      result = apply_matchers(endpoints)
    end

    if @filters.size > 0
      @logger.system "Applying filters"
      result = apply_filters(endpoints)
    end

    result
  end

  def apply_matchers(endpoints : Array(Endpoint))
    result = [] of Endpoint
    endpoints.each do |endpoint|
      @matchers.each do |matcher|
        if endpoint.url.includes? matcher
          @logger.debug "Endpoint '#{endpoint.url}' matched with '#{matcher}'."
          result << endpoint
        end
      end
    end

    result
  end

  def apply_filters(endpoints : Array(Endpoint))
    result = [] of Endpoint
    endpoints.each do |endpoint|
      @filters.each do |filter|
        if endpoint.url.includes? filter
          @logger.debug "Endpoint '#{endpoint.url}' filtered with '#{filter}'."
        else
          result << endpoint
        end
      end
    end

    result
  end

  def proxy
    @proxy
  end

  def headers
    @headers
  end

  def matchers
    @matchers
  end

  def filters
    @filters
  end

  def run
    # After inheriting the class, write an action code here.
  end
end
