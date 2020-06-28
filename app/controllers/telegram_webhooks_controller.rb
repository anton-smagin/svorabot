# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  MENU = %i[about ticket transfer food excursion merch cart].map do |category|
    [category, t("telegram_webhooks.#{category}")]
  end.to_h.freeze

  ITEMS_MENU = %i[ticket transfer food excursion merch].freeze

  def start!(value = nil, *_args)
    if value
      send("#{MENU.find { |_k, v| v == value }&.first}!")
    else
      save_context :start!
      respond_with :message, text: t('telegram_webhooks.start'), reply_markup: {
        keyboard: MENU.values.each_slice(2).to_a,
        resize_keyboard: true,
        one_time_keyboard: false,
        selective: true
      }
    end
  end

  def next_step!(value, *)
    respond_with :message, text: value
  end

  def callback_query(data)
    send(data)
  end

  ITEMS_MENU.each do |item|
    define_method("#{item}!") do |*|
      respond_with(
        :message,
        text: t("telegram_webhooks.#{item}"),
        reply_markup: { inline_keyboard: send("#{item}_keyboard") }
      )
    end

    define_method("edit_#{item}!") do |*|
      edit_message(
        :reply_markup,
        reply_markup: { inline_keyboard: send("#{item}_keyboard") }
      )
    end
  end

  def action_missing(_action, *args)
    start!(*args)
  end

  Cart::ADDABLE_ITEMS.each do |item|
    define_method("add_#{item}") do
      cart.items[item] ||= {}
      cart.items[item]['count'] = (cart.items[item]['count'] || 0) + 1
      cart.save
      send("edit_#{Cart.category_by(item)}!")
    end

    define_method("remove_#{item}") do
      cart.items[item] ||= {}
      cart_items = (cart.items[item]['count'] || 0)
      cart.items[item]['count'] = cart_items - 1 if cart_items.positive?
      cart.items[item]['count'] = cart_items - 1 if cart_items.positive?
      cart.items.delete(item) if cart.items[item]['count'].zero?
      send("edit_#{Cart.category_by(item)}!") if cart.changed? && cart.save
    end
  end

  def cart!(*)
    if cart.items.values.sum.zero?
      respond_with(:message, text: t('telegram_webhooks.cart_empty'))
    else
      respond_with(
        :message,
        text: cart_total_text,
        reply_markup: {
          inline_keyboard: [
            [
              {
                text: t('telegram_webhooks.forward_to_pay'),
                callback_data: 'pay!'
              }
            ]
          ]
        }
      )
    end
  end

  def complete!(value = nil, *)
    if value
      cart.update(
        contacts: payload['text'],
        telegram_username: from['username']
      )
      age!
    else
      respond_with :message, text: t('telegram_webhooks.leave_name_and_contact')
    end
  end

  def age!(value = nil, *)
    if value
      cart.user_age = value
      if cart.save
        respond_with :message, text: pay_text
      else
        save_context :age!
        respond_with :message, text: cart.errors.full_messages
      end
    else
      respond_with :message, text: t('telegram_webhooks.leave_name_and_contact')
    end
  end

  def do_nothing
    # do nothing
  end

  def message(message)
    send("#{MENU.find { |_k, v| v == message['text'] }&.first}!")
  end

  private

  def ticket_keyboard
    Cart::TICKET_OPTIONS
      .map { |option, price| build_cart_item(option, price) }
      .flatten(1)
  end

  def transfer_keyboard
    Cart::TRANSFER_OPTIONS
      .map { |option, price| build_cart_item(option, price) }
      .flatten(1)
  end

  def excursion_keyboard
    Cart::EXCURSION_OPTIONS
      .map { |option, price| build_cart_item(option, price) }
      .flatten(1)
  end

  def merch_keyboard
    Cart::MERCH_OPTIONS
      .map { |option, price| build_cart_item(option, price) }
      .flatten(1)
  end

  def food_keyboard
    Cart::FOOD_OPTIONS
      .map { |option, price| build_cart_item(option, price) }
      .flatten(1)
  end

  def cart
    @cart ||= Cart.find_or_create_by(telegram_id: from['id'], completed: false)
  end

  def cart_total_text
    "#{t('telegram_webhooks.cart')} \n" +
      cart.items.map do |item, count|
        t(
          "telegram_webhooks.options.#{item}",
          count: count,
          price: Cart.price_by(item)
        )
      end.join("\n") +
      "\n#{t('telegram_webhooks.cart_total', total: cart.total)}"
  end

  def pay_text
    {
      text: t(
        'telegram_webhooks.your_contact_and_age_is',
        contact: cart.contacts,
        age: cart.user_age
      ),
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: t('telegram_webhooks.change_contact'),
              callback_data: :complete!
            }
          ],
          [{ text: t('telegram_webhooks.pay'), url: 'google.com' }]
        ]
      }
    }
  end

  def build_cart_item(option, price)
    [
      [
        {
          text: t("telegram_webhooks.options.#{option}",
                  price: price,
                  count: cart.items[option] || 0),
          callback_data: 'do_nothing'
        }
      ],
      [
        { text: '➖', callback_data: "remove_#{option}" },
        { text: '➕', callback_data: "add_#{option}" }
      ]
    ]
  end
end
