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
  ACCEPTANCE_STATUS = ['Not Reviewed', 'Admit', 'Auto-Reject', 'Reject', 'Withdraw', 'Waitlist', 'Enroll', 'Decline'].insert(0, "")
  #REVIEW_STATUS = ['Not Reviewed', 'In Process', 'First Rev', 'Second Rev', 'Unreviewed'].insert(0, "")
  
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
  
  def grade_why
    # Why do you want to take CopyrightX? (Please provide no fewer than 300 and no more than 500 words)
    grade = false
    self.custom_values.each do |custom_value|
      p custom_value.custom_field.name
      if custom_value.custom_field.name.include?("Why do you want to take CopyrightX?")
        if custom_value.value.split.size > 300 && custom_value.value.split.size < 500
          grade = true
        else
          grade = false
        end    
  	  end
    end
    return grade
  end  
  
  def grade_read_comp
    #1. We allowed the woman to stay with us for three weeks, but after the hurricane hit she _________ refused to help us repair our house.
    #2. The farmer expected the sun to nourish his crop with its unseasonably strong rays, but instead it _________ the crop before the fruit had a chance to mature.
    #3. In addition to being over 2,000 miles long, the trail was also one of the most _________ and tiring on the continent.
    #4. The artist’s paintings are _________ today, though they were _________ during her lifetime.
    #5. The teacher wanted to inspire his students to study science, so he invited the _________ _________ to his class.
    #6. Learning to wrap packages was the first thing the girl did when she _________ to work in her aunt’s store.
    #7. Wherever you go, _________ to remind you of the musician.
    #8. If we examine the forest with _________ the island is covered, we find it is full of life.
    #9. Identify the word that must be changed in order for the following sentence to be correct: Because the days was cold and stormy, the fishermen stayed in port.
    
    count_wrong = 0
    count_right = 0
    
    self.custom_values.each do |custom_value|
      if custom_value.custom_field.name.include?("1. We allowed the woman")
        if custom_value.value == "e. heartlessly"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("2. The farmer expected the sun")
        if custom_value.value == "b. withered"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("3. In addition to being over 2,000")
        if custom_value.value == "d. treacherous"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("4. The artist’s paintings are")
        if custom_value.value == "b. admired, overlooked"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("5. The teacher wanted to inspire")
        if custom_value.value == "d. eloquent chemist"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("6. Learning to wrap packages was")
        if custom_value.value == "a. went"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("7. Wherever you go,")
        if custom_value.value == "c. you will find something"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("8. If we examine the forest with")
        if custom_value.value == "d. which"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
      
      if custom_value.custom_field.name.include?("9. Identify the word that must be changed")
        if custom_value.value == "a. days"
          count_right = count_right + 1
        else
          count_wrong = count_wrong + 1
        end    
  	  end
    end
    
    if count_wrong > 2
      return false
    else 
      return true
    end    
  end  
  
end
