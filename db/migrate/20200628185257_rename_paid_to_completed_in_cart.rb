# frozen_string_literal: true

class RenamePaidToCompletedInCart < ActiveRecord::Migration[5.2]
  def change
    change_table :carts do |t|
      t.rename :paid, :completed
    end
  end
end
