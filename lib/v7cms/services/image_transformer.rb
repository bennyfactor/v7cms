# frozen_string_literal: true

module V7CMS
  class ImageTransformer
    ALLOWED_PARAMS = %w[w h fit q format].freeze
    ALLOWED_FITS = %w[crop contain cover fill].freeze
    ALLOWED_FORMATS = %w[jpg jpeg png webp gif].freeze

    class << self
      def available?
        return @available if defined?(@available)

        @available = begin
          require 'image_processing/mini_magick'
          MiniMagick.cli_version
          true
        rescue LoadError, MiniMagick::Error, Errno::ENOENT
          false
        end
      end

      def parse_params(params)
        result = {}

        if params['w'].to_s =~ /\A\d+\z/
          result[:width] = params['w'].to_i
        end

        if params['h'].to_s =~ /\A\d+\z/
          result[:height] = params['h'].to_i
        end

        if params['fit'] && ALLOWED_FITS.include?(params['fit'])
          result[:fit] = params['fit']
        end

        if params['q'].to_s =~ /\A\d+\z/
          quality = params['q'].to_i
          result[:quality] = quality if quality.between?(1, 100)
        end

        if params['format'] && ALLOWED_FORMATS.include?(params['format'])
          result[:format] = params['format']
        end

        result
      end

      def cache_key(params)
        return nil if params.empty?

        parts = []
        parts << "w#{params[:width]}" if params[:width]
        parts << "h#{params[:height]}" if params[:height]
        parts << "fit-#{params[:fit]}" if params[:fit]
        parts << "q#{params[:quality]}" if params[:quality]
        parts << "f-#{params[:format]}" if params[:format]

        parts.empty? ? nil : parts.sort.join('_')
      end

      def transform(source_path, params, dest_path)
        return false unless available?
        return false if params.empty?

        require 'image_processing/mini_magick'

        pipeline = ImageProcessing::MiniMagick.source(source_path)

        if params[:width] || params[:height]
          width = params[:width]
          height = params[:height]

          case params[:fit]
          when 'crop'
            pipeline = pipeline.resize_to_fill(width || height, height || width)
          when 'contain'
            pipeline = pipeline.resize_to_fit(width, height)
          when 'cover'
            pipeline = pipeline.resize_to_fill(width || height, height || width)
          else
            pipeline = pipeline.resize_to_limit(width, height)
          end
        end

        if params[:quality]
          pipeline = pipeline.saver(quality: params[:quality])
        end

        FileUtils.mkdir_p(File.dirname(dest_path))

        if params[:format]
          pipeline.convert(params[:format]).call(destination: dest_path)
        else
          pipeline.call(destination: dest_path)
        end

        true
      rescue => e
        warn "ImageTransformer error: #{e.message}"
        false
      end
    end
  end
end
