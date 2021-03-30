# frozen_string_literal: true

class CreateCarts < ActiveRecord::Migration[5.2]
  def change
    create_table :carts do |t|
      t.integer :telegram_id
      t.string :telegram_username
      t.string :contacts
      t.boolean :paid, default: false
      t.jsonb :items, null: false, default: {}

      t.timestamps
    end
  end
end
