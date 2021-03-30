# frozen_string_literal: true

class AddInstagramToCart < ActiveRecord::Migration[5.2]
  def change
    add_column :carts, :instagram, :string
  end
end
