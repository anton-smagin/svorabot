class AddTransferRequestTable < ActiveRecord::Migration[6.1]
  def change
    create_table :transfer_requests do |t|
      t.references :user
      t.string :route_to
      t.string :route_return
      t.boolean :approved

      t.timestamps
    end
  end
end
