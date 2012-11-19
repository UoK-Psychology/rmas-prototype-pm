class AddIsApprovedToProposals < ActiveRecord::Migration
  def change
    add_column :proposals, :ethics_approved, :boolean , :default => false
  end
end
