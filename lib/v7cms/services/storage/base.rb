# frozen_string_literal: true

module V7CMS
  module Storage
    class Base
      def store(file, key)
        raise NotImplementedError, "#{self.class} must implement #store"
      end

      def retrieve(key)
        raise NotImplementedError, "#{self.class} must implement #retrieve"
      end

      def delete(key)
        raise NotImplementedError, "#{self.class} must implement #delete"
      end

      def url(key)
        raise NotImplementedError, "#{self.class} must implement #url"
      end

      def exists?(key)
        raise NotImplementedError, "#{self.class} must implement #exists?"
      end
    end
  end
end
