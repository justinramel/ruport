# report/table.rb : Tabular data report for Ruby Reports
#
# Written by Gregory Brown, December 2006.  Copyright 2006, All Rights Reserved
# This is Free Software, please see LICENSE and COPYING for details.

module Ruport

  # This class implements the basic report for table rows.
  #
  # == Supported Formats 
  #  
  # * Format::CSV
  # * Format::Text
  # * Format::HTML
  #
  # == Format hooks called (in order)
  #  
  # * build_row
  #
  class Report::Row < Report
    stage :row
  end

  # This class implements the basic tabular data report for Ruport.
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
  # * prepare_table
  # * build_table_header
  # * build_table_body
  # * build_table_footer
  # * finalize_table
  #
  class Report::Table < Report
    options { |o| o.show_table_headers = true }

    prepare :table
    
    stage :table_header, :table_body, :table_footer

    finalize :table
  end
end
