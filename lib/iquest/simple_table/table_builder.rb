require 'ransack_simple_form'

module Iquest
  module SimpleTable
    class TableBuilder
      attr_reader :parent, :table_id, :columns, :collection, :search_form, :actions, :new_link
      delegate :capture, :content_tag, :link_to, :paginate, :params, to: :parent
      delegate :sort_link, :search_form_for, to: :parent
      delegate :polymorphic_path, :polymorphic_url, :new_polymorphic_path, :new_polymorphic_url, to: :parent
      delegate :l, :t, to: :parent

      def initialize(parent, collection_or_search, options = {})
        @parent = parent
        if collection_or_search.is_a? Ransack::Search
          @collection = collection_or_search.result
          @search = collection_or_search
          @klass = @search.klass
        elsif collection_or_search.is_a? ActiveRecord::Relation
          @collection = collection_or_search
          @klass = @collection.klass
        else
          raise TypeError, 'ActiveRecord::Relation or Ransack::Search expected'
        end
        apply_pagination
        #draper
        @collection = @collection.decorate if @collection.respond_to?(:decorate)
        @options = options
        @table_id = "table_#{self.object_id}".parameterize
        @columns = {}.with_indifferent_access
        @actions = []
        @search_input_default_options = {label: false, placeholder: false}.with_indifferent_access
      end

      def column(*args, &block)
        attr = args.first
        options = args.extract_options!
        search = options.delete(:search)
        @columns[attr] = options
        if @search
          @columns[attr][:label] ||= Ransack::Translate.attribute(attr.to_s.tr('.','_'), context: @search.context)
        else
          @columns[attr][:label] ||= @klass.human_attribute_name(attr)
        end
        #iniciaizce search options
        if search.is_a?(Symbol) || search.is_a?(String)
          @columns[attr][:search] = {search.to_sym => {}}
        elsif search.is_a? Array
          @columns[attr][:search] = search.inject({}) {|h, s| h[s.to_sym] = {}; h}
        elsif search.is_a? Hash
          @columns[attr][:search] = search
        end
        @columns[attr][:formatter] ||= block if block_given?
      end

      def action(*args, &block)
        action = args.first
        options = args.extract_options!
        options[:proc] = block if block_given?
        @actions << options
      end

      def new_link(*args, &block)
        @new_link = block if block_given?
      end


      def search_link(*args, &block)
        @search_button = block if block_given?
      end

      def reset_link(*args, &block)
        @reset_button = block if block_given?
      end

      def to_s
        if @search
          render_table_with_search
        else
          render_table_without_search
        end
      end

      private
      def render_table_without_search
        table = content_tag :table, class: @options[:html][:class] << %w(table table-hover table-striped) do
          render_table_header + render_table_body + render_table_footer
        end

        if @options[:responsive]
          content_tag :div, class: 'table-responsive' do
            table
          end
        else
          table
        end
      end

      include RansackSimpleForm::FormHelper

      def render_table_with_search
        ransack_simple_form_for @search do |f|
          @search_form = f
          render_table_without_search
        end
      end

      def render_table_header
        content_tag :thead, class: 'header' do
          render_column_labels + render_search_inputs
        end
      end

      def render_column_labels
        content_tag :tr, class:'labels' do
          rendered_columns = columns.map do |col, opts|
            render_column_label(col)
          end.join.html_safe
          render_new_link + rendered_columns
        end
      end

      def render_new_link
        content_tag :th, class:'new-link' do
          @new_link || (link_to t('new'), new_polymorphic_url(@klass), class: "btn btn-primary")
        end
      end

      def render_search_inputs
        content_tag :tr, class:'filters' do
          rendered_columns = columns.map do |col, opts|
            render_column_search_inputs(col, opts)
          end.join.html_safe
          render_buttons + rendered_columns
        end
      end

      def render_column_search_inputs(column, options)
        content_tag :th, class: '' do
          if options[:search]
            options[:search].map do |search, options|
              render_search_input(search, options)
            end.join.html_safe
          end
        end
      end

      def render_search_input(search, options = {})
        input_options = @search_input_default_options.merge(options)
        search_form.input search.dup, input_options
      end

      def render_buttons
        content_tag :th, class:'search-action' do
          out = content_tag :div, class:'btn-group' do
            link_to("<i class=\"fa fa-times\" title=\"#{t('search.reset')}\"></i>".html_safe, '?' , class: 'search-reset btn btn-default') +
            search_form.button( :submit, t('search.search'), class: 'search-button btn btn-default')
          end
          # FIXME change link_to url
        end
      end

      def render_table_body
        content_tag :tbody do
          collection.map do |item|
            render_table_row(item)
          end.join.html_safe
        end
      end

      def render_table_row(item)
        content_tag :tr do
          rendered_columns = columns.map do |col|
            render_value_cell(col, item)
          end.join.html_safe
          render_actions(item) + rendered_columns
        end
      end


      def render_column_label(column)
        options = @columns[:column]

        content_tag :th do
          render_label(column)
        end
      end

      def render_label(column)
        attr = column
        options = @columns[attr]

        label = options[:label] || attr.to_s
        if @search
          sort_link(@search, attr, label, method: search_action)
        else
          label
        end
      end

      def render_value_cell(*args)
        col = args.first
        attr = col.first
        options = col.second
        obj = args.second
        value = get_value(attr, obj)
        formatter = options[:formatter]
        content_tag :td do
          render_value(value, &formatter)
        end
      end

      def get_value(attr, obj)
        if attr.is_a? Symbol
          obj.try(attr)
        elsif attr.is_a? String
          attr.split('.').inject(obj, :try)
        end
      end

      def render_value(*args, &block)
        value = args.first
        if block_given?
          block.call(value)
        else
          format_value(value)
        end

      end

      def format_value(value)
        case value
          when Time
            l(value)
          when Date
            l(value)
          else
            value
        end
      end

      def render_actions(item)
         content_tag :td do
           @actions.map do |action|
             render_action(item, action)
           end.join.html_safe
         end
      end

      def render_action(*args)
        obj = args.first
        options = args.extract_options!
        options[:proc].call(obj) if options[:proc].is_a? Proc
      end

      def render_table_footer
        content_tag :tfoot, class: '' do
          content_tag :tr, class: '' do
            render_pagination + render_footer_actions
          end
        end
      end

      def render_pagination
        content_tag :td, colspan: column_count do
          paginate @collection if @collection.respond_to?(:current_page)
        end

      end

      def render_footer_actions
        content_tag(:td, '', class: '')
      end

      private
      def column_class(col)

      end

      def column_value(col, obj)
        col.to_s.split('.').inject(obj, :try)
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
