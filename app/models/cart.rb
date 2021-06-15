# frozen_string_literal: true

class Cart < ApplicationRecord # :nodoc:
  acts_as_paranoid

  belongs_to :user
  scope :completed, -> { where(completed: true) }

  MERCH_OPTIONS = {
    'tshirt' => 1800,
    'flask' => 500
  }.freeze

  ALL_OPTIONS = {
    **MERCH_OPTIONS
  }

  ITEMS = {
    merch: MERCH_OPTIONS.keys
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
    CartCompletedMailer.with(cart: self).cart_completed.deliver_later
    if merch_items.present?
      CartCompletedMailer.with(cart: self).cart_with_merch_completed.deliver_later
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
