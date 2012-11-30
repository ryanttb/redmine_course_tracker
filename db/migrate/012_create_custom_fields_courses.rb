class CreateCustomFieldsCourses < ActiveRecord::Migration
  def self.up
    create_table :custom_fields_courses, :id => false do |t|
      t.references :custom_field
      t.references :course
      t.timestamps
    end
  end

  def self.down
    drop_table :custom_fields_courses
  end
end
