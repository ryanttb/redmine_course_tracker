class CreateCourseApplications < ActiveRecord::Migration
  def self.up
    create_table :course_applications do |t|
      t.integer :course_tracker_id
      t.integer :registrant_id
      t.integer :course_id
      t.string :review_status
      t.string :acceptance_status
      t.text :notes

      t.timestamps
    end
  end

  def self.down
    drop_table :course_applications
  end
end
