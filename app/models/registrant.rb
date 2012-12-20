class Registrant < ActiveRecord::Base
  
  # associations
  has_and_belongs_to_many :course_trackers
  has_many :projects, :through => :course_trackers

  has_many :course_application_materials, :through => :course_applications
  has_many :course_application_referrals, :through => :course_applications
  has_many :course_applications, :dependent => :destroy
  
  acts_as_searchable :columns => ["#{table_name}.first_name", "#{table_name}.last_name"], :order_column => "created_at", :date_column => :created_at
  acts_as_event :title => Proc.new {|o| "#{o.user_name}"},
                :url => Proc.new {|o| {:controller => 'registrants', :action => 'show', :id => o.id}},
                :type => Proc.new {|o| 'registrant' },
                :datetime => :created_at
                
  acts_as_activity_provider :find_options => {:select => "#{Registrant.table_name}.*", 
                                              :joins => "LEFT JOIN #{CourseApplication.table_name} ON #{Registrant.table_name}.id=#{CourseApplication.table_name}.registrant_id"}           

  # FIXME uncomment this when starting to implement Redmine login functionality
  # belongs_to :user


  # validation
  # FIXME Validations that fail are coming up with a 'translation missing: en' error
  validates_presence_of :first_name, :last_name, :email, :dob
  validates_length_of :phone, :maximum => 30
  #validates_uniqueness_of :email

  # constants
  # TODO convert these values into variables that can be set from a settings page within Redmine
  GENDER_OPTIONS = ['Male', 'Female', 'Other/Prefer not to answer']

end
