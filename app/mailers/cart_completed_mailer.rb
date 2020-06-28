class CartCompletedMailer < ApplicationMailer
  EMAILS_TO = ENV['ORDERS_MAILS'].split(',').freeze

  def cart_completed
    @cart = params[:cart]

    mail(to: EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
