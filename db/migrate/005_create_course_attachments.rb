class CreateCourseAttachments < ActiveRecord::Migration
  def self.up
    create_table :course_attachments do |t|
      t.integer :course_id
      t.string :filename
      t.string :name
      t.string :notes

      t.timestamps
    end
  end

  def self.down
    drop_table :course_attachments
  end
end
