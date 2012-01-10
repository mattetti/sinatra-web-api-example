# formatting the timestamps for JS
class Time; def to_json(*a); iso8601.to_json(*a); end; end

# Offers a simple way to exclude some attributes
module ActiveRecord
  class Base
    def except(*attrs)
      attributes.except(attrs)
    end
  end
end

# default behavior
ActiveRecord::Base.include_root_in_json = false

# Temporary patch merged in Rails  master
# https://github.com/rails/rails/pull/3106
module ActiveModel
  module Serializers
    module JSON
      def as_json(options = nil)
        opts_root = options[:root] if options.try(:key?, :root)
        if opts_root
          custom_root = opts_root == true ? self.class.model_name.element : opts_root
          { custom_root => serializable_hash(options) }
        elsif opts_root == false
          serializable_hash(options)
        elsif include_root_in_json
          { self.class.model_name.element => serializable_hash(options) }
        else
          serializable_hash(options)
        end
      end
    end
  end
end

