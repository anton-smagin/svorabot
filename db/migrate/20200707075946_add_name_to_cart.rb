class AddFullNameToCart < ActiveRecord::Migration[5.2]
  def change
    add_column :carts, :first_name, :string
    add_column :carts, :last_name, :string
  end
end
