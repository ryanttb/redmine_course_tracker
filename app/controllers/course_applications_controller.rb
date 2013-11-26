class CourseApplicationsController < ApplicationController
  unloadable
  # TODO make sure an registrant cannot add a new course application to a course they have already applied to
  before_filter :require_admin, :except => [:index, :show, :new, :edit, :create, :update, :destroy, :view_table, :new_referral]

  helper :attachments
  include AttachmentsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :sort
  include SortHelper
  
  def index
    sort_init 'created_at', 'desc'
    sort_update 'last_name' => "#{Registrant.table_name}.last_name",
                'id' => "#{CourseApplication.table_name}.id",
                'acceptance_status' => "#{CourseApplication.table_name}.acceptance_status",
                'user_id' => "#{CourseApplication.table_name}.user_id",
                'created_at' => "#{CourseApplication.table_name}.created_at"
    
    if(User.current.admin?)
      @course_tracker = CourseTracker.find(params[:course_tracker_id])
      if(params[:view_scope] == 'course' || (params[:registrant_id].nil? && params[:course_tracker_id].nil?))
        # if viewing all course applications for a particular course
        @course_applications = Course.find(params[:course_id]).course_applications
      elsif(params[:view_scope] == 'registrant' || (params[:course_id].nil? && params[:course_tracker_id].nil?))
        # if viewing all course applications for a particular user/registrant
        @course_applications = Registrant.find(params[:registrant_id]).course_applications
      else
        # if viewing all course applications for an course_tracker
        @courses = CourseTracker.find(params[:course_tracker_id]).courses
        @course_applications = Array.new
        @courses.each do |course|
          @course_applications << course.course_applications
        end
      end
      @course_applications.flatten!

    elsif(User.current.logged?)
      @registrant = Registrant.find_by_email(User.current.mail)
      @course_applications = @registrant.nil? ? nil : @registrant.course_applications
      @course_tracker = CourseTracker.find(params[:course_tracker_id])
    end
  end

  def show
    # secure the parent course_tracker id and find requested course_application
    @course_application = CourseApplication.find(params[:id])
    @registrant = @course_application.registrant
    @course_tracker = CourseTracker.find(@course_application.course_tracker_id)

  	unless User.current.admin? || @course_application.course.is_manager? || @registrant.email == User.current.mail
  	  flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
    
    # note these two lines are NOT the same, one is course materials the other is course referrals
    #@course_application_materials = @course_application.course_application_materials.find :all, :include => [:attachments]
    #@course_application_referrals = @course_application.course_application_referrals.find :all, :include => [:attachments]
    
    respond_to do |format|
      format.html #show.html.erb
    end
  end

  def new
    @course = Course.find params[:course_id] 
    @registrant = Registrant.find_by_email(User.current.mail)
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    if @course.submission_date < DateTime.now
      flash[:error] = "The deadline has passed for this course."
      redirect_to('/') and return
    end

    if @registrant.nil?
      redirect_to(new_registrant_url(:course_tracker_id => @course_tracker.id, :course_id => @course.id))
    else
      if @registrant.age < 13
        redirect_to(courses_url(:course_tracker_id => @course_tracker.id), :notice => "Thank you for your interest in this course.")
      else
        @course_application = CourseApplication.new(:course_id => @course.id, :registrant_id => @registrant.id, :course_tracker_id => @course_tracker.id) 
      end  
    end  
  end

  def edit
    @course_application = CourseApplication.find(params[:id])
    @course = Course.find @course_application.course_id
    @registrant = @course_application.registrant
  	unless User.current.admin? || @course.is_manager? || @registrant.email == User.current.mail
  	  flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @course_application_materials = @course_application.course_application_materials.find :all, :include => [:attachments]
  end

  def create
    @registrant = Registrant.find params[:course_application][:registrant_id]
    @course = Course.find params[:course_application][:course_id]
    if @course.submission_date < DateTime.now
      flash[:error] = "The deadline has passed for this course."
      redirect_to('/') and return
    end
    
    if @course_application.grade_why
      @course_application = CourseApplication.new(:course_id => @course.id, :registrant_id => @registrant.id, :acceptance_status => "Auto-Reject")
    else
      @course_application = CourseApplication.new(:course_id => @course.id, :registrant_id => @registrant.id, :acceptance_status => "Not Reviewed")
    end    
    
    @course_tracker = CourseTracker.find(params[:course_application][:course_tracker_id])
    
    #prepare the course application material attachments
    materials = @course_application.course.application_material_types.split(',')
    error_files = Array.new
    unless params[:attachments].nil?
      i = 1
      materials.each do |amt|
        unless params[:attachments][i.to_s].nil?
          params[:attachments][i.to_s]['description'] = amt
        else
          error_files << amt  
        end  
        i = i + 1
      end 
    else
      error_files = materials  
    end
    
    #Automatically assign the TF
    @course_application.assign_tf
    
    respond_to do |format|
      if error_files.empty?
        flash.now[:error] = nil
        @course_application.update_attributes(params[:course_application])
        if(@course_application.save)
          #if course application requires material then create course application material
          unless @course.application_material_types.nil? || @course.application_material_types.empty?
            course_app_file = Hash.new
            course_app_file["course_application_id"] = @course_application.id
            @course_application_material = @course_application.course_application_materials.build(course_app_file)
            @course_application_material.save
            attachments = Attachment.attach_files(@course_application_material, params[:attachments])
            render_attachment_warning_if_needed(@course_application_material)
          end
          #Send Notification
          Email.deliver_application_submitted(@course_application) 
          
          # no errors, redirect with success message
          flash[:notice] = l(:notice_successful_create)
          #if there are referrals required redirect to referral entry page
          unless @course.referrer_count.nil? || @course.referrer_count == "0"
            format.html { redirect_to(new_referral_course_applications_url(:course_application => @course_application.id, :course_tracker_id => @course_tracker.id), :notice => "Application has been created. Please fill in your referrals.") }
          else  
            format.html { redirect_to(courses_url(:course_tracker_id => @course_application.course_tracker_id), :notice => "Application has been submitted.") }
          end  
        else
          # validation prevented save; redirect back to new.html.erb with error messages
          format.html { render :action => "new" }
        end
      else
        flash.now[:error] = nil
        # course material validation prevented save; redirect back to new.html.erb with error messages
        flash.now[:error] = nil
        message = ""
        error_files.each do |material|
          line = material + " " + "cannot be empty."
          message = message + line + "\n"
        end
        message = message + "You will need to re-upload all documents."
        flash.now[:error] = message
        @course_application.attributes = params[:course_application]
        format.html { render :action => "new" }  
      end  
    end  
  end
  
  def new_referral
    @course_application = CourseApplication.find(params[:course_application])
    @registrant = @course_application.registrant_id
    @course_tracker = CourseTracker.find(@course_application.course_tracker_id)
    @course = Course.find(@course_application.course_id)
    @course_application_referral = @course_application.course_application_referrals.build()
  end

  def update
    # find the course_application within its parent registrant
    @registrant = Registrant.find(params[:course_application][:registrant_id])
    @course_application = @registrant.course_applications.find(params[:id])
  	unless User.current.admin? || @course_application.course.is_manager? || @registrant.email == User.current.mail
  	  flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
    
    @course = Course.find @course_application.course_id
    @course_tracker = CourseTracker.find(params[:course_application][:course_tracker_id])
    @course_application_materials = @course_application.course_application_materials.find :all, :include => [:attachments]
        
    # update the course_application's attributes, and indicate a message to the user opon success/failure
    respond_to do |format|
      if(@course_application.update_attributes(params[:course_application]))
        # attach files
        unless @course.application_material_types.nil? || @course.application_material_types.empty?
          course_app_file = Hash.new
          course_app_file["course_application_id"] = @course_application.id
          if @course_application_materials.nil? || @course_application_materials.empty?
            @course_application_material = @course_application.course_application_materials.build(course_app_file)
            @course_application_material.save
          else  
            @course_application_material = @course_application.course_application_materials.find :first
          end  
          materials = @course_application.course.application_material_types.split(',')
          unless materials.empty?
            i = 1
            materials.each do |amt|
              unless params[:attachments].nil? || params[:attachments][i.to_s].nil? || params[:attachments][i.to_s]['file'].nil?
                params[:attachments][i.to_s]['description'] = amt
              end  
              i = i + 1
            end
            attachments = Attachment.attach_files(@course_application_material, params[:attachments])
            render_attachment_warning_if_needed(@course_application_material)    
            @course_application_materials = @course_application.course_application_materials.find :all, :include => [:attachments]
            uploaded = Array.new
            @course_application_materials.each do |jam|
      		    jam.attachments.each do |jam_file|
      		      uploaded << jam_file.description
      		    end  
      	    end
          
      	    upload_error = false
      	    materials.each do |material|
      	      if !uploaded.include?(material)
      	        upload_error = true
      	      end  
      	    end
      	  end
      	end
      	if upload_error == true
      	  # validation prevented update; redirect to edit form with error messages
      	  flash[:error] = "Please upload all required materials. You will need to re-upload all documents."
          format.html { render :action => "edit" }
        else
          if @registrant.email == User.current.mail
            #Send Notification
            Email.deliver_application_updated(@course_application)
          end  
          # no errors, redirect with success message
          if(User.current.admin? || @course_application.course.is_manager?)
            format.html { redirect_to(course_url(@course_application.course_id, :course_tracker_id => @course_application.course_tracker_id), :notice => "#{@course_application.registrant.first_name} #{@course_application.registrant.last_name}\'s information has been updated.") }
          else
            #if there are referrals required redirect to referral entry page
            unless @course.referrer_count.nil? || @course.referrer_count == "0" || (@course_application.course_application_referrals.length >= @course_application.course.referrer_count.to_i)
              format.html { redirect_to(new_referral_course_applications_url(:course_application => @course_application.id, :course_tracker_id => @course_tracker.id), :notice => "Application has been updated. Please fill in your referrals.") }
            else  
              format.html { redirect_to(course_applications_url(:course_tracker_id => @course_application.course_tracker_id, :registrant_id => @course_application.registrant_id), :notice => "#{@course_application.registrant.first_name} #{@course_application.registrant.last_name}\'s information has been updated.") }
            end
          end    
        end  
      else
        # validation prevented update; redirect to edit form with error messages
        format.html { render :action => "edit"}
      end
    end
  end

  # DELETE /course_applications/1
  # DELETE course_application_url(:id => 1)
  def destroy
    # create a course_application in the context of its parent registrant
    @course_application = CourseApplication.find(params[:id])
    @course = @course_application.course
    @registrant = Registrant.find(@course_application.registrant_id)
	unless User.current.admin? || @registrant.email == User.current.mail
	  flash[:error] = "You are not authorized to view this section."
		redirect_to('/') and return
	end
    @course_tracker = CourseTracker.find(@course_application.course_tracker_id)

    # destroy the course_application, and indicate a message to the user upon success/failure
    @course_application.destroy ? flash[:notice] = "#{@registrant.first_name} #{@registrant.last_name}\'s record has been deleted." : flash[:error] = "Error: #{@registrant.first_name} #{@registrant.last_name}\'s record could not be deleted."
    
    respond_to do |format|
      format.html { redirect_to(course_url(@course, :course_tracker_id => @course_tracker.id, :registrant_id => @registrant.id)) }
    end
  end
  
  def view_table
    sort_init 'acceptance_status', 'asc'  
    sort_update %w(acceptance_status)       
                
    @course = Course.find(params[:course_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
    @course_tracker = @course.course_tracker
    
    @course_count = @course.course_applications.count
    @per_page = 5
    @course_pages = Paginator.new self, @course_count, @per_page, params[:page]
    
    @course_applications = @course.course_applications.find(:all, :order => sort_clause, :limit => @course_pages.items_per_page, :offset => @course_pages.current.offset)
    @course_application_custom_fields = @course.all_course_app_custom_fields
    @registrant_fields = Registrant.column_names - ["id", "created_at", "updated_at"]
    @custom = []
    unless @course_application_custom_fields.empty?
  		@course_application_custom_fields.each do |custom_field|
  		  @custom << custom_field.name
  		end
  	end
  	@columns = @registrant_fields + @custom
  end
  
end
