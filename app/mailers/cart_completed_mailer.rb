class CartCompletedMailer < ApplicationMailer
  MERCH_EMAILS_TO = ENV['MERCH_MAILS'].split(',').freeze

  def cart_with_merch_completed
    @cart = params[:cart]
    @user = params[:user]
    mail(to: MERCH_EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
