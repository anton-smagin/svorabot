module Requestable
  extend ActiveSupport::Concern

  included do
    belongs_to :user

    scope :without_rejected, -> { where(approved: [true, nil]) }
  end

  def not_approved?
    approved == false
  end
end
