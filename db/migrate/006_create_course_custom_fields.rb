class CreateCourseCustomFields < ActiveRecord::Migration
  def self.up
    create_table :course_custom_fields, :id => false do |t|
      t.references :custom_field
      t.references :course
      t.timestamps
    end
  end

  def self.down
    drop_table :course_custom_fields
  end
end
