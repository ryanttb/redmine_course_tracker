class CourseTracker < ActiveRecord::Base
  # associations
  has_many :courses, :dependent => :destroy
  has_and_belongs_to_many :registrants
  belongs_to :project
  
  acts_as_searchable :columns => ["#{table_name}.title", "#{table_name}.description"], :order_column => "created_at", :include => :project
  acts_as_event :title => Proc.new {|o| "#{o.title}"},
                :url => Proc.new {|o| {:controller => 'course_trackers', :action => 'show', :id => o.id}},
                :type => Proc.new {|o| 'course_tracker' },
                :datetime => :created_at

  # validation
  validates_presence_of :title, :status
  validates_uniqueness_of :title

  # constants
  # TODO convert these values into variables that can be set from a settings page within Redmine
  COURSE_TRACKER_PLUGIN_FOLDER = "redmine_course_tracker"
  STATUS_OPTIONS = ['Active','Inactive']

  def self.find_all_course_trackers
    find(:all, :order => 'title')
  end

  def after_destroy
    if CourseTracker.count.zero?
      raise 'No course tracker to delete.'
    end
  end

end
