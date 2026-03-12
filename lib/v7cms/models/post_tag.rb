module V7CMS
  class PostTag < ActiveRecord::Base
    belongs_to :post, class_name: 'V7CMS::Post'
    belongs_to :tag, class_name: 'V7CMS::Tag'

    validates :post_id, presence: true
    validates :tag_id, presence: true, uniqueness: { scope: :post_id }
  end
end
