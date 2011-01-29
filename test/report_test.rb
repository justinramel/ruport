#!/usr/bin/env ruby -w   
require File.join(File.expand_path(File.dirname(__FILE__)), "helpers")

###########################################################################
#
#  NOTE:
#
#  As it stands, we haven't found a more clever way to test the formatting
#  system than to just create a bunch of renderers and basic formats for
#  different concepts we're trying to test.  Patches and ideas welcome:
#
#  list.rubyreports.org
############################################################################

#============================================================================
# These two renderers represent the two styles that can be used when defining
# renderers in Ruport.  The OldSchoolReport approach has largely been
# deprecated, but still has uses in edge cases that we need to support.
#============================================================================

class OldSchoolReport < Ruport::Report

  def run
    format do
      build_header
      build_body
      build_footer
    end
  end

end               

class VanillaReport < Ruport::Report
  stage :header,:body,:footer
end


# This format implements some junk output so we can be sure
# that the hooks are being set up right.  Perhaps these could
# be replaced by mock objects in the future.
class DummyText < Ruport::Format
  
  renders :text, :for => OldSchoolReport
  
  def prepare_document
    output << "p"
  end

  def build_header
    output << "header\n"
  end

  def build_body
    output << "body\n"
  end

  def build_footer
    output << "footer\n"
  end

  def finalize_document
    output << "f"
  end
end   

# This format modifies the (String) data object passed to it
class Destructive < Ruport::Format

  def prepare_document; end

  def build_header; end

  def build_body
    output << "You sent #{data}"
    data.replace("RUBBISH")
  end

  def build_footer; end

  def finalize_document; end
end


class VanillaBinary < Ruport::Format
  renders :bin, :for => VanillaReport
  save_as_binary_file
end 

class SpecialFinalize < Ruport::Format
  renders :with_finalize, :for => VanillaReport
  
  def finalize
    output << "I has been finalized"
  end
end

class TestReport < Test::Unit::TestCase

  def teardown
    Ruport::Format::Template.instance_variable_set(:@templates, nil)
  end

  def test_trivial
    actual = OldSchoolReport.render(:text)
    assert_equal "header\nbody\nfooter\n", actual
  end          
  
  context "when running a format with custom a finalize method" do
    def specify_finalize_method_should_be_called
      assert_equal "I has been finalized", 
                   VanillaReport.render_with_finalize
    end                
  end
  
  context "when using templates" do
    def specify_apply_template_should_be_called
      Ruport::Format::Template.create(:stub)
      Table(%w[a b c]).to_csv(:template => :stub) do |r| 
       r.format.expects(:apply_template)
      end  
    end 

    def specify_undefined_template_should_throw_sensible_error
      assert_raises(Ruport::Format::TemplateNotDefined) do
        Table(%w[a b c]).to_csv(:template => :sub)
      end 
    end
  end

  context "when using default templates" do
    def specify_default_template_should_be_called
      Ruport::Format::Template.create(:default)
      Table(%w[a b c]).to_csv do |r| 
        r.format.expects(:apply_template)
        assert r.format.template == Ruport::Format::Template[:default]
      end  
    end

    def specify_specific_should_override_default
      Ruport::Format::Template.create(:default)
      Ruport::Format::Template.create(:stub)
      Table(%w[a b c]).to_csv(:template => :stub) do |r| 
        r.format.expects(:apply_template)
        assert r.format.template == Ruport::Format::Template[:stub]
      end  
    end

    def specify_should_be_able_to_disable_templates
      Ruport::Format::Template.create(:default)
      Table(%w[a b c]).to_csv(:template => false) do |r| 
        r.format.expects(:apply_template).never
      end  
    end
  end

  def test_using_io
    require "stringio"
    out = StringIO.new
    a = OldSchoolReport.render(:text) { |r| r.io = out }
    out.rewind
    assert_equal "header\nbody\nfooter\n", out.read
    assert_equal "", out.read
  end

  def test_using_file
    f = []
    File.expects(:open).yields(f)
    a = OldSchoolReport.render(:text, :file => "foo.text")
    assert_equal "header\nbody\nfooter\n", f[0]
    
    f = []
    File.expects(:open).with("blah","wb").yields(f)
    VanillaReport.render(:bin, :file => "blah")
  end       
  
  def test_using_file_via_rendering_tools     
    f = []
    File.expects(:open).yields(f)  
    Table(%w[a b c], :data => [[1,2,3],[4,5,6]]).save_as("foo.csv")      
    assert_equal "a,b,c\n1,2,3\n4,5,6\n", f[0]  
  end
    

  def test_formats
    assert_equal( {}, Ruport::Report.formats )
    assert_equal( { :text => DummyText },OldSchoolReport.formats )
  end

  def test_method_missing
    actual = OldSchoolReport.render_text
    assert_equal "header\nbody\nfooter\n", actual
  end

  def test_format
    # normal instance mode
    rend = OldSchoolReport.new
    rend.send(:use_format,:text)

    assert_kind_of Ruport::Format, rend.format
    assert_kind_of DummyText, rend.format

    # render mode
    OldSchoolReport.render_text do |r|
      assert_kind_of Ruport::Format, r.format
      assert_kind_of DummyText, r.format
    end

    assert_equal "body\n", rend.format { build_body }.output

    rend.format.clear_output
    assert_equal "", rend.format.output
  end  
  
  def test_options_act_like_indifferent_hash
     opts = Ruport::Report::Options.new
     opts.foo = "bar"
     assert_equal "bar", opts[:foo]
     assert_equal "bar", opts["foo"]    
     
     opts["f"] = "bar"
     assert_equal "bar", opts[:f]
     assert_equal "bar", opts.f
     assert_equal "bar", opts["f"]
     
     opts[:apple] = "banana"
     assert_equal "banana", opts.apple
     assert_equal "banana", opts["apple"]
     assert_equal "banana", opts[:apple]
  end     
  
end


class TestFormatUsingBuild < Test::Unit::TestCase
  # This format uses the build syntax
  class UsesBuild < Ruport::Format
     renders :text_using_build, :for => VanillaReport
     
     build :header do
       output << "header\n"
     end

     build :body do
       output << "body\n"
     end

     build :footer do
       output << "footer\n"
     end     
  end

  def test_should_render_using_build_syntax
    assert_equal "header\nbody\nfooter\n",
      VanillaReport.render_text_using_build
    VanillaReport.render_text_using_build do |rend|
      assert rend.format.respond_to?(:build_header)
      assert rend.format.respond_to?(:build_body)
      assert rend.format.respond_to?(:build_footer)
    end
  end
end


class TestFormatWithLayout < Test::Unit::TestCase
  # This format is meant to check out a special case in Ruport's renderer,
  # in which a layout method is called and yielded to when defined
  class WithLayout < DummyText
     renders :text_with_layout, :for => VanillaReport
     
     def layout     
       output << "---\n"
       yield
       output << "---\n"
     end
     
  end

  def test_layout
     assert_equal "---\nheader\nbody\nfooter\n---\n", 
                  VanillaReport.render_text_with_layout
  end
  
  def test_layout_disabled
     assert_equal "header\nbody\nfooter\n",
                  VanillaReport.render_text_with_layout(:layout => false)
  end

end


class TestReportWithManyHooks < Test::Unit::TestCase
  # This provides a way to check several hooks that report supports
  class ReportWithManyHooks < Ruport::Report
    add_format DummyText, :text
    add_format Destructive, :destructive

    prepare :document

    stage :header
    stage :body
    stage :footer

    finalize :document

    def setup
      options.apple = true
    end

  end

  def test_hash_options_setters
    a = ReportWithManyHooks.render(:text, :subtitle => "foo",
                                       :subsubtitle => "bar") { |r|
      assert_equal "foo", r.options.subtitle
      assert_equal "bar", r.options.subsubtitle
    }
  end

  def test_data_accessors
   a = ReportWithManyHooks.render(:text, :data => [1,2,4]) { |r|
     assert_equal [1,2,4], r.data
   }
  
   b = ReportWithManyHooks.render_text(%w[a b c]) { |r|
     assert_equal %w[a b c], r.data
   }
  
   c = ReportWithManyHooks.render_text(%w[a b f],:snapper => :red) { |r|
     assert_equal %w[a b f], r.data
     assert_equal :red, r.options.snapper
   }
  end

  def test_format_data_dup
    source = "some text"
    result = ReportWithManyHooks.render(:destructive, :data => source)
    assert_equal("You sent some text", result)
    assert_equal("some text", source)
  end

  def test_stage_helper
    assert ReportWithManyHooks.stages.include?('body')
  end
 
  def test_finalize_helper
    assert_equal :document, ReportWithManyHooks.final_stage
  end

  def test_prepare_helper
   assert_equal :document, ReportWithManyHooks.first_stage
  end

  def test_finalize_again
   assert_raise(Ruport::Report::StageAlreadyDefinedError) {
     ReportWithManyHooks.finalize :report
   }
  end

  def test_prepare_again
   assert_raise(Ruport::Report::StageAlreadyDefinedError) {
     ReportWithManyHooks.prepare :foo
   }
  end

  def test_renderer_using_helpers
   actual = ReportWithManyHooks.render(:text)
   assert_equal "pheader\nbody\nfooter\nf", actual

   actual = ReportWithManyHooks.render_text
   assert_equal "pheader\nbody\nfooter\nf", actual
  end

  def test_required_option_helper
   a = ReportWithManyHooks.dup
   a.required_option :title

   a.render_text do |r|
     r.title = "Test Report"
     assert_equal "Test Report", r.options.title
   end

  end

  def test_without_required_option
   a = ReportWithManyHooks.dup
   a.required_option :title

   assert_raise(Ruport::Report::RequiredOptionNotSet) { a.render(:text) }
  end
 
end


class TestReportWithRunHook < Test::Unit::TestCase

  class ReportWithRunHook < Ruport::Report
    add_format DummyText, :text

    required_option :foo,:bar
    stage :header
    stage :body
    stage :footer

    def run
      format.output << "|"
      super
    end

  end

  def test_renderer_with_run_hooks
    assert_equal "|header\nbody\nfooter\n", 
       ReportWithRunHook.render_text(:foo => "bar",:bar => "baz")
  end

end


class TestWithHelperModule < Test::Unit::TestCase

  class ReportWithHelperModule < VanillaReport

    add_format DummyText, :stub

    module Helpers
      def say_hello
        "Hello Dolly"
      end
    end
  end   

  def test_renderer_helper_module
    ReportWithHelperModule.render_stub do |r|
      assert_equal "Hello Dolly", r.format.say_hello
    end
  end
end


class TestMultiPurposeFormat < Test::Unit::TestCase
  # This provides a way to check the multi-format hooks for the Report
  class MultiPurposeFormat < Ruport::Format

     renders [:html,:text], :for => VanillaReport

     def build_header
       a = 10

       text { output << "Foo: #{a}\n" }
       html { output << "<b>Foo: #{a}</b>\n" } 
     end

     def build_body
       html { output << "<pre>\n" }
       output << options.body_text
       html { output << "\n</pre>\n" }
     end

  end   

  def test_multi_purpose
    text = VanillaReport.render_text(:body_text => "foo")
    assert_equal "Foo: 10\nfoo", text
    html = VanillaReport.render_html(:body_text => "bar")
    assert_equal "<b>Foo: 10</b>\n<pre>\nbar\n</pre>\n",html
  end


  def test_method_missing_hack_format
    assert_equal [:html,:text], MultiPurposeFormat.formats

    a = MultiPurposeFormat.new
    a.format = :html
    
    visited = false
    a.html { visited = true }

    assert visited
    
    visited = false
    a.text { visited = true }
    assert !visited

    assert_raises(NoMethodError) do
      a.pdf { 'do nothing' }
    end
  end

end


class TestFormatErbHelper < Test::Unit::TestCase
  class ErbFormat < Ruport::Format
     
    renders :terb, :for  => VanillaReport
    
    def build_body    
       # demonstrate local binding
       @foo = "bar"                         
       if options.binding
         output << erb("Binding Override: <%= reverse %>", 
                       :binding => options.binding) 
       else   
         output << erb("Default Binding: <%= @foo %>") 
       end   
    end
    
  end

   #FIXME: need to test file

   def test_self_bound
     assert_equal "Default Binding: bar", VanillaReport.render_terb
   end
   
   def test_custom_bound
     a = [1,2,3]
     arr_binding = a.instance_eval { binding }
     assert_equal "Binding Override: 321", 
                   VanillaReport.render_terb(:binding => arr_binding)
   end
end    


class TestOptionReaders < Test::Unit::TestCase
  
  class ReportForCheckingOptionReaders < Ruport::Report
    required_option :foo  
  end 
  
  class ReportForCheckingPassivity < Ruport::Report
    def foo
      "apples"
    end
    required_option :foo    
  end

   def setup 
     @renderer = ReportForCheckingOptionReaders.new
     @renderer.format = Ruport::Format.new
     
     @passive = ReportForCheckingPassivity.new
     @passive.format = Ruport::Format.new
   end
   
   def test_options_are_readable
      @renderer.foo = 5
      assert_equal 5, @renderer.foo
   end                                   
   
   def test_methods_are_not_overridden
     @passive.foo = 5
     assert_equal "apples", @passive.foo
     assert_equal 5, @passive.options.foo
     assert_equal 5, @passive.format.options.foo
   end
     
end
     
class TestSetupOrdering < Test::Unit::TestCase
   
  class ReportWithSetup < Ruport::Report
    stage :bar
    def setup
      options.foo.capitalize!
    end        
  end           
  
  class BasicFormat < Ruport::Format
    renders :text, :for => ReportWithSetup
    
    def build_bar
      output << options.foo
    end
  end
  
  def test_render_hash_options_should_be_called_before_setup
    assert_equal "Hello", ReportWithSetup.render_text(:foo => "hello")
  end       
  
  def test_render_block_should_be_called_before_setup
    assert_equal "Hello", 
      ReportWithSetup.render_text { |r| r.options.foo = "hello" }
  end
  
end

class CustomFormat < Ruport::Format
  def custom_helper
    output << "Custom!"
  end
end

class ReportWithAnonymousFormats < Ruport::Report

  stage :report

  format :html do
    build :report do
      output << textile("h1. Hi there")
    end
  end

  format :csv do
    build :report do
      build_row([1,2,3])
    end
  end

  format :pdf do
    build :report do 
      add_text "hello world"
    end
  end

  format :text do
    build :report do
      output << "Hello world"
    end
  end

  format :custom => CustomFormat do

    build :report do
      output << "This is "
      custom_helper
    end

  end

end

class TestAnonymousFormat < Test::Unit::TestCase
  context "When using built in Ruport formats" do

    def specify_text_format_shortcut_is_accessible
      assert_equal "Hello world", ReportWithAnonymousFormats.render_text
      assert_equal "1,2,3\n", ReportWithAnonymousFormats.render_csv
      assert_equal "<h1>Hi there</h1>", ReportWithAnonymousFormats.render_html
      assert_not_nil ReportWithAnonymousFormats.render_pdf
    end
    
  end

  context "When using custom formats" do
    def specify_custom_format_shortcut_is_accessible
      assert_equal "This is Custom!", ReportWithAnonymousFormats.render_custom
    end
  end

end

# Used to ensure that problems in report code aren't mistakenly intercepted
# by Ruport.
class MisbehavingReport < Ruport::Report
end

class MisbehavingFormat < Ruport::Format
  renders :text, :for => MisbehavingReport
  def initialize
    super
    raise NoMethodError
  end
end

class TestMisbehavingReport < Test::Unit::TestCase

  context "using a report that throws NoMethodError" do
    def specify_report_errors_should_bubble_up
      assert_raises(NoMethodError) do
        MisbehavingReport.render :text
      end
    end
  end

end

class TestReportHooks < Test::Unit::TestCase

  context "when renderable_data omitted" do

    require "mocha"

    class DummyObject 
      include Ruport::Report::Hooks
      renders_as_table
    end

    def specify_should_return_self
      a = DummyObject.new
      rend = mock("renderer")
      rend.expects(:data=).with(a)
      Ruport::Report::Table.expects(:render).with(:csv,{}).yields(rend)
      a.as(:csv)
    end

  end

  context "when using renderable_data" do

    class DummyObject2
      include Ruport::Report::Hooks
      renders_as_table

      def renderable_data(format)
        1
      end
    end

    def specify_should_return_results_of_renderable_data
      a = DummyObject2.new
      rend = mock("renderer")
      rend.expects(:data=).with(1)
      Ruport::Report::Table.expects(:render).with(:csv,{}).yields(rend)
      a.as(:csv)
    end

    class DummyObject3
      include Ruport::Report::Hooks
      renders_as_table
      
      def renderable_data
        raise ArgumentError
      end
    end

    def specify_should_not_mask_errors
      assert_raises(ArgumentError) { DummyObject3.new.as(:csv) }
    end

    class DummyObject4
      include Ruport::Report::Hooks
      renders_as_table

      def renderable_data(format)
        case format
        when :html
          1
        when :csv
          2
        end
      end
    end

    def specify_should_return_results_of_renderable_data_using_format
      a = DummyObject4.new
      rend = mock("renderer")
      rend.expects(:data=).with(2)
      Ruport::Report::Table.expects(:render).with(:csv,{}).yields(rend)
      a.as(:csv)
    end

  end    

  context "when attempting to render a format that doesn't exist" do

    def specify_an_unknown_format_error_should_be_raised

      assert_raises(Ruport::Report::UnknownFormatError) do
        Ruport::Report.render_foo
      end

    end
  end



end
