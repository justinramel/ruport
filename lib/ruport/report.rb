require 'lib/ruport/report/errors'
require 'lib/ruport/report/options'
require 'lib/ruport/report/hooks'

# report.rb : General purpose control of formatted data for Ruby Reports
#
# Copyright December 2006, Gregory Brown.  All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.


# This class implements the core report for Ruport's formatting system.
# It is designed to implement the low level tools necessary to build
# reports for different kinds of tasks.  See Report::Table for a
# tabular data report.
#
class Ruport::Report
  
  class << self

    # Returns a hash that maps format names to their format classes, for use
    # with the format shortcut.  Supported formats are :html, :csv, :pdf, and
    # :text by default.
    #
    #
    # Sample override:
    #
    #   class MyReport < Ruport::Report
    # 
    #     def built_in_formats
    #       super.extend(:xml => MyXMLFormat,
    #                    :json => MyJSONFormat)
    #     end
    #   end 
    #
    # This would allow for:
    #
    #   class Report < MyReport
    #
    #     format :xml do
    #       # ...
    #     end
    #
    #     format :json do
    #       # ...
    #     end
    #   end
    #     
    def built_in_formats
     { :html => Ruport::Format::HTML,
       :csv  => Ruport::Format::CSV,
       :pdf  => Ruport::Format::PDF,
       :text => Ruport::Format::Text }
    end


    # Generates an anonymous format class and ties it to the Report.
    # This method looks up the built in formats in the hash returned by 
    # built_in_formats, but also explicitly specify a custom Format class to
    # subclass from.
    #
    # Sample usage:
    #
    #   class ReportWithAnonymousFormat < Ruport::Report
    #   
    #     stage :report
    #   
    #     format :html do
    #       build :report do
    #         output << textile("h1. Hi there")
    #       end
    #     end
    #   
    #     format :csv do
    #       build :report do
    #         build_row([1,2,3])
    #       end
    #     end
    #   
    #     format :pdf do
    #       build :report do
    #         add_text "hello world"
    #       end
    #     end
    #   
    #     format :text do
    #       build :report do
    #         output << "Hello world"
    #       end
    #     end
    #   
    #     format :custom => CustomFormat do
    #   
    #       build :report do
    #         output << "This is "
    #         custom_helper
    #       end
    #   
    #     end
    #   
    #   end
    #
    def format(*a,&b)
      case a[0]
      when Symbol
        klass = Class.new(built_in_formats[a[0]])
        klass.renders a[0], :for => self
      when Hash
        k,v = a[0].to_a[0]
        klass = Class.new(v)
        klass.renders k, :for => self
      end
      klass.class_eval(&b)
    end
    
    attr_accessor :first_stage,:final_stage,:required_options,:stages #:nodoc: 
    
    # Registers a hook to look for in the Format object when the render()
    # method is called.                           
    #
    # Usage:
    #
    #   class MyReport < Ruport::Report
    #      # other details omitted...
    #      finalize :apple
    #   end
    #
    #   class MyFormat < Ruport::Format
    #      renders :example, :for => MyReport
    # 
    #      # other details omitted... 
    #    
    #      def finalize_apple
    #         # this method will be called when MyReport tries to render
    #         # the :example format
    #      end
    #   end  
    #
    #  If a format does not implement this hook, it is simply ignored.
    def finalize(stage)
      if final_stage
        raise StageAlreadyDefinedError, 'final stage already defined'      
      end
      self.final_stage = stage
    end
    
    # Registers a hook to look for in the Format object when the render()
    # method is called.                           
    #
    # Usage:
    #
    #   class MyReport < Ruport::Report
    #      # other details omitted...
    #      prepare :apple
    #   end
    #
    #   class MyFormat < Ruport::Format
    #      renders :example, :for => MyReport
    #
    #      def prepare_apple
    #         # this method will be called when MyReport tries to render
    #         # the :example format
    #      end        
    #      
    #      # other details omitted...
    #   end  
    #
    #  If a format does not implement this hook, it is simply ignored.
    def prepare(stage)
      if first_stage
        raise StageAlreadyDefinedError, "prepare stage already defined"      
      end 
      self.first_stage = stage
    end
    
    # Registers hooks to look for in the Format object when the render()
    # method is called.                           
    #
    # Usage:
    #
    #   class MyReport < Ruport::Report
    #      # other details omitted...
    #      stage :apple,:banana
    #   end
    #
    #   class MyFormat < Ruport::Format
    #      renders :example, :for => MyReport
    #
    #      def build_apple
    #         # this method will be called when MyReport tries to render
    #         # the :example format
    #      end 
    #   
    #      def build_banana
    #         # this method will be called when MyReport tries to render
    #         # the :example format
    #      end    
    #      
    #      # other details omitted...
    #   end  
    #
    #  If a format does not implement these hooks, they are simply ignored.
    def stage(*stage_list)
      self.stages ||= []
      stage_list.each { |stage|
        self.stages << stage.to_s 
      }
    end
     
    # Defines attribute writers for the Report::Options object shared
    # between Report and Format. Will throw an error if the user does
    # not provide values for these options upon rendering.
    #
    # usage:
    #   
    #   class MyReport < Ruport::Report
    #      required_option :employee_name, :address
    #      # other details omitted
    #   end
    def required_option(*opts) 
      self.required_options ||= []
      opts.each do |opt|
        self.required_options << opt 

        o = opt
        unless instance_methods(false).include?(o.to_s)
          define_method(o) { options.send(o.to_s) }
        end
        opt = "#{opt}="
        define_method(opt) {|t| options.send(opt, t) }
      end
    end

    # Lists the formats that are currently registered on a report,
    # as a hash keyed by format name.
    #
    # Example:
    # 
    #   >> Ruport::Report::Table.formats
    #   => {:html=>Ruport::Format::HTML,
    #   ?>  :csv=>Ruport::Format::CSV,
    #   ?>  :text=>Ruport::Format::Text,
    #   ?>  :pdf=>Ruport::Format::PDF}
    def formats
      @formats ||= {}
    end

    def known_format?(format)
      formats.include?(format)
    end
    
    # Builds up a report object, looks up the appropriate format,
    # sets the data and options, and then does the following process:
    #
    #   * If the report contains a module Helpers, mix it in to the instance.
    #   * If a block is given, yield the Report instance.
    #   * If a setup() method is defined on the Report, call it.
    #   * Call the run() method.
    #   * If the :file option is set to a file name, appends output to the file.
    #   * Return the results of format.output
    #
    # Please see the examples/ directory for custom report examples, because
    # this is not nearly as complicated as it sounds in most cases.
    def render(format, add_options=nil)
      report = build(format, add_options) { |r|
        yield(r) if block_given?   
        r.setup if r.respond_to? :setup
      }  

      report.run
      report.save_output
      return report.output
    end

    # Allows you to set class-wide default options.
    # 
    # Example:
    #  
    #  options { |o| o.style = :justified }
    #
    def options
      @options ||= Ruport::Report::Options.new
      yield(@options) if block_given?

      return @options
    end

    private
    
    # Creates a new instance of the report and sets it to use the specified
    # format (by name).  If a block is given, the report instance is
    # yielded.  
    #
    # Returns the report instance.
    #
    def build(format, add_options=nil)
      rend = self.new

      rend.send(:use_format, format)
      rend.send(:options=, options.dup)
      if rend.class.const_defined? :Helpers
        rend.format.extend(rend.class.const_get(:Helpers))
      end
      if add_options.kind_of?(Hash)
        d = add_options.delete(:data)
        rend.data = d if d
        add_options.each {|k,v| rend.options.send("#{k}=",v) }
      end

      yield(rend) if block_given?
      return rend
    end
    
    # Allows you to register a format with the report.
    #
    # Example:
    #
    #   class MyFormat < Ruport::Format
    #     # format code ...
    #     SomeReport.add_format self, :my_format
    #   end
    #
    def add_format(format,name=nil)
      formats[name] = format
    end
    
  end
  
  # The name of format being used.
  attr_accessor :format_name
  
  # The format object being used.
  attr_writer :format
  
  # The +data+ that has been passed to the active format.
  def data
    format.data
  end

  # Sets +data+ attribute on the active format.
  def data=(val)
    format.data = val
  end

  # Report::Options object which is shared with the current format.
  def options
    yield(format.options) if block_given?
    format.options
  end
  
  # Call the _run_ method.  You can override this method in your custom
  # report if you need to define other actions.
  def run
    _run_
  end
 
  def save_output
    format.save_output(options.file) if options.file
  end    

  def output
    format.output
  end



  # If an IO object is given, Format#output will use it instead of
  # the default String.  For Ruport's core reports, we technically
  # can use any object that supports the << method, but it's meant
  # for IO objects such as File or STDOUT
  #
  def io=(obj)
    options.io=obj    
  end

  # Returns the active format.
  #
  # If a block is given, it is evaluated in the context of the format.
  def format(&block)
    @format.instance_eval(&block) if block
    return @format
  end

  # Provides a shortcut to render() to allow
  # render(:csv) to become render_csv
  #
  def self.method_missing(id,*args,&block)
    id.to_s =~ /^render_(.*)/
    unless args[0].kind_of? Hash
      args = [ (args[1] || {}).merge(:data => args[0]) ]
    end
    $1 ? render($1.to_sym,*args,&block) : super
  end
  
  private  

  # Called automatically when the report is rendered. Uses the
  # data collected from the earlier methods.
  def _run_
    unless self.class.required_options.nil?
      self.class.required_options.each do |opt|
        if options.__send__(opt).nil?
          raise RequiredOptionNotSet, "Required option #{opt} not set"
        end
      end
    end

    if format.respond_to?(:apply_template) && options.template != false
      format.apply_template if options.template ||
        Ruport::Format::Template.default
    end

    prepare self.class.first_stage if self.class.first_stage
              
    if format.respond_to?(:layout)  && options.layout != false
      format.layout do execute_stages end
    else
      execute_stages
    end

    finalize self.class.final_stage if self.class.final_stage
    maybe :finalize

    return format.output
  end  
  
  def execute_stages
    unless self.class.stages.nil?
      self.class.stages.each do |stage|
        maybe("build_#{stage}")
      end
    end
  end

  def prepare(name)
    maybe "prepare_#{name}"
  end

  def finalize(name)
    maybe "finalize_#{name}"
  end      
  
  def maybe(something)
    format.send something if format.respond_to? something
  end    

  def options=(o)
    format.options = o
  end
  
  # Selects a format for use by format name
  def use_format(format_name)
    raise UnknownFormatError unless self.class.formats.include?(format_name) &&
      self.class.formats[format_name].respond_to?(:new)
    self.format = self.class.formats[format_name].new
    self.format.format = format_name
  end

end

require "ruport/report/table"
require "ruport/report/grouping"
