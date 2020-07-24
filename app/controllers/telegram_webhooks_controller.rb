# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  MENU = %i[about lineup ticket transfer food excursion merch cart help]
         .map do |category|
    [category, t("telegram_webhooks.categories.#{category}")]
  end.to_h.freeze
  ARTISTS = I18n.t('telegram_webhooks.artists').keys.freeze

  ITEMS_MENU = {
    'ticket' => ['ticket'],
    'transfer' => %w[transfer_moscow transfer_galich],
    'food' => ['food'],
    'excursion' => ['excursion'],
    'merch' => ['merch']
  }.freeze

  def start!(_value = nil, *_args)
    respond_with(
      :message,
      text: t('telegram_webhooks.description.start'),
      reply_markup: default_keyboard
    )
    respond_with(
      :photo,
      photo: File.open(Rails.root.join('public', 'img', 'afisha.png'))
    )
  end

  def help!(*)
    respond_with(
      :message,
      text: t('telegram_webhooks.help') + "\n" +
      t('telegram_webhooks.categories')
        .map { |command, name| "/#{command} #{name}\n" }.join('')
    )
  end

  def about!(*)
    start!
  end

  def callback_query(data)
    send(data)
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
      cart.items.delete(item) if cart.items[item]['count'].zero?
      send("edit_#{Cart.category_by(item)}!") if cart.changed? && cart.save
    end
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

  def lineup!(*)
    respond_with(
      :message,
      text: t('telegram_webhooks.description.lineup'),
      reply_markup: default_keyboard
    )

    t('telegram_webhooks.timetable').each do |day, stages|
      stages.each do |stage, artists|
        message_text = t("telegram_webhooks.categories.#{day}")
        message_text +=  " #{t("telegram_webhooks.stages.#{stage}")}"
        respond_with(
          :message,
          text: message_text,
          reply_markup: {
            inline_keyboard: artists.map do |artist, time|
              [{ text: time, callback_data: "artist_#{artist}!" }]
            end
          }
        )
      end
    end
  end

  ARTISTS.each do |artist_name|
    define_method("artist_#{artist_name}!") do
      artist_info(artist_name)
    end
  end

  def complete!(value = nil, *)
    return cart_empty if cart.empty?

    if value
      cart.update(
        contacts: payload['text'],
        telegram_username: from['username']
      )
      share_contact!
    else
      save_context :complete!
      respond_with :message, text: t('telegram_webhooks.leave_name_and_contact')
    end
  end

  def share_contact!(value = nil, *)
    return cart_empty if cart.empty?

    if value
      cart.update(instagram: payload['text'])
      full_name!
    else
      save_context :share_contact!
      respond_with :message, text: t('telegram_webhooks.leave_instagram')
    end
  end

  def age!(value = nil, *)
    return cart_empty if cart.empty?

    if value
      cart.user_age = value
      if cart.save
        respond_with :message, send_cart_text
      else
        save_context :age!
        respond_with :message, text: cart.errors.full_messages.join(',')
      end
    else
      save_context :age!
      respond_with :message, text: t('telegram_webhooks.leave_age')
    end
  end

  def full_name!(value = nil, *)
    return cart_empty if cart.empty?

    if value
      cart.update(full_name: payload['text'])
      age!
    else
      save_context :full_name!
      respond_with :message, text: t('telegram_webhooks.leave_name')
    end
  end

  def send_cart!(*)
    return cart_empty if cart.empty?

    cart.complete!
    respond_with :message, text: t('telegram_webhooks.thank_you')
  end

  def clear_cart!(*)
    cart.clear!
    cart!
  end

  def do_nothing
    # do nothing
  end

  def message(message)
    return start! if t('telegram_webhooks.categories.home') == message['text']

    send("#{MENU.find { |_k, v| v == message['text'] }&.first}!")
  end

  private

  def ticket_keyboard
    Cart::TICKET_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def transfer_moscow_keyboard
    Cart::TRANSFER_MOSCOW_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def transfer_galich_keyboard
    Cart::TRANSFER_GALICH_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def excursion_keyboard
    Cart::EXCURSION_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def merch_keyboard
    Cart::MERCH_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def food_keyboard
    Cart::FOOD_OPTIONS
      .flat_map { |option, price| build_cart_item(option, price) }
  end

  def cart
    @cart ||= Cart.find_or_create_by(telegram_id: from['id'], completed: false)
  end

  def cart_total_text
    "#{t('telegram_webhooks.categories.cart')} \n" +
      cart.items.map do |item, info|
        t(
          "telegram_webhooks.options.#{item}",
          count: info['count'],
          price: Cart.price_by(item)
        )
      end.join("\n") +
      "\n#{t('telegram_webhooks.cart_total', total: cart.total)}"
  end

  def send_cart_text
    {
      text: t(
        'telegram_webhooks.your_contact_and_age_is',
        contact: cart.contacts,
        age: cart.user_age,
        instagram: cart.instagram,
        full_name: cart.full_name
      ),
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: t('telegram_webhooks.change_contact'),
              callback_data: 'complete!'
            }
          ],
          [{ text: t('telegram_webhooks.pay'), callback_data: 'send_cart!' }]
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

  def cart_empty
    respond_with(:message, text: t('telegram_webhooks.cart_empty'))
  end

  def artist_info(artist)
    respond_with(:message, text: t("telegram_webhooks.artists.#{artist}"))
    photo_path = Rails.root.join('public', 'img', 'artists', "#{artist}.jpg")

    reply_with :photo, photo: File.open(photo_path) if File.exist?(photo_path)
  end

  def default_keyboard
    {
      keyboard: MENU.values.each_slice(3).to_a,
      resize_keyboard: true,
      one_time_keyboard: false,
      selective: false
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
end
