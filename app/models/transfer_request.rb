# frozen_string_literal: true

class TransferRequest < ApplicationRecord # :nodoc:
  include Requestable
  belongs_to :user

  OPTIONS = {
    'transfer_from_moscow_29_07_02_08' => { price: 3200, count: 40 },
    'transfer_from_galich_30_07_02_08' => { price: 700, count: 25 },
    'transfer_from_galich_31_07_02_08' => { price: 700, count: 25 }
  }.each_value(&:freeze).freeze

  def self.left(option)
    OPTIONS.dig(option, :count) -
      TransferRequest.where(route: option, approved: true).count
  end

  def approve!
    update(approved: true)
    TransferRequestMailer
      .with(user: user, transfer_request: self)
      .completed
      .deliver_later
  end
end
