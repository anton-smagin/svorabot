class AddFullNameToCart < ActiveRecord::Migration[5.2]
  def change
    add_column :carts, :full_name, :string
  end
end
