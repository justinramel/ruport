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
    class RequiredOptionNotSet < RuntimeError #:nodoc:
    end
    class UnknownFormatError < RuntimeError #:nodoc:
    end
    class StageAlreadyDefinedError < RuntimeError #:nodoc:
    end
    class ReportNotSetError < RuntimeError #:nodoc:
    end
  end
end
