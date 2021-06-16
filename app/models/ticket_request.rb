# frozen_string_literal: true

class TicketRequest < ApplicationRecord # :nodoc:
  include Requestable

  def self.save_request!(user)
    create(user_id: user.id)
    TicketRequestMailer.with(user: user).completed.deliver_now
  end
end
