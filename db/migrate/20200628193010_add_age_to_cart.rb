class AddAgeToCart < ActiveRecord::Migration[5.2]
  def change
    add_column :carts, :user_age, :integer
  end
end
