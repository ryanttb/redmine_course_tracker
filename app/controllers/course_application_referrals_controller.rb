# TODO implement this controller
class CourseApplicationReferralsController < ApplicationController
  unloadable
  
  helper :attachments
  include AttachmentsHelper


  def index
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    if(User.current.admin?)
      if(params[:view_scope] == 'course' || (params[:registrant_id].nil? && params[:course_tracker_id].nil?))
        # if viewing all course applications for a particular course
        @course_application_referrals = Course.find(params[:course_id]).course_application.course_application_referrals
      elsif(params[:view_scope] == 'registrant' || (params[:course_id].nil? && params[:course_tracker_id].nil?))
        # if viewing all course referrals for a particular user/registrant
        @course_application_referrals = Registrant.find(params[:registrant_id]).course_application.course_application_referrals
      else
        # if viewing all course applications for an course_tracker
        @courses = CourseTracker.find(params[:course_tracker_id]).courses
        @course_application_referral = Array.new
        @courses.each do |course|
          course.course_applications.each do |ja|
            @course_application_referral << ja.course_application_referrals
          end
        end
      end
      @course_application_referral.flatten!

    elsif(User.current.logged?)
      @registrant = Registrant.find_by_email(User.current.mail)
      @course_application_referral = Array.new
      
      if params[:course_application_id].nil?
        @course_applications = @registrant.course_applications
        @course_applications.each do |ja|
          @course_application_referral << ja.course_application_referrals.find(:all, :include => [:attachments])
        end
        @course_application_referral.flatten!
      else
        @course_application_referral = CourseApplication.find(params[:course_application_id]).course_application_referrals.find(:all, :include => [:attachments])
      end
    end
  end

  def show
  end

  def new
    @course_application = CourseApplication.find(params[:id])
    @registrant = @course_application.registrant_id
    @course_tracker = CourseTracker.find(@course_application.course_tracker_id)
    @course = Course.find(@course_application.course_id)
    @course_application_referral = @course_application.course_application_referrals.build()
  end

  def create
    @course_application = CourseApplication.find(params[:course_application_referral][:course_application_id])
    
    @course_application_referral = @course_application.course_application_referrals.build(params[:course_application_referral])
    @course_application_referral.save
    
    # Send email to referrer to request referral
    Email.deliver_request_referral(@course_application, @course_application_referral.email, @course_application_referral)
    
    if @course_application.course_application_referrals.length < @course_application.course.referrer_count.to_i
      redirect_to(new_referral_course_applications_url(:course_application => @course_application.id, :course_tracker_id => @course_application.course_tracker_id), :notice => "Please fill in another referral.")
    else  
      redirect_to(course_applications_url(:course_tracker_id => @course_application.course_tracker_id, :registrant_id => @course_application.registrant_id), :notice => %Q[<p>Your reference requests have been submitted. If you are ready to add in application information and upload your application materials, click <a href='#{url_for(edit_course_application_url(@course_application.id, :course_tracker_id => @course_application.course_tracker_id))}'>here</a> or the 'Edit Application' link below.</p><p>Do not worry if you are not yet ready to finish other parts of the application - you have until the application deadline to do so.</p><p>When you are ready to submit your other application materials, visit the <a href="https://cyber.law.harvard.edu/apply/courses/7?course_tracker_id=3">fellowship listing page</a>, log back into the Application Tracker, and click on the 'Apply to this course' link at the top of the page.</p>])
    end 
  end

  def edit
    @course_application_referral = CourseApplicationReferral.find(params[:id])
    @course_application = CourseApplication.find(params[:course_app_id])
    @registrant = @course_application.registrant_id
    @course_tracker = CourseTracker.find(@course_application.course_tracker_id)
    @course = Course.find(@course_application.course_id)
  end

  def update
    @course_application = CourseApplication.find(params[:course_application_referral][:course_application_id])
    params[:course_application_referral][:referral_text] = params[:attachments]["1"][:description]
    @course_application_referral = CourseApplicationReferral.find(params[:id])
    
    #@course_application_referral = @course_application.course_application_referrals.build(params[:course_application_referral])
    @course_application_referral.update_attributes(params[:course_application_referral])
    
    attachments = Attachment.attach_files(@course_application_referral, params[:attachments])
    render_attachment_warning_if_needed(@course_application_referral)
    
    # Send email to registrant and referrer that referral has been submitted
    Email.deliver_referral_complete(@course_application, @course_application_referral.email)
    Email.deliver_referral_complete_to_ref(@course_application, @course_application_referral.email)
    
    redirect_to :controller => 'courses', :action => 'index', :course_tracker_id => @course_application.course_tracker_id, :notice => "Referral has been submitted."
  end

  def destroy
  end

  def request_referral
    @course_application = CourseApplication.find(params[:id])
    @emails = params[:email].split(',')
    #Send Message to Referrer
    @emails.each do |email|
      Email.deliver_request_referral(@course_application, email)
    end
    
    redirect_to(course_applications_url(:course_tracker_id => @course_application.course_tracker_id, :registrant_id => @course_application.registrant_id), :notice => "Referral request has been sent.")
  end
  
  def resend_referral
    @course_application = CourseApplication.find(params[:course_application])
    @course_application_referral = CourseApplicationReferral.find(params[:course_application_referral])
    Email.deliver_request_referral(@course_application, @course_application_referral.email, @course_application_referral)
    redirect_to(course_application_referrals_url(:course_id => @course_application.course.id, :course_application_id => @course_application.id, :course_tracker_id => @course_application.course_tracker_id), :notice => "Referral request has been sent.")
  end  
end
