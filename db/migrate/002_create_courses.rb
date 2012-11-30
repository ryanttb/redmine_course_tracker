class CreateCourses < ActiveRecord::Migration
  def self.up
    create_table :courses do |t|
      t.integer :course_tracker_id
      t.string :category 
      t.string :title 
      t.text :short_desc
      t.text :description 
      t.integer :spots_available
      t.string :application_followup_message, :text, :default => "", :null => false
      t.integer :application_material_count
      t.string :application_material_types
      t.integer :attachment_count
      t.string :attachment_ids
      t.string :referrer_count
      t.string :status
      t.datetime :submission_date

      t.timestamps
    end
  end

  def self.down
    drop_table :courses
  end
end
