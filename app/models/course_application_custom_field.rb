class CourseApplicationCustomField < CustomField
  unloadable

  # associations
  has_and_belongs_to_many :courses, :join_table => "#{table_name_prefix}custom_fields_courses#{table_name_suffix}", :foreign_key => "custom_field_id"
  has_many :course_applications, :through => :course_application_custom_values

end
