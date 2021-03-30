# frozen_string_literal: true

class Cart < ApplicationRecord # :nodoc:
  acts_as_paranoid

  belongs_to :user
  scope :completed, -> { where(completed: true) }

  TICKET_OPTIONS = {
    # 'ticket' => 3000
  }.freeze

  TRANSFER_MOSCOW_OPTIONS = {
    'transfer_from_moscow_29_07_02_08' => 3200
  }.freeze

  TRANSFER_GALICH_OPTIONS = {
    'transfer_from_galich_30_07_02_08' => 700,
    'transfer_from_galich_31_07_02_08' => 700
  }.freeze

  FOOD_OPTIONS = {
    # 'food_30_07' => 500,
    # 'food_31_07' => 500,
    # 'food_01_08' => 500,
    # 'food_02_08' => 500
  }.freeze

  MERCH_OPTIONS = {
    'tshirt' => 1800,
    'flask' => 500
  }.freeze

  EXCURSION_OPTIONS = {
    'bath' => 6000,
    'pogorelovo' => 1000
  }.freeze

  ALL_OPTIONS = TICKET_OPTIONS.merge(
    TRANSFER_MOSCOW_OPTIONS,
    TRANSFER_GALICH_OPTIONS,
    FOOD_OPTIONS,
    MERCH_OPTIONS,
    EXCURSION_OPTIONS
  )

  ITEMS = {
    ticket: TICKET_OPTIONS.keys,
    transfer_moscow: TRANSFER_MOSCOW_OPTIONS.keys,
    transfer_galich: TRANSFER_GALICH_OPTIONS.keys,
    excursion: EXCURSION_OPTIONS.keys,
    merch: MERCH_OPTIONS.keys,
    food: FOOD_OPTIONS.keys
  }.freeze

  ADDABLE_ITEMS = ITEMS.values.flatten.freeze

  def self.category_by(item)
    ITEMS.find { |_, items| items.include?(item) }.first
  end

  def self.price_by(item)
    ALL_OPTIONS[item]
  end

  def total
    items.sum { |item, info| self.class.price_by(item) * info['count'] }
  end

  def party_total
    party_items.sum { |item, info| self.class.price_by(item) * info['count'] }
  end

  def merch_total
    merch_items.sum { |item, info| self.class.price_by(item) * info['count'] }
  end

  def merch_items
    items.slice(*MERCH_OPTIONS.keys)
  end

  def party_items
    items.slice(*(ALL_OPTIONS.keys - MERCH_OPTIONS.keys))
  end

  def complete!
    items.each { |item, info| info['price'] = self.class.price_by(item) }
    self.completed = true
    save
    CartCompletedMailer.with(cart: self).cart_completed.deliver_now
    if merch_items.present?
      CartCompletedMailer.with(cart: self).cart_with_merch_completed.deliver_now
    end
  end

  def clear!
    self.items = {}
    save
  end

  def empty?
    items.sum { |_item, info| info['count'] }.zero?
  end
end
