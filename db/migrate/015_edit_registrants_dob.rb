class EditRegistrantsDob < ActiveRecord::Migration
  def self.up
    add_column :registrants, :dob, :date
  end

  def self.down
    remove_column :registrants, :dob
  end
end
