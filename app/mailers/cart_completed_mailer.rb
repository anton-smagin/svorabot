class CartCompletedMailer < ApplicationMailer
  EMAILS_TO = ENV['ORDERS_MAILS'].split(',').freeze

  def cart_completed
    @cart = params[:cart]
  end
end
