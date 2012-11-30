require 'rubygems'
require 'zip/zipfilesystem'

class CourseApplicationMaterial < ActiveRecord::Base
  unloadable
  
  # associations
  belongs_to :course_application
  acts_as_attachable

  validates_presence_of :course_application_id

  # TODO implement validation 

  # constants
  # TODO convert these values into variables that can be set from a settings page within Redmine
  MATERIAL_TYPE = ['Resume', 'Cover Letter', 'School Transcript', 'Recommendation Letter', 'License Photocopy', 'Passport Photocopy', 'Other']


  def attachments_deletable?(usr=User.current)
    if usr.admin? || usr.member_of?(self.course_application.course.course_tracker.project)
      false
    else
      true
    end  
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
