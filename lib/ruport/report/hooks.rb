# Ruport : Extensible Reporting System
#
# report/grouping.rb : Group data report for Ruby Reports
#
# Written by Michael Milner, 2007.
# Copyright (C) 2007, All Rights Reserved
#
# This is free software distributed under the same terms as Ruby 1.8
# See LICENSE and COPYING for details.
#
module Ruport
  class Report
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
  end
end
