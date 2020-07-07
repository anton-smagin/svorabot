class CartCompletedMailer < ApplicationMailer
  EMAILS_TO = ENV['ORDERS_MAILS'].split(',').freeze
  MERCH_EMAILS_TO = ENV['MERCH_MAILS'].split(',').freeze

  def cart_completed
    @cart = params[:cart]
    mail(to: EMAILS_TO, subject: t('mails.cart_completed'))
  end

  def cart_with_merch_completed
    @cart = params[:cart]
    mail(to: MERCH_EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
