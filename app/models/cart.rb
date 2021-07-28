# frozen_string_literal: true

class Cart < ApplicationRecord # :nodoc:
  acts_as_paranoid

  belongs_to :user
  scope :completed, -> { where(completed: true) }

  MERCH_OPTIONS = {}.freeze

  REHAB_OPTIONS = {
    'bath' => 8000,
    'pogorelovo' => 2000
  }.freeze

  ALL_OPTIONS = {
    **MERCH_OPTIONS,
    **REHAB_OPTIONS
  }.freeze

  ITEMS = {
    merch: MERCH_OPTIONS.keys,
    rehab: REHAB_OPTIONS.keys
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

  def rehab_total
    rehab_items.sum { |item, info| self.class.price_by(item) * info['count'] }
  end

  def merch_total
    merch_items.sum { |item, info| self.class.price_by(item) * info['count'] }
  end

  def merch_items
    items.slice(*MERCH_OPTIONS.keys)
  end

  def rehab_items
    items.slice(*REHAB_OPTIONS.keys)
  end

  def complete_merch!
    return false if merch_items.empty?

    self.items = merch_items
    merch_items.each { |item, info| info['price'] = self.class.price_by(item) }
    self.completed = true
    save
    CartCompletedMailer
      .with(cart: self, user: user)
      .cart_with_merch_completed
      .deliver_now
    true
  end

  def complete_rehab!
    return false if rehab_items.empty?

    self.items = rehab_items
    rehab_items.each { |item, info| info['price'] = self.class.price_by(item) }
    self.completed = true
    save
    CartCompletedMailer
      .with(cart: self, user: user)
      .cart_with_rehab_completed
      .deliver_now
    true
  end

  def clear!
    self.items = {}
    save
  end

  def empty?
    items.sum { |_item, info| info['count'] }.zero?
  end
end
