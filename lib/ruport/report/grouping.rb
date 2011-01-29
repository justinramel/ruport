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
  
  # This class implements the basic report for a single group of data.
  #
  # == Supported Formats
  #
  # * Format::CSV
  # * Format::Text
  # * Format::HTML
  # * Format::PDF
  #
  # == Default layout options 
  #
  # * <tt>show_table_headers</tt> #=> true
  #
  # == Format hooks called (in order)
  #
  # * build_group_header
  # * build_group_body
  # * build_group_footer
  #
  class Report::Group < Report
    options { |o| o.show_table_headers = true }

    stage :group_header, :group_body, :group_footer
  end

  # This class implements the basic report for data groupings in Ruport
  # (a collection of Groups).
  #
  # == Supported Formats
  #
  # * Format::CSV
  # * Format::Text
  # * Format::HTML
  # * Format::PDF
  #
  # == Default layout options 
  #
  # * <tt>show_group_headers</tt> #=> true    
  # * <tt>style</tt> #=> :inline  
  #
  # == Format hooks called (in order)
  #
  # * build_grouping_header
  # * build_grouping_body
  # * build_grouping_footer
  # * finalize_grouping
  #
  class Report::Grouping < Report
    options do |o| 
      o.show_group_headers = true 
      o.style = :inline
    end

    stage :grouping_header, :grouping_body, :grouping_footer
    
    finalize :grouping
  end
  
end
