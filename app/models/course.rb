class Course < ActiveRecord::Base
  # associations
  belongs_to :course_tracker
  
  # FIXME Should course_applications to a course be destroyed if a course is deleted?
  has_many :course_applications
  has_many :registrants, :through => :course_applications
  has_many :course_attachments, :dependent => :destroy

  has_and_belongs_to_many :course_application_custom_fields,
                          :class_name => 'CourseApplicationCustomField',
                          :order => "#{CustomField.table_name}.position",
                          :join_table => "#{table_name_prefix}custom_fields_courses#{table_name_suffix}",
                          :association_foreign_key => 'custom_field_id'
       
  acts_as_searchable :columns => ["#{table_name}.title", "#{table_name}.description"], :date_column => :created_at
  acts_as_event :title => Proc.new {|o| "#{o.title}"},
                :url => Proc.new {|o| {:controller => 'courses', :action => 'show', :id => o.id}},
                :type => Proc.new {|o| 'course' },
                :datetime => :created_at
                        
  acts_as_customizable
  acts_as_attachable :delete_permission => :manage_documents

  accepts_nested_attributes_for :course_attachments, :reject_if => proc { |attributes| attributes['document'].blank? }, :allow_destroy => true

  # validation
  validates_presence_of :category, :status, :title, :short_desc, :description, :referrer_count, :application_followup_message
  validates_length_of :short_desc, :maximum => 255
  
  # constants
  # TODO convert these values into variables that can be set from a settings page within Redmine
  # The first entry of the COURSE_STATUS array is reserved for allowing anonymous to see a course's details
  COURSE_STATUS = ["Active", "Inactive"]
  COURSE_CATEGORIES = ["Application", "Enrollment"]
  COURSE_MATERIALS = ["Resume or CV", "Cover Letter", "Proposed Work", "Writing Sample"]
  
  def all_course_app_custom_fields
    @all_course_app_custom_fields = self.course_application_custom_fields
  end
  
  def is_manager?(usr=User.current)
    usr.roles_for_project(self.course_tracker.project).include?(Role.find(:first, :conditions => {:name => "Manager"}))
    #usr.member_of?(self.course_tracker.project)
  end
  
  def display_deadline
    return "#{(self.submission_date.to_date-30).strftime('%m/%d/%Y')} #{self.submission_date.strftime('%I:%M %p')} ET"
  end 
  
  def tf_select
    tfs = Array.new
    User.all.each do |u| 
      if self.is_manager?(u)
        tfs << [u.login, u.id]
      end  
    end 
    tfs.insert(0, "")
    return tfs
  end
  
  def tf_list
    tfs = Array.new
    User.all.each do |u| 
      if self.is_manager?(u)
        tfs << u
      end  
    end 
    return tfs
  end     

end
