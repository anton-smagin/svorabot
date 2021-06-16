# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  before_action :user

  MENU =
    %i[ticket transfer]
    .map do |category|
      [category, t("telegram_webhooks.categories.#{category}")]
    end.to_h.freeze

  ITEMS_MENU = {
    'ticket' => ['ticket'],
    'transfer' => %w[transfer]
    #'merch' => ['merch']
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
    return unless ticket_available?

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
    define_method("#{item}!") { |*| respond_item_keyboard(item) }

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
      if TransferRequest.left(item).positive?
        transfer_request.select_route(item)
        transfer_request.save
      else
        text = [
          t("telegram_webhooks.#{item}"),
          t('telegram_webhooks.unavailable')
        ].join(' ')
        respond_with(:message, text: text)
      end
      edit_transfer!
    end
  end

  def transfer!
    if TransferRequest.unavailable?
      return respond_with(
        :message,
        text: t('telegram_webhooks.transfer_request_unavailable')
      )
    end
    return respond_item_keyboard('transfer') unless transfer_request.approved?

    routes =
      transfer_request
      .selected_routes
      .map { |route| [t("telegram_webhooks.#{route}")] }
    respond_with(
      :message,
      text: t(
        'telegram_webhooks.selected_transfer_request',
        routes: routes.join("\n")
      )
    )
  end

  def order_transfer!
    session[:checkout_callback] = 'save_transfer_request!'
    if user.contacts_info_filled?
      respond_with :message, before_complete_response
    else
      complete!
    end
  end

  def order_ticket!
    session[:checkout_callback] = 'save_ticket_request!'
    if user.contacts_info_filled?
      respond_with :message, before_complete_response
    else
      complete!
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
        respond_with :message, before_complete_response
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
    return unless ticket_available?

    if user.contacts_info_filled?
      TicketRequest.save_request!(user)
      respond_with :message, text: t('telegram_webhooks.thank_you')
    else
      session[:checkout_callback] = 'save_ticket_request!'
      respond_with :message, text: t('telegram_webhooks.some_data_missed')
      complete!
    end
  end

  def save_transfer_request!(*)
    if user.contacts_info_filled?
      if transfer_request.approve!
        respond_with :message, text: t('telegram_webhooks.thank_you')
      else
        respond_with(
          :message, text: t('telegram_webhooks.transfer_request_unavailable')
        )
      end
    else
      session[:checkout_callback] = 'save_transfer_request!'
      respond_with :message, text: t('telegram_webhooks.some_data_missed')
      complete!
    end
  end

  def do_nothing
    # do nothing
  end

  def callback_query(data)
    send(data)
  end

  def ticket_available?
    if TicketRequest.without_rejected.count > 150
      respond_with :message, text: t('telegram_webhooks.preorder_closed')
      false
    elsif (ticket_request = TicketRequest.find_by(user_id: user.id))
      text =
        if ticket_request.not_approved?
          t('telegram_webhooks.ticket_rejected')
        else
          t('telegram_webhooks.thank_you')
        end
      respond_with :message, text: text
      false
    else
      true
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

  def transfer_request
    @transfer_request ||=
      user.transfer_request || TransferRequest.new(user_id: user.id)
  end

  def before_complete_response
    {
      text: t(
        'telegram_webhooks.your_contact_and_age_is',
        contact: user.contacts,
        age: user.age,
        instagram: user.instagram,
        first_name: user.first_name,
        last_name: user.last_name
      ),
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: t('telegram_webhooks.change_contact'),
              callback_data: 'complete!'
            }
          ],
          [
            {
              text: t('telegram_webhooks.pay'),
              callback_data: session[:checkout_callback]
            }
          ]
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
    if TEST_QUESTIONS[index + 1]
      next_callback = TEST_QUESTIONS[index + 1]
    else
      next_callback = 'order_ticket'
    end
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
    keyboard =
      TransferRequest::OPTIONS.map do |option, about|
        next [] if TransferRequest.left(option) <= 0

        [
          {
            text: t(
              "telegram_webhooks.options.#{option}",
              price: about[:price],
              selected: ('✅' if transfer_request.selected_route?(option))
            ),
            callback_data: "add_#{option}"
          }
        ]
      end
    if transfer_request.selected_route?
      [*keyboard, order_transfer_button]
    else
      keyboard
    end
  end

  def order_transfer_button
    [
      {
        text: t('telegram_webhooks.pay'), callback_data: 'order_transfer!'
      }
    ]
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

  def send_photo(item)
    Dir.foreach(Rails.root.join('public', 'img', item.to_s)) do |filename|
      next unless /png|gif|jpeg|jpg/.match?(filename)

      file =
        File.open(Rails.root.join('public', 'img', item.to_s, filename))

      reply_with :photo, photo: file
    end
  end
end
