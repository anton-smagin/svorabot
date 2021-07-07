# frozen_string_literal: true

class CartCompletedMailer < ApplicationMailer
  MERCH_EMAILS_TO = ENV['MERCH_MAILS'].split(',').freeze
  REHAB_EMAILS_TO = ENV['REHAB_MAILS'].split(',').freeze

  def cart_with_merch_completed
    @cart = params[:cart]
    @user = params[:user]
    mail(to: MERCH_EMAILS_TO, subject: t('mails.cart_completed'))
  end

  def cart_with_rehab_completed
    @cart = params[:cart]
    @user = params[:user]
    mail(to: REHAB_EMAILS_TO, subject: t('mails.cart_completed'))
  end
end
