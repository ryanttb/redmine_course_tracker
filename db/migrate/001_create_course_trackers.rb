class CreateCourseTrackers < ActiveRecord::Migration
  def self.up
    create_table :course_trackers do |t|
      t.integer :project_id
      t.string :title
      t.string :description
      t.string :status
      
      t.timestamps
    end
  end

  def self.down
    drop_table :course_trackers
  end
end
