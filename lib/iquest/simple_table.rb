require "iquest/simple_table/version"
require "iquest/simple_table/table_builder"
require "iquest/simple_table/table_helper"

module Iquest
  module SimpleTable
    include TableHelper
  end
end

ActionController::Base.helper Iquest::SimpleTable::TableHelper

