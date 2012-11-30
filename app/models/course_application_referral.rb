class CourseApplicationReferral < ActiveRecord::Base
  unloadable

  # associations
  belongs_to :course_application
  acts_as_attachable :delete_permission => :manage_documents

  # validations
  validates_presence_of :first_name, :last_name, :email

  # constants
  
  def attachments_deletable?(user=User.current)
    #editable_by?(usr) && super(usr)
    user.admin? ? true : false
  end
  
  def project
    self.course_application.course.course_tracker.project
  end
  
  def visible?(user=User.current)
    #!user.nil? && user.allowed_to?(:view_documents, project)
    true
  end
  
  def attachments_visible?(user=User.current)
    #user.allowed_to?(self.class.attachable_options[:view_permission], self.project)
    true
  end

end
