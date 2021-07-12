# frozen_string_literal: true

class TicketRequestMailer < ApplicationMailer
  EMAILS_TO = ENV['ORDERS_MAILS'].split(',').freeze

  def completed
    @user = params[:user]
    @ticket_request = params[:ticket_request]
    mail(to: EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
