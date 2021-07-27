# frozen_string_literal: true

class TransferRequest < ApplicationRecord # :nodoc:
  include Requestable
  belongs_to :user

  OPTIONS = {
    'transfer_from_galich_29_07' => {
      price: 400,
      count: 36,
      type: :to
    },
    'transfer_from_galich_30_07' => {
      price: 400,
      count: 26,
      type: :to
    },
    'transfer_from_svora_01_08_17_00' => {
      price: 400,
      count: 23,
      type: :return
    },
    'transfer_from_svora_01_08_23_00' => {
      price: 400,
      count: 34,
      type: :return
    },
    'transfer_from_moscow_28_07_01_08' => {
      price: 3500,
      count: 38,
      type: :two_way
    }
  }.each_value(&:freeze).freeze

  def self.left(option)
    OPTIONS.dig(option, :count) -
      TransferRequest
      .where(route_to: option, approved: true)
      .or(TransferRequest.where(route_return: option, approved: true))
      .count
  end

  def self.unavailable?
    OPTIONS.keys.all? { |option| left(option) <= 0 }
  end

  def select_route(route)
    case OPTIONS[route][:type]
    when :two_way
      self.route_to = route == route_to ? nil : route
      self.route_return = route == route_return ? nil : route
    when :to
      self.route_to = route == route_to ? nil : route
      self.route_return = nil if OPTIONS.dig(route_return, :type) == :two_way
    when :return
      self.route_return = route == route_return ? nil : route
      self.route_to = nil if OPTIONS.dig(route_to, :type) == :two_way
    end
  end

  def selected_route?(option = nil)
    if option.nil?
      [route_to, route_return].compact.present?
    else
      route_to == option || route_return == option
    end
  end

  def selected_routes
    [route_to, route_return].compact.uniq
  end

  def approve!
    available =
      selected_routes.all? { |route| TransferRequest.left(route).positive? }
    return false unless available

    self.approved = true
    if changed? && save
      TransferRequestMailer
        .with(user: user, transfer_request: self).completed.deliver_now
    end
    true
  end
end
