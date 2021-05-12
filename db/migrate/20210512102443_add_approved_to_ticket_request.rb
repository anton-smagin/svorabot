class AddApprovedToTicketRequest < ActiveRecord::Migration[6.1]
  def change
    add_column :ticket_requests, :approved, :boolean
  end
end
