# frozen_string_literal: true

class TicketRequest < ApplicationRecord # :nodoc:
  belongs_to :user

  def self.save_request!(user)
    create(user_id: user.id)
    TicketRequestMailer.with(user: user).completed.deliver_now
  end
end
