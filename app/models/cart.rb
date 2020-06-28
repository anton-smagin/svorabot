# frozen_string_literal: true

class Cart < ApplicationRecord # :nodoc:
  acts_as_paranoid

  TICKET_OPTIONS = { 'ticket' => 3000 }.freeze

  TRANSFER_OPTIONS = {
    'transfer_from_galich' => 1250,
    'transfer_from_moscow' => 3000
  }.freeze

  FOOD_OPTIONS = {
    'food_thursday' => 500,
    'food_friday' => 500,
    'food_saturday' => 500,
    'food_sunday' => 500
  }.freeze

  MERCH_OPTIONS = {
    'tshirt' => 800,
    'flask' => 500
  }.freeze

  EXCURSION_OPTIONS = {
    'bath' => 1000,
    'rafting' => 1500
  }.freeze

  ALL_OPTIONS = TICKET_OPTIONS.merge(
    TRANSFER_OPTIONS,
    FOOD_OPTIONS,
    MERCH_OPTIONS,
    EXCURSION_OPTIONS
  )

  ITEMS = {
    ticket: TICKET_OPTIONS.keys,
    transfer: TRANSFER_OPTIONS.keys,
    excursion: EXCURSION_OPTIONS.keys,
    merch: MERCH_OPTIONS.keys,
    food: FOOD_OPTIONS.keys
  }.freeze

  ADDABLE_ITEMS = ITEMS.values.flatten.freeze

  validates :user_age, numericality: true

  def self.category_by(item)
    ITEMS.find { |_, items| items.include?(item) }.first
  end

  def self.price_by(item)
    ALL_OPTIONS[item]
  end

  def total
    items.sum { |item, info| self.class.price_by(item) * info['count'] }
  end

  def complete!
    items.each do |item|
      item['price'] = self.class.price_by[item]
    end
    item.completed = true
    save
    CartCompletedMailer.with(cart: self).cart_completed.deliver_now
  end
end
