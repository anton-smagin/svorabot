# frozen_string_literal: true

class AddUsersTable < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.integer :telegram_id
      t.string :telegram_username
      t.string :instagram
      t.string :first_name
      t.string :last_name
      t.string :contacts
      t.integer :age

      t.timestamps
    end
  end
end
