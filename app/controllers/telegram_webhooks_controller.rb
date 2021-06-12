# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  before_action :user
  around_action :check_ticket_available

  MENU =
    %i[ticket transfer merch]
    .map do |category|
      [category, t("telegram_webhooks.categories.#{category}")]
    end.to_h.freeze

  ITEMS_MENU = {
    'ticket' => ['ticket'],
    'transfer' => %w[transfer],
    'merch' => ['merch']
  }.freeze

  TEST_QUESTIONS =
    t('telegram_webhooks.test').keys.freeze

  TEST_QUESTIONS.each.with_index do |step, index|
    define_method("#{step}!") do |*|
      respond_with(
        :message,
        text: t("telegram_webhooks.test.#{step}.question"),
        reply_markup: { inline_keyboard: test_keyboard(step, index) }
      )
    end
  end

  def start!(_value = nil, *_args)
    respond_with(
      :photo,
      photo: File.open(Rails.root.join('public', 'img', 'afisha.png')),
      reply_markup: default_keyboard
    )

    respond_with(
      :message,
      text: t('telegram_webhooks.description.start'),
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: t('telegram_webhooks.go'),
              callback_data: "#{TEST_QUESTIONS[0]}!"
            }
          ]
        ]
      }
    )
  end

  def about!(*)
    start!
  end

  ITEMS_MENU.each do |item, subitems|
    define_method("#{item}!") do |*|
      if Rails.root.join('public', 'img', item.to_s).exist?
        Dir.foreach(Rails.root.join('public', 'img', item.to_s)) do |filename|
          next unless /png|gif|jpeg|jpg/.match?(filename)

          file =
            File.open(Rails.root.join('public', 'img', item.to_s, filename))

          reply_with :photo, photo: file
        end
      end

      if t("telegram_webhooks.description.#{item}").is_a? String
        respond_item_keyboard(item)
      elsif t("telegram_webhooks.description.#{item}").is_a? Hash
        t("telegram_webhooks.description.#{item}").each do |item2, _text|
          respond_item_keyboard(item, item2)
        end
      end
    end

    subitems.each do |subitem|
      define_method("edit_#{subitem}!") do |*|
        edit_message(
          :reply_markup,
          keyboard: default_keyboard,
          reply_markup: { inline_keyboard: send("#{subitem}_keyboard") }
        )
      end
    end
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
      cart.items.delete(item) if cart.items[item]['count'].zero?
      send("edit_#{Cart.category_by(item)}!") if cart.changed? && cart.save
    end
  end

  TransferRequest::OPTIONS.each_key do |item|
    define_method("add_#{item}") do
      transfer_request = user.transfer_request || TransferRequest.new(user_id: user.id)
      transfer_request.route = transfer_request.route != item ? item : nil
      transfer_request.save
      edit_transfer!
    end
  end

  def action_missing(_action, *args)
    start!(*args)
  end

  def ticket!
    start! # delegate ticket to start to get into test
  end

  def cart!(*)
    return cart_empty if cart.empty?

    respond_with(
      :message,
      text: cart_total_text,
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: t('telegram_webhooks.forward_to_complete'),
              callback_data: 'complete!'
            }
          ],
          [{ text: t('telegram_webhooks.clear'), callback_data: 'clear_cart!' }]
        ]
      }
    )
  end

  def complete!(value = nil, *)
    if value
      user.contacts = payload['text']
      if user.save
        share_instagram!
      else
        save_context :complete!
        respond_with(
          :message, text: user.errors.full_messages_for(:contacts).join(',')
        )
      end
    else
      save_context :complete!
      respond_with :message, text: t('telegram_webhooks.leave_name_and_contact')
    end
  end

  def share_instagram!(value = nil, *)
    if value
      user.instagram = payload['text']
      if user.save
        first_name!
      else
        save_context :share_instagram!
        respond_with(
          :message, text: user.errors.full_messages_for(:instagram).join(',')
        )
      end
    else
      save_context :share_instagram!
      respond_with :message, text: t('telegram_webhooks.leave_instagram')
    end
  end

  def age!(value = nil, *)
    if value
      user.age = value
      if user.save
        respond_with :message, before_complete_text
      else
        save_context :age!
        respond_with(
          :message, text: user.errors.full_messages_for(:age).join(',')
        )
      end
    else
      save_context :age!
      respond_with :message, text: t('telegram_webhooks.leave_age')
    end
  end

  def first_name!(value = nil, *)
    if value
      user.first_name = payload['text']
      if user.save
        last_name!
      else
        save_context :first_name!
        respond_with(
          :message, text: user.errors.full_messages_for(:first_name).join(',')
        )
      end
    else
      save_context :first_name!
      respond_with :message, text: t('telegram_webhooks.leave_first_name')
    end
  end

  def last_name!(value = nil, *)
    if value
      user.last_name = payload['text']
      if user.save
        age!
      else
        save_context :last_name!
        respond_with(
          :message, text: user.errors.full_messages_for(:last_name).join(',')
        )
      end
    else
      save_context :last_name!
      respond_with :message, text: t('telegram_webhooks.leave_last_name')
    end
  end

  def save_ticket_request!(*)
    if user.contact_info_filled?
      TicketRequest.save_request!(user)
      respond_with :message, text: t('telegram_webhooks.thank_you')
    else
      respond_with :message, text: t('telegram_webhooks.some_data_missed')
      complete!
    end
  end

  def clear_cart!(*)
    cart.clear!
    cart!
  end

  def do_nothing
    # do nothing
  end

  def callback_query(data)
    send(data)
  end

  def check_ticket_available
    if TicketRequest.without_rejected.count > 200
      respond_with :message, text: t('telegram_webhooks.preorder_closed')
    elsif (ticket_request = TicketRequest.find_by(user_id: user.id))
      text =
        if ticket_request.not_approved?
          t('telegram_webhooks.ticket_rejected')
        else
          t('telegram_webhooks.thank_you')
        end
      respond_with :message, text: text
    else
      yield
    end
  end

  def message(message)
    return start! if t('telegram_webhooks.categories.home') == message['text']

    send("#{MENU.find { |_k, v| v == message['text'] }&.first}!")
  end

  private

  def cart
    @cart ||= Cart.find_or_create_by(user_id: @user.id, completed: false)
  end

  def user
    @user ||= User.find_or_create_by(
      telegram_id: from['id'],
      telegram_username: from['username']
    )
  end

  def before_complete_text
    {
      text: t(
        'telegram_webhooks.your_contact_and_age_is',
        contact: user.contacts,
        age: user.age,
        instagram: user.instagram,
        first_name: user.first_name,
        last_name: user.last_name,
      ),
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: t('telegram_webhooks.change_contact'),
              callback_data: 'complete!'
            }
          ],
          [{ text: t('telegram_webhooks.pay'), callback_data: 'save_ticket_request!' }]
        ]
      }
    }
  end

  def respond_item_keyboard(item, subitem = nil)
    text = ['telegram_webhooks', 'description', item, subitem].join('.')
    respond_with(
      :message,
      text: t(text),
      reply_markup: { inline_keyboard: send("#{subitem || item}_keyboard") },
      parse_mode: 'Markdown'
    )
  end

  def test_keyboard(step, index)
    next_callback = TEST_QUESTIONS[index + 1] || 'complete'
    %w[button_1 button_2].map do |button|
      [
        {
          text: t("telegram_webhooks.test.#{step}.#{button}"),
          callback_data: "#{next_callback}!"
        }
      ]
    end
  end

  def transfer_keyboard
    TransferRequest::OPTIONS.map do |option, price|
      [
        {
          text:
            t("telegram_webhooks.options.#{option}",
            price: price,
            selected: ('✅' if user.transfer_request&.route == option)
          ),
          callback_data: "add_#{option}"
        }
      ]
    end
  end

  def merch_keyboard
    Cart::MERCH_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def build_cart_item(option, price)
    [
      [
        {
          text: t("telegram_webhooks.options.#{option}",
                  price: price,
                  count: cart.items.dig(option, 'count') || 0),
          callback_data: 'do_nothing'
        }
      ],
      [
        { text: '➖', callback_data: "remove_#{option}" },
        { text: '➕', callback_data: "add_#{option}" }
      ]
    ]
  end

  def default_keyboard
    {
      keyboard: MENU.values.each_slice(3).to_a,
      resize_keyboard: true,
      one_time_keyboard: false,
      selective: false
    }
  end
end
