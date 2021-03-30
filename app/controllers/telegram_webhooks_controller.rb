# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  around_action :check_ticket_available

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
      user.update(
        contacts: payload['text'], telegram_username: from['username']
      )
      share_instagram!
    else
      save_context :complete!
      respond_with :message, text: t('telegram_webhooks.leave_name_and_contact')
    end
  end

  def share_instagram!(value = nil, *)
    if value
      user.update(instagram: payload['text'])
      first_name!
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
        respond_with :message, text: user.errors.full_messages.join(',')
      end
    else
      save_context :age!
      respond_with :message, text: t('telegram_webhooks.leave_age')
    end
  end

  def first_name!(value = nil, *)
    if value
      user.update(first_name: payload['text'])
      last_name!
    else
      save_context :first_name!
      respond_with :message, text: t('telegram_webhooks.leave_first_name')
    end
  end

  def last_name!(value = nil, *)
    if value
      user.update(last_name: payload['text'])
      age!
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
    if TicketRequest.count > 50
      respond_with :message, text: t('telegram_webhooks.preorder_closed')
    elsif TicketRequest.where(user_id: user.id).exists?
      respond_with :message, text: t('telegram_webhooks.thank_you')
    else
      yield
    end
  end

  private

  def cart
    @cart ||= Cart.find_or_create_by(user_id: @user.id, completed: false)
  end

  def user
    @user ||= User.find_or_create_by(telegram_id: from['id'])
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
end
