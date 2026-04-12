# frozen_string_literal: true

require 'fileutils'

module V7CMS
  module Storage
    class LocalAdapter < Base
      attr_reader :base_path

      def initialize(base_path: nil)
        @base_path = base_path || default_base_path
        FileUtils.mkdir_p(@base_path)
      end

      def store(file, key)
        path = File.join(@base_path, key)
        FileUtils.mkdir_p(File.dirname(path))

        if file.respond_to?(:read)
          File.open(path, 'wb') { |f| f.write(file.read) }
          file.rewind if file.respond_to?(:rewind)
        else
          FileUtils.cp(file, path)
        end

        key
      end

      def retrieve(key)
        path = File.join(@base_path, key)
        return nil unless File.exist?(path)

        File.binread(path)
      end

      def delete(key)
        path = File.join(@base_path, key)
        FileUtils.rm_f(path)

        # Clean up empty directories
        dir = File.dirname(path)
        while dir != @base_path && Dir.exist?(dir) && Dir.empty?(dir)
          Dir.rmdir(dir)
          dir = File.dirname(dir)
        end
      end

      def url(key)
        "/upload/#{key}"
      end

      def exists?(key)
        File.exist?(File.join(@base_path, key))
      end

      def generate_unique_key(original_filename)
        date_path = Time.now.strftime('%Y/%m')
        ext = File.extname(original_filename)
        base = File.basename(original_filename, ext)

        # Sanitize filename
        base = base.downcase.gsub(/[^a-z0-9_-]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
        base = 'file' if base.empty?

        key = "#{date_path}/#{base}#{ext}"
        return key unless exists?(key)

        # Find unique name by appending number
        counter = 1
        loop do
          key = "#{date_path}/#{base}-#{counter}#{ext}"
          return key unless exists?(key)
          counter += 1
        end
      end

      private

      def default_base_path
        if defined?(V7CMS) && V7CMS.respond_to?(:project_root)
          File.join(V7CMS.project_root, 'upload')
        else
          File.join(Dir.pwd, 'upload')
        end
      end
    end
  end
end
