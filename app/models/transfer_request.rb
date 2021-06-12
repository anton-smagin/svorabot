# frozen_string_literal: true

class TransferRequest < ApplicationRecord # :nodoc:
  include Requestable
  belongs_to :user

  OPTIONS = {
    'transfer_from_moscow_29_07_02_08' => 3200,
    'transfer_from_galich_30_07_02_08' => 700,
    'transfer_from_galich_31_07_02_08' => 700
  }.freeze

  def self.save_request!(user, route)
    create(user_id: user.id, route: route)
    # TransferRequestMailer.with(user: user).completed.deliver_now
  end
end
