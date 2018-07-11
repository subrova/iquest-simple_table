require 'ransack_simple_form'

module Iquest
  module SimpleTable
    class TableBuilder
      attr_reader :parent, :table_id, :columns, :collection, :search_form, :actions, :collection_actions
      delegate :capture, :content_tag, :link_to, :paginate, :page_entries_info, :params, to: :parent
      delegate :sort_link, :search_form_for, to: :parent
      delegate :polymorphic_path, :polymorphic_url, to: :parent
      delegate :l, :t, :dom_id, to: :parent
      delegate :render, :render_to_string, to: :parent
      CLASS_DELIMITER = ' '.freeze
      EMPTY_STRING = ''.freeze
      DEFAULT_FORMATTER = ->(value) do
        case value
        when Time
          l(value)
        when Date
          l(value)
        else
          value
        end
      end

      def initialize(parent, collection_or_search, options = {})
        @parent = parent
        if collection_or_search.is_a? Ransack::Search
          @collection = collection_or_search.result
          @search = collection_or_search
          @klass = @search.klass
        elsif collection_or_search.is_a?(ActiveRecord::Relation) || collection_or_search.is_a?(ActiveRecord::AssociationRelation)
          @collection = collection_or_search
          @klass = @collection.klass
        elsif collection_or_search.is_a?(Array) && (search = collection_or_search.detect { |o| o.is_a?(Ransack::Search) })
          @search = search
          @collection = search.result
          @klass = @collection.klass
          options[:search_url] ||= polymorphic_path(collection_or_search.map { |o| o.is_a?(Ransack::Search) ? o.klass : o })
        elsif collection_or_search.is_a?(Array) && (collection = collection_or_search.detect { |o| o.is_a?(ActiveRecord::Relation) || o.is_a?(ActiveRecord::AssociationRelation) })
          @collection = collection
          @klass = @collection.klass
        elsif collection_or_search.is_a?(Array) && (collection_or_search.any? || options[:class])
          @collection = collection_or_search
          @klass = options[:class] || collection_or_search.first.class
        else
          raise TypeError, 'ActiveRecord::Relation, ActiveRecord::AssociationRelation, Ransack::Search or Array of ActiveModel like objects expected'
        end
        apply_pagination
        # draper
        @collection = @collection.decorate if @collection.respond_to?(:decorate)
        options[:search_url] ||= begin
                                   polymorphic_path(@klass)
                                 rescue NoMethodError
                                   nil
                                 end
        @options = options
        @table_id = "table_#{@klass}".pluralize.parameterize
        @columns = {}.with_indifferent_access
        @actions = []
        @collection_actions = []
        @search_input_default_options = { label: false, placeholder: false }.with_indifferent_access
        @attr_classes = {}
      end

      def column(*args, &block)
        attr = args.first
        options = args.extract_options!
        search = options.delete(:search)
        @columns[attr] = options
        @columns[attr][:label] ||= column_label(attr)
        # iniciaizce search options
        if search.is_a?(Symbol) || search.is_a?(String)
          @columns[attr][:search] = { search.to_sym => {} }
        elsif search.is_a? Array
          @columns[attr][:search] = search.each_with_object({}) { |s, h| h[s.to_sym] = {}; }
        elsif search.is_a? Hash
          @columns[attr][:search] = search
        end
        @columns[attr][:formatter] ||= block_given? ? block : DEFAULT_FORMATTER
        @columns[attr][:sort] ||= attr.to_s.tr('.', '_') unless @columns[attr][:sort] == false # sort link attr
        @columns[attr][:html] ||= {}
        @columns[attr][:html][:class] = @columns[attr][:html][:class].join(CLASS_DELIMITER) if @columns[attr][:html][:class].is_a?(Array)
        @columns[attr][:html][:class] ||= ''
      end

      def action(*args, &block)
        _action = args.first
        options = args.extract_options!
        options[:proc] = block if block_given?
        @actions << options
      end

      def collection_action(*args)
        action = args.first
        if action.is_a? String
          @collection_actions << action
        elsif block_given?
          @collection_actions << yield
        end
      end

      def new_link(*_args)
        ActiveSupport::Deprecation.warn("Iquest::SimpleTable#new_link does nothing. Use collection_action")
      end

      def search_link(*_args, &block)
        @search_button = block if block_given?
      end

      def reset_link(*_args, &block)
        @reset_button = block if block_given?
      end

      WRAPPER_TEMPLATE = '<div class="filter-table-block">
      <%= content %>
      <div class"paginate-block"><%= paginate @collection if @collection.respond_to?(:current_page) %></div>
      <div class="totals-block"><%= page_entries_info @collection, entry_name: @klass.model_name.human if @collection.respond_to?(:current_page) %></div>
      </div>'.freeze
      WRAPPER_ERB = ERB.new(WRAPPER_TEMPLATE)

      def to_s
        content = render_table
        WRAPPER_ERB.result(binding).html_safe
      end

      private

      TABLE_TEMPLATE = '
      <% if  @options[:responsive] %><div class="table-responsive"><%end%>
      <table id="<%= @table_id %>" class="<%= @options[:html][:class].join(CLASS_DELIMITER) %> table table-hover table-striped">
      <thead>
      <tr class="labels">
      <th class="collection-actions"><%= @collection_actions.join %></th>
      <% columns.each do |attr, options| %>
        <%= content_tag :th, class: options[:class], data: options[:data] do
          render_label(attr)
        end %>
      <% end %>
      <% if @search %>
        <%= render_search_inputs %>
      <% end %>
      </tr>
      </thead>
      <tbody class="rowlink" data-link="row" data-target="a.rowlink">
      <% collection.each do |item| %>
        <%= render_table_row(item) %>
      <% end %>
      </tbody>
      <tfoot class=""><tr class=""></tr></tfoot>
      </table>
      <% if  @options[:responsive] %></div><%end%>
      '.freeze
      TABLE_ERB = ERB.new(TABLE_TEMPLATE)
      include RansackSimpleForm::FormHelper

      def render_table
        if @search
          ransack_simple_form_for @search, url: @options[:search_url] do |f|
            @search_form = f
            TABLE_ERB.result(binding).html_safe
          end
        else
          TABLE_ERB.result(binding).html_safe
        end
      end

      def render_label(attr)
        options = @columns[attr]
        label = options[:label] || attr.to_s
        sort = options[:sort]
        if @search && sort
          sort_attr = attr
          sort_options = {}
          if sort.is_a?(Hash)
            sort_attr = sort.keys.first
            sort_options = sort[sort_attr]
          elsif sort.is_a?(Symbol) || sort.is_a?(String)
            sort_attr = sort
          end
          sort_options.reverse_merge!(method: search_action)
          sort_link(@search, sort_attr, label, sort_options) << description(attr)
        else
          label << description(attr)
          label.html_safe
        end
      end

      def render_search_inputs
        return EMPTY_STRING unless @search
        content_tag :tr, class: 'filters' do
          rendered_columns = columns.map do |col, opts|
            render_column_search_inputs(col, opts)
          end.join.html_safe
          render_buttons + rendered_columns
        end
      end

      def render_column_search_inputs(_column, options)
        content_tag :th, class: options[:class], data: options[:data] do
          if options[:search]
            options[:search].map do |search, opts|
              render_search_input(search, opts)
            end.join.html_safe
          end
        end
      end

      def render_search_input(search, options = {})
        input_options = @search_input_default_options.merge(options).symbolize_keys
        search_form.input search.dup, input_options
      end

      BUTTONS_TEMPLATE = %q(<th class="search-action"><div class="btn-group">
      <%= link_to(t('simple_table.reset', default: 'reset').html_safe, '?', class: 'search-reset btn btn-default') %>
      <%= search_form.button( :submit, t('simple_table.search', default: 'search').html_safe, class: 'search-button btn btn-default') %>
      </div></th>).freeze # FIXME change link_to url
      BUTTONS_ERB = ERB.new(BUTTONS_TEMPLATE)

      def render_buttons
        BUTTONS_ERB.result(binding).html_safe
      end

      ROWLINK_SKIP = 'rowlink-skip'.freeze
      TR_TEMPLATE = '<tr id="<%= row_id %>"><%= actions %>
      <% columns.each do |attr, options| %>
        <%
        options = columns[attr]
        value = get_value(attr, object)
        html_class = options[:html][:class]
        html_class << " #{ROWLINK_SKIP}" if include_link?(value)
        %>
        <td class="<%= html_class %>"><%= value %></td>
      <% end %>
      </tr>'.freeze
      TR_ERB = ERB.new(TR_TEMPLATE)

      def render_table_row(object)
        row_id = begin
                   "row_#{dom_id(object)}"
                 rescue StandardError
                   nil
                 end
        actions = render_actions(object)
        TR_ERB.result(binding).html_safe
      end

      METHOD_DELIMITER = '.'.freeze

      def get_value(attr, obj)
        value = if attr.is_a? Symbol
                  obj.send(attr) if obj.respond_to?(attr)
                elsif attr.is_a? String
                  attr.split(METHOD_DELIMITER).inject(obj, :try)
                end
        formatter = @columns[attr][:formatter] || DEFAULT_FORMATTER
        case formatter.arity
        when 1
          parent.instance_exec value, &formatter
        when 2
          parent.instance_exec obj, value, &formatter
        else
          parent.instance_exec(&formatter)
        end
      end

      LINK_PATTERN = '<a'.freeze

      def include_link?(string)
        return false unless string.is_a?(String)
        string.include?(LINK_PATTERN)
      end

      ACTIONS_TEMPLATE = '<td class="rowlink-skip">
      <% @actions.each do |action|
        <%= options[:proc].call(obj) if options[:proc].is_a? Proc %>
      </td>'

      def render_actions(item)
        content_tag :td, class: 'rowlink-skip' do
          @actions.map do |action|
            render_action(item, action)
          end.join.html_safe
        end
      end

      def render_action(obj, **options)
        options[:proc].call(obj) if options[:proc].is_a? Proc
      end

      def column_label(attr)
        if attr_class(attr).respond_to?(:human_attribute_name)
          attr_class(attr).try(:human_attribute_name, attr)
        elsif @search
          Ransack::Translate.attribute(attr.to_s.tr(METHOD_DELIMITER, '_'), context: @search.context)
        else
          attr.to_s.humanize
        end
      end

      def description(attr)
        return ''.html_safe unless attr_class(attr).respond_to?(:human_attribute_description)
        description = attr_class(attr).try(:human_attribute_description, attr)
        if description.present?
          "<div class=\"description\">#{description}</div>".html_safe
        else
          ''.html_safe
        end
      end

      def attr_class(attr)
        return @attr_classes[attr] if @attr_classes.key?(attr)
        @attr_classes[attr] ||= attr.to_s.split(METHOD_DELIMITER)[0..-2].inject(@klass) { |klass, assoc| klass.try(:reflect_on_association, assoc).try(:klass) }
      end

      def column_count
        @columns.count
      end

      def apply_pagination
        page = params[:page] || 1
        per_page = params[:per_page]
        @collection = @collection.page(page).per(per_page)
      end

      def search_action
        :get
      end
    end
  end
end
