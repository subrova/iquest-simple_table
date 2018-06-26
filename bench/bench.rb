#!/usr/bin/env ruby
# frozen_string_literal: true

begin
  require 'bundler/inline'
rescue LoadError => e
  $stderr.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bench.rb [options]"

  opts.on("-m", "--[no-]mem", "Memory profile") do |v|
    options[:mem] = v
  end
  opts.on("-b", "--[no-]bench", "Benchmark IPS") do |v|
    options[:bench] = v
  end
  opts.on("-t", "--[no-]time", "Method timing") do |v|
    options[:time] = v
  end
end.parse!

gemfile(true) do
  source 'https://rubygems.org'

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  gem 'rails', '5.2.0'
  gem 'activerecord', '5.2.0'
  gem 'benchmark-ips'
  gem 'kaminari'
  gem 'memory_profiler'
  gem 'ransack', '1.8.8', require: false
  gem 'iquest-simple_table', path: '../', require: false
  gem 'timeasure'
end

require 'rails/all'

class BenchApp < Rails::Application
  config.root = __dir__
  config.session_store :cookie_store, key: 'cookie_store_key'
  secrets.secret_key_base = 'secret_key_base'

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger
end

require 'iquest/simple_table'

class ApplicationController < ActionController::Base
  layout false
  prepend_view_path('templates')
end

class Foo
  include ActiveModel::Model
  ATTRIBUTES = %i(a b c d e f g h).freeze
  attr_accessor *ATTRIBUTES
  delegate :each, :map, to: :attributes

  def attributes
    ATTRIBUTES.map { |a| send(a) }
  end
end

def render(template, **assigns)
  ApplicationController.render(
    template: template.to_s,
    layout: nil,
    locals: assigns
  )
end

def memory_profile(title)
  report = MemoryProfiler.report(top: 10, ingnore_files: /memory_profiler/) do
    yield
  end
  puts '=' * 80
  puts title
  puts '=' * 80
  report.pretty_print
end

today = Date.today
now = Time.now
collection = Array.new(100) { Foo.new(a: 0, b: 1, c: 2, d: 3, e: 4, f: 5, g: today, h: now) }
table = Kaminari.paginate_array(collection).page(1).per(100)

if options[:mem]
  memory_profile 'table' do
    render 'table', table: table
  end

  memory_profile 'simple_table' do
    render 'simple_table', table: table
  end
end

if options[:bench]
  Benchmark.ips do |x|
    x.report('table') { render 'table', table: table }
    x.report('simple_table') { render 'simple_table', table: table }

    x.compare!
  end
end

if options[:time]
  require 'timeasure'

  module Iquest
    module SimpleTable
      class TableBuilder
        include Timeasure
        tracked_instance_methods :to_s
        tracked_private_instance_methods :render_table_row, :attr_class
      end
    end
  end

  require 'pp'

  Timeasure::Profiling::Manager.prepare
  render 'simple_table', table: table
  report = Timeasure::Profiling::Manager.export
  report.each do |item|
    pp item
  end
end
