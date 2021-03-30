# frozen_string_literal: true

class AddTicketRequestTable < ActiveRecord::Migration[6.1]
  def change
    create_table :ticket_requests do |t|
      t.references :user

      t.timestamps
    end
  end
end
