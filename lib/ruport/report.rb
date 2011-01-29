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
  
  class RequiredOptionNotSet < RuntimeError #:nodoc:
  end
  class UnknownFormatError < RuntimeError #:nodoc:
  end
  class StageAlreadyDefinedError < RuntimeError #:nodoc: 
  end
  class ReportNotSetError < RuntimeError #:nodoc:
  end
                                          
  require "ostruct"              
  
  # Structure for holding report options.
  # Simplified version of HashWithIndifferentAccess
  class Options < OpenStruct 
           
    if RUBY_VERSION < "1.9"
      private :id   
    end
    
    # Returns a Hash object.  Use this if you need methods other than []
    def to_hash
      @table
    end            
    # Indifferent lookup of an attribute, e.g.
    #
    #  options[:foo] == options["foo"]
    def [](key)
      send(key)
    end 
    
    # Sets an attribute, with indifferent access.
    #  
    #  options[:foo] = "bar"  
    #
    #  options[:foo] == options["foo"] #=> true
    #  options["foo"] == options.foo #=> true
    #  options.foo #=> "bar"
    def []=(key,value)
      send("#{key}=",value)
    end
  end
   
  # This module provides hooks into Ruport's formatting system.
  # It is used to implement the as() method for all of Ruport's data
  # structures, as well as the renders_with and renders_as_* helpers.
  #
  # You can actually use this with any data structure, it will look for a
  # renderable_data(format) method to pass to the <tt>report</tt> you
  # specify, but if that is not defined, it will pass <tt>self</tt>.
  #
  # Examples:
  #
  #   # Render Arrays with Ruport's Row Report
  #   class Array
  #     include Ruport::Report::Hooks
  #     renders_as_row
  #   end
  #
  #   # >> [1,2,3].as(:csv) 
  #   # => "1,2,3\n" 
  #
  #   # Render Hashes with Ruport's Row Report
  #   class Hash
  #      include Ruport::Report::Hooks
  #      renders_as_row
  #      attr_accessor :column_order
  #      def renderable_data(format)
  #        column_order.map { |c| self[c] }
  #      end
  #   end
  #
  #   # >> a = { :a => 1, :b => 2, :c => 3 }
  #   # >> a.column_order = [:b,:a,:c]
  #   # >> a.as(:csv)
  #   # => "2,1,3\n"
  module Hooks 
    module ClassMethods 
      
      # Tells the class which report as() will forward to.
      #
      # Usage:
      #
      #   class MyStructure
      #     include Report::Hooks
      #     renders_with CustomReport
      #   end
      #   
      # You can also specify default rendering options, which will be used
      # if they are not overriden by the options passed to as().
      #
      #   class MyStructure
      #     include Report::Hooks
      #     renders_with CustomReport, :font_size => 14
      #   end
      def renders_with(report,opts={})
        @report = report
        @rendering_options=opts
      end  
      
      # The default rendering options for a class, stored as a hash.
      def rendering_options
        @rendering_options
      end

      def merge(options)
        rendering_options.merge(options)
      end 
       
      # Shortcut for renders_with(Ruport::Report::Table), you
      # may wish to override this if you build a custom table report.
      def renders_as_table(options={})
        renders_with Ruport::Report::Table,options
      end
      
      # Shortcut for renders_with(Ruport::Report::Row), you
      # may wish to override this if you build a custom row report.
      def renders_as_row(options={})
        renders_with Ruport::Report::Row, options
      end
      
      # Shortcut for renders_with(Ruport::Report::Group), you
      # may wish to override this if you build a custom group report.
      def renders_as_group(options={})
        renders_with Ruport::Report::Group,options
      end 
      
      # Shortcut for renders_with(Ruport::Report::Grouping), you
      # may wish to override this if you build a custom grouping report.
      def renders_as_grouping(options={})
        renders_with Ruport::Report::Grouping,options
      end
      
      # The class of the report object for the base class.
      #
      # Example:
      # 
      #   >> Ruport::Data::Table.report
      #   => Ruport::Report::Table
      def report
        @report
      end
    end

    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end      
    
    # Uses the Report specified by renders_with to generate formatted
    # output.  Passes the return value of the <tt>renderable_data(format)</tt>
    # method if the method is defined, otherwise passes <tt>self</tt> as :data
    #
    # The remaining options are converted to a Report::Options object and
    # are accessible in both the report and format.
    #
    #  Example:
    #
    #    table.as(:csv, :show_table_headers => false)
    def as(format,options={}) 
      report = self.class.report

      raise ReportNotSetError unless report
      raise UnknownFormatError unless report.known_format?(format)

      options = self.class.merge(options)

      report.render(format, options) do |rend|
        rend.data =
          respond_to?(:renderable_data) ? renderable_data(format) : self

        yield(rend) if block_given?  
      end
    end      

    def save_as(file,options={})
      file =~ /.*\.(.*)/    
      format = $1
      as(format.to_sym, options.merge(:file => file))        
    end
  end

  
  
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
  attr_accessor :format  
  
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
  def use_format(format)
    raise UnknownFormatError unless self.class.formats.include?(format) &&
      self.class.formats[format].respond_to?(:new)
    self.format = self.class.formats[format].new
    self.format.format = format
  end

end

require "ruport/report/table"
require "ruport/report/grouping"
