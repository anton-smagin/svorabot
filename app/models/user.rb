# frozen_string_literal: true

class User < ApplicationRecord # :nodoc:
  has_one :ticket_request
  has_one :transfer_request
  has_many :carts

  validates :age, numericality: true, allow_nil: true
  %i[instagram first_name last_name contacts]
    .each { |field| validates_length_of field, in: 2..60, allow_nil: true }

  def contacts_info_filled?
    [instagram, first_name, last_name, age, contacts].all?(&:present?)
  end
end
