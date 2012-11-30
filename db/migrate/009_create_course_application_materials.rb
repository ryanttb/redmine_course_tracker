class CreateCourseApplicationMaterials < ActiveRecord::Migration
  def self.up
    create_table :course_application_materials do |t|
      t.integer :course_application_id
      t.string :material_type
      t.string :title
      t.string :notes
      t.string :filename

      t.timestamps
    end
  end

  def self.down
    drop_table :course_application_materials
  end
end
