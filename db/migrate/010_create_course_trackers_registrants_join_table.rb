class CreateCourseTrackersRegistrantsJoinTable < ActiveRecord::Migration
  def self.up
    create_table :course_trackers_registrants, :id => false do |t|
      t.integer :course_tracker_id
      t.integer :registrant_id
    end
  end

  def self.down
    drop_table :course_trackers_registrants
  end
end
