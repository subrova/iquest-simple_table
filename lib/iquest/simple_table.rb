require "iquest/simple_table/version"
require "iquest/simple_table/table_builder"
require "iquest/simple_table/table_helper"
require "iquest/simple_table/attribute_description"

module Iquest
  module SimpleTable
    include TableHelper
  end
end

ActionController::Base.helper Iquest::SimpleTable::TableHelper
ActiveRecord::Base.extend Iquest::SimpleTable::AttributeDescription
