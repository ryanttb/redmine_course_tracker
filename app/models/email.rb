class Email < Mailer
  
  def application_submitted(course_application)
    # Send the email to the registrant
    @email = course_application.course.application_followup_message
    recipients course_application.registrant.email
    subject "Course Application Submitted"
    body :url => url_for(:controller => 'course_application', :action => 'show', :id => course_application.id, :course_tracker_id => course_application.course_tracker_id)
    content_type "text/html"     
  end
  
  def application_updated(course_application)
    # Send the email to the registrant
    recipients Registrant.find_by_id(course_application.registrant.id).email
    subject "Course Application Updated"
    body :user => Registrant.find_by_id(course_application.registrant_id),
         :url => url_for(:controller => 'course_application', :action => 'show', :id => course_application.id, :course_tracker_id => course_application.course_tracker_id)
    content_type "text/html"
  end
  
  def request_referral(course_application, email, course_application_referral)
    @course_application = course_application
    @course_application_referral = course_application_referral
    # Send email to referrer
    recipients email
    subject "Link to upload a letter of recommendation in support of a course application"
    body :user => Registrant.find_by_id(course_application.registrant_id),
         :url => url_for(:controller => 'course_application_referral', :action => 'show', :id => course_application_referral.id, :course_app_id => course_application.id, :course_tracker_id => course_application.course_tracker_id)
    content_type "text/html"     
  end
  
  def referral_complete(course_application, referrer_email)
    @course_application = course_application
    # Send the email to the registrant
    recipients Registrant.find_by_id(course_application.registrant_id).email
    subject "A letter of recommendation has been submitted on your behalf"
    body :user => Registrant.find_by_id(course_application.registrant_id),
         :url => url_for(:controller => 'course_application', :action => 'show', :id => course_application.id, :course_tracker_id => course_application.course_tracker_id)
    content_type "text/html"     
  end
  
  def referral_complete_to_ref(course_application, referrer_email)
    @course_application = course_application
    # Send the email to the referrer
    recipients referrer_email
    subject "Your letter of recommendation has been successfully submitted"
    body :user => Registrant.find_by_id(course_application.registrant_id),
         :url => url_for(:controller => 'course_application', :action => 'show', :id => course_application.id, :course_tracker_id => course_application.course_tracker_id)
    content_type "text/html"     
  end
  
end