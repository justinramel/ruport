require "ostruct"
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
  end
end
