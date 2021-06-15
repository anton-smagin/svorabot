class TicketRequestMailer < ApplicationMailer
  EMAILS_TO = ENV['ORDERS_MAILS'].split(',').freeze

  def completed
    @user = params[:user]
    mail(to: EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
