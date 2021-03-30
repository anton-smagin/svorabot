# frozen_string_literal: true

class User < ApplicationRecord # :nodoc:
  has_one :ticket_request
  has_many :carts

  validates :age, numericality: true, allow_nil: true

  def contact_info_filled?
    [instagram, first_name, last_name, age, contacts].all?(&:present?)
  end
end
