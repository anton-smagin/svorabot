# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
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
      photo: File.open(Rails.root.join('public', 'img', 'afisha.png'))
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

  def action_missing(_action, *args)
    start!(*args)
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
      cart.update(
        contacts: payload['text'], telegram_username: from['username']
      )
      share_name!
    else
      save_context :complete!
      respond_with :message, text: t('telegram_webhooks.leave_name_and_contact')
    end
  end

  def share_contact!(value = nil, *)
    if value
      cart.update(instagram: payload['text'])
      full_name!
    else
      save_context :share_contact!
      respond_with :message, text: t('telegram_webhooks.leave_instagram')
    end
  end

  def age!(value = nil, *)
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
    if value
      cart.update(full_name: payload['text'])
      age!
    else
      save_context :full_name!
      respond_with :message, text: t('telegram_webhooks.leave_name')
    end
  end

  def send_cart!(*)
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

  def callback_query(data)
    send(data)
  end

  private

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
    next_callback = TEST_QUESTIONS[index + 1] || 'complete!'
    %w[button_1 button_2].map do |button|
      [
        {
          text: t("telegram_webhooks.test.#{step}.#{button}"),
          callback_data: next_callback
        }
      ]
    end
  end
end
