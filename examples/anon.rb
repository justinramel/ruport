# Demonstrates building a parent report which provides additional 'built in'
# formats, allowing anonymous format support to use the simple interface
# rather than the :format => FormatClass approach.

require "ruport"
module FooCorp
  class Report < Ruport::Report
    def self.built_in_formats
      super.merge(:xml => FooCorp::Format::XML)
    end
  end

  class Format
    class XML < Ruport::Format

      def xmlify(stuff)
        output << "Wouldn't you like to see #{stuff} in XML?"
      end
    end
  end

  class MyReport < FooCorp::Report
    stage :foo

    format :xml do
      build :foo do
        xmlify "Red Snapper"
      end
    end

    format :text do
      build :foo do
        output << "Red Snapper"
      end
    end
  end
end

puts "XML:"
puts FooCorp::MyReport.render_xml

puts "Text:"
puts FooCorp::MyReport.render_text
