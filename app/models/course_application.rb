class CourseApplication < ActiveRecord::Base
  unloadable

  # associations
  #belongs_to :registrant
  belongs_to :course
  belongs_to :registrant
  belongs_to :user

  has_many :course_application_referrals
  has_many :course_application_materials
  
  acts_as_customizable
  acts_as_attachable :delete_permission => :manage_documents
  
  acts_as_activity_provider :find_options => {:select => "#{CourseApplication.table_name}.*", 
                                              :joins => "LEFT JOIN #{Registrant.table_name} ON #{Registrant.table_name}.id=#{CourseApplication.table_name}.registrant_id"}

  # TODO incorporate reject_if code
  accepts_nested_attributes_for :course_application_referrals, :allow_destroy => true
  accepts_nested_attributes_for :course_application_materials, :reject_if => proc { |attributes| attributes['document'].blank? }, :allow_destroy => true

  # constants
  # TODO convert these values into variables that can be set from a settings page within Redmine
  ACCEPTANCE_STATUS = ['Yes', 'High Maybe', 'No', "Admit"].insert(0, "")
  REVIEW_STATUS = ['In Process', 'First Rev', 'Second Rev', 'Unreviewed'].insert(0, "")
  
  def validate
     
  end
  
  def available_custom_fields
    self.course.all_course_app_custom_fields || []
  end 
  
  def find_tf
    unless self.user_id.nil?
      User.find(self.user_id).login
    else
      "none"
    end  
  end  
  
  def assign_tf
    #tfs = self.course.tf_list.cycle
    #apps = Array.new(5){|i| "Application #{(i+1).to_s}"}
    #apps.each{|app| puts "Do something with #{app} and #{tfs.next}."}
    
    tfs = self.course.tf_list
    tfs_hash = Hash.new
    tfs.each do |tf|
      tf_apps = CourseApplication.find(:all, :conditions => {:user_id => tf.id})
      tfs_hash[tf] = tf_apps.length
    end
    self.user_id = tfs_hash.select {|k,v| v == tfs_hash.values.min}.first[0].id
  end  
  
end
