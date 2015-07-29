module Iquest
  module SimpleTable
    module AttributeDescription

      def human_attribute_description(attribute, options = {})
        parts     = attribute.to_s.split(".")
        attribute = parts.pop
        namespace = parts.join("/") unless parts.empty?
        attributes_scope = "#{self.i18n_scope}.descriptions"

        if namespace
          defaults = lookup_ancestors.map do |klass|
            :"#{attributes_scope}.#{klass.model_name.i18n_key}/#{namespace}.#{attribute}"
          end
          defaults << :"#{attributes_scope}.#{namespace}.#{attribute}"
        else
          defaults = lookup_ancestors.map do |klass|
            :"#{attributes_scope}.#{klass.model_name.i18n_key}.#{attribute}"
          end
        end

        defaults << options.delete(:default) if options[:default]

        options[:default] = ''
        I18n.translate(defaults.shift, options)
      end

    end
  end
end