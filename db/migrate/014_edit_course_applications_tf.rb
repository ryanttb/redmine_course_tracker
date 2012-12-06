class EditCourseApplicationsTf < ActiveRecord::Migration
  def self.up
    add_column :course_applications, :user_id, :integer
  end

  def self.down
    remove_column :course_applications, :user_id
  end
end
