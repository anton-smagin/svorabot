class TransferRequestMailer < ApplicationMailer
  EMAILS_TO = ENV['ORDERS_MAILS'].split(',').freeze

  def completed
    @user = params[:user]
    @transfer_request = params[:transfer_request]
    mail(to: EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
