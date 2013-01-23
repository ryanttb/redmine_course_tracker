require 'rubygems'
require 'zip/zipfilesystem'
require 'csv'
require 'tempfile'

class CoursesController < ApplicationController
  unloadable
  before_filter :require_admin, :except => [:index, :show, :register, :filter, :filter_by_status, :export_to_csv, :zip_some, :zip_all, :zip_filtered, :zip_filtered_single, :export_filtered_to_csv, :show_all]
  
  helper :attachments
  include AttachmentsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :sort
  include SortHelper
  
  default_search_scope :courses

  def index
    sort_init 'submission_date', 'desc'
    sort_update %w(title category short_desc status submission_date)
    
    # secure the parent course_tracker id and find its courses
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    if(User.current.admin? || User.current.member_of?(@course_tracker.project))
      @courses = @course_tracker.courses.find(:all, :order => sort_clause)
    else
      @courses = @course_tracker.courses.find(:all, :conditions => ["status = ? and submission_date > ?", Course::COURSE_STATUS[0], DateTime.now], :order => sort_clause)
    end
  end

  def show
    @course = Course.find(params[:id])
    @course_tracker = @course.course_tracker
    
    session[:auth_source_registration] = nil
    @user = User.new(:language => Setting.default_language)
    
    sort_init 'created_at', 'desc'
    sort_update 'last_name' => "#{Registrant.table_name}.last_name",
                'id' => "#{CourseApplication.table_name}.id",
                'review_status' => "#{CourseApplication.table_name}.review_status",
                'acceptance_status' => "#{CourseApplication.table_name}.acceptance_status",
                'created_at' => "#{CourseApplication.table_name}.created_at"
                
    @course_count = @course.course_applications.count
    @per_page = 5
    @course_pages = Paginator.new self, @course_count, @per_page, params[:page]            
    
    if User.current.admin?
      @course_applications = @course.course_applications.find(:all, :order => sort_clause, :limit => @course_pages.items_per_page, :offset => @course_pages.current.offset)
    elsif User.current.member_of?(@course_tracker.project)
      @course_applications = @course.course_applications.find(:all, :conditions => {:user_id => User.current.id}, :order => sort_clause, :limit => @course_pages.items_per_page, :offset => @course_pages.current.offset)  
      @course_applications_all = @course.course_applications.find(:all, :order => sort_clause, :limit => @course_pages.items_per_page, :offset => @course_pages.current.offset)
    end
    
    @course_attachments = @course.course_attachments.build
    course_attachments = @course.course_attachments.find :first, :include => [:attachments]
    @course_attachment = course_attachments
    
    respond_to do |format|
      format.html #show.html.erb
    end
  end
  
  def show_all
    @course = Course.find(params[:id])
    @course_tracker = @course.course_tracker
    
    session[:auth_source_registration] = nil
    @user = User.new(:language => Setting.default_language)
    
    sort_init 'created_at', 'desc'
    sort_update 'last_name' => "#{Registrant.table_name}.last_name",
                'id' => "#{CourseApplication.table_name}.id",
                'review_status' => "#{CourseApplication.table_name}.review_status",
                'acceptance_status' => "#{CourseApplication.table_name}.acceptance_status",
                'created_at' => "#{CourseApplication.table_name}.created_at"
                
    @course_count = @course.course_applications.count
    @per_page = 5
    @course_pages = Paginator.new self, @course_count, @per_page, params[:page]            
    
    @course_applications = @course.course_applications.find(:all, :order => sort_clause, :limit => @course_pages.items_per_page, :offset => @course_pages.current.offset)
    
    @course_attachments = @course.course_attachments.build
    course_attachments = @course.course_attachments.find :first, :include => [:attachments]
    @course_attachment = course_attachments
    
    respond_to do |format|
      format.html #show.html.erb
    end
  end

  def new
    # secure the parent course_tracker id and create a new course
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    
    if(params[:course_id].nil?)
      @course = @course_tracker.courses.new
    else
      @course = @course_tracker.courses.find(params[:course_id])
    end
    respond_to do |format|
        format.html # new.html.erb
    end
  end

  def create
    # create a course in its parent course_tracker
    @course_tracker = CourseTracker.find(params[:course][:course_tracker_id])
    @course = @course_tracker.courses.new(params[:course])    
    unless params[:application_material_types].nil?
      @course.application_material_types = params[:application_material_types].join(",") + "," + params[:other_app_materials]
    else
      @course.application_material_types = params[:other_app_materials]  
    end  
    
    respond_to do |format|
      if(@course.save)
        
        #if course saved then create the course attachments
        #@course_attachments = params[:course][:course_attachments_attributes]["0"]
        course_file = Hash.new
        course_file["course_id"] = @course.id
        course_file["name"] = @course.title
        course_file["filename"] = @course.title
        course_file["notes"] = @course.title
        @course_attachment = @course.course_attachments.build(course_file)
        @course_attachment.save
        attachments = Attachment.attach_files(@course_attachment, params[:attachments])
        render_attachment_warning_if_needed(@course_attachment)
        
        flash[:notice] = l(:notice_successful_create)
        
        # no errors, redirect to second part of form
        format.html { redirect_to(courses_url(:course_tracker_id => @course_tracker.id)) }
      else
        # validation prevented save; redirect back to new.html.erb with error messages
        format.html { render :action => "new" }
      end
    end
  end

  def edit
    # secure the parent course_tracker id and find the course to edit
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @course = @course_tracker.courses.find(params[:id])
    @course_attachment = @course.course_attachments.find :first, :include => [:attachments]

    @custom_field = begin
      "CourseApplicationCustomField".to_s.constantize.new(params[:custom_field])
    rescue
    end
    
    @course_application_custom_fields = CourseApplicationCustomField.find(:all, :order => "#{CustomField.table_name}.position")
    
  end

  def update
    # find the course within its parent course_tracker
    @course_tracker = CourseTracker.find(params[:course][:course_tracker_id])
    @course = @course_tracker.courses.find(params[:id])
    # update the course's attributes, and indicate a message to the user opon success/failure
    respond_to do |format|
      if(@course.update_attributes(params[:course]))
        unless params[:application_material_types].nil?
          @course.application_material_types = params[:application_material_types].join(",") + "," + params[:other_app_materials]
        else
          @course.application_material_types = params[:other_app_materials]  
        end
        @course.save
        # no errors, redirect with success message
        @course_attachment = CourseAttachment.find(:first, :conditions => {:course_id => @course.id})
        course_file = Hash.new
        course_file["course_id"] = @course.id
        course_file["name"] = @course.title
        course_file["filename"] = @course.title
        course_file["notes"] = @course.title
        @course_attachment.update_attributes(course_file)
        attachments = Attachment.attach_files(@course_attachment, params[:attachments])
        render_attachment_warning_if_needed(@course_attachment)
        
        format.html { redirect_to(edit_course_url(@course, :course_tracker_id => @course_tracker.id), :notice => "\'#{@course.title}\' has been updated.") }
      else
        # validation prevented update; redirect to edit form with error messages
        @course_attachment = @course.course_attachments.find :first, :include => [:attachments]
        @custom_field = begin
          "CourseApplicationCustomField".to_s.constantize.new(params[:custom_field])
        rescue
        end
        @course_application_custom_fields = CourseApplicationCustomField.find(:all, :order => "#{CustomField.table_name}.position")
        format.html { render :action => "edit"}
      end
    end
  end

  def destroy
    # create a course in its parent course_tracker
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @course = @course_tracker.courses.find(params[:id])

    # destroy the course, and indicate a message to the user upon success/failure
    @course.destroy ? flash[:notice] = "\'#{@course.title}\' has been deleted." : flash[:error] = "Error: \'#{@course.title}\' could not be deleted."
    
    respond_to do |format|
      format.html { redirect_to(courses_url(:course_tracker_id => @course_tracker.id)) }
    end
  end
  
  def create_custom_field
    custom_field = CustomField.new(params[:custom_field])
    custom_field.type = params[:type]
    custom_field = begin
      if params[:type].to_s.match(/.+CustomField$/)
        params[:type].to_s.constantize.new(params[:custom_field])
      end
    rescue
    end
    course = Course.find_by_id params[:id]
    
    if custom_field.save
      flash[:notice] = l(:notice_successful_create)
      call_hook(:controller_custom_fields_new_after_save, :params => params, :custom_field => custom_field)
      cf_ids = course.all_course_app_custom_fields.collect {|cfield| cfield.id }
      cf_ids << custom_field.id
      cf = {"course_application_custom_field_ids" => cf_ids}
      course.attributes = cf
      course.save
    else
      flash[:notice] = "Custom field could not be added."
    end
    
    redirect_to :action => "edit", :id => course, :course_tracker_id => course.course_tracker_id
  end

  # Removes a CustomField from an Course.
  #
  # @return Nothing.
  def remove_custom_field
    course = Course.find_by_id params[:id]
    custom_field = CourseApplicationCustomField.find_by_id params[:existing_custom_field]
    course.course_application_custom_fields.delete custom_field
    course.save
    redirect_to :action => "edit", :id => course, :course_tracker_id => course.course_tracker_id
  end
  
  def zip_all
    @course = Course.find(params[:course])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
    @material_types = @course.application_material_types.split(',')
    @file_name = @course.title.gsub(/[^a-zA-Z\d]/, '-')
    @zip_file_path = "#{RAILS_ROOT}/tmp/#{@file_name}-all-materials.zip"
    @ca_materials = Array.new
    @ca_referrals = Array.new
    filepaths = Array.new
    counter = 1
    material_id_hash = Hash.new
    
    @registrants = @course.registrants
    @applications = CourseApplication.find(:all, :conditions => {:course_id => @course.id})
    
    @applications.each do |app|
      @ca_materials << CourseApplicationMaterial.find(:first, :conditions => {:course_application_id => app.id})
      unless @ca_referrals.nil?
        @ca_referrals << CourseApplicationReferral.find(:all, :conditions => {:course_application_id => app.id})
      end  
    end  
    
    unless @ca_referrals.nil?
      if @material_types.include?("Proposed Work")
        @material_types.insert(@material_types.index("Proposed Work") + 1, "Referral")
      elsif @material_types.include?("Cover Letter")
        @material_types.insert(@material_types.index("Cover Letter") + 1, "Referral")
      elsif @material_types.include?("Resume or CV")
        @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
      else 
        @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
      end  
    end
      
    @material_types.each do |material|
      material_id_hash[material] = "%03d" % counter.to_s + "_" + material.gsub(/ /, '_')
      counter = counter + 1
    end

    Zip::ZipFile.open(@zip_file_path, Zip::ZipFile::CREATE) do |zipfile|
      @registrants.each do |registrant|
        if zipfile.find_entry("#{registrant.last_name}_#{registrant.first_name}_#{registrant.id}")
          zipfile.remove("#{registrant.last_name}_#{registrant.first_name}_#{registrant.id}")
        end
        zipfile.mkdir("#{registrant.last_name}_#{registrant.first_name}_#{registrant.id}")  
      end  
      
      unless @ca_materials.nil?
        @ca_materials.each do |jam|
          jam.attachments.each do |jama|
            ext_name = File.extname("#{RAILS_ROOT}/files/" + jama.disk_filename)
            new_file_name = "#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{jam.course_application_id}#{ext_name}"
            orig_file_path = "#{RAILS_ROOT}/files/" + jama.disk_filename
            if File.exists?(orig_file_path)
              orig_file_name = File.basename(orig_file_path)
              if zipfile.find_entry(new_file_name)
                zipfile.remove(new_file_name)
              end
              zipfile.get_output_stream("#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).first_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).id}/" + new_file_name) do |f|
                input = File.open(orig_file_path)
                data_to_copy = input.read()
                f.write(data_to_copy)
              end
            else
              puts "Warning: file #{orig_file_path} does not exist"
            end
          end    
        end
      end   
    
      unless @ca_referrals.nil?
        @ca_referrals.each do |jar|
          jar.each do |ref|
            ref.attachments.each do |jara|
              ext_name = File.extname("#{RAILS_ROOT}/files/" + jara.disk_filename)
              new_file_name = "#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{ref.attachments.index(jara)+1}_#{ref.course_application_id}#{ext_name}"
              
              orig_file_path = "#{RAILS_ROOT}/files/" + jara.disk_filename
              if File.exists?(orig_file_path)
                orig_file_name = File.basename(orig_file_path)
                if zipfile.find_entry(new_file_name)
                  zipfile.remove(new_file_name)
                end
                zipfile.get_output_stream("#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).first_name}/" + new_file_name) do |f|
                  input = File.open(orig_file_path)
                  data_to_copy = input.read()
                  f.write(data_to_copy)
                end
              else
                puts "Warning: file #{orig_file_path} does not exist"
              end
            end  
          end    
        end
      end
      
    end
    
    begin
      send_file @zip_file_path, :type => 'application/zip', :disposition => 'attachment', :stream => false
      File.delete(@zip_file_path)
    rescue  
      if File.file?(@zip_file_path)
        File.delete(@zip_file_path)
      end  
      puts "Error sending file"
    end
    
  end
  
  def zip_some
    if params[:commit] == "Bulk Change"
      unless params[:registrants_to_zip].nil?
        applications = Array.new
        params[:registrants_to_zip].each do |ja|
          applications << CourseApplication.find(ja)
        end
        applications.each do |app|
          if !params[:user_id].blank?
            app.user_id = params[:user_id]
          end  
          if !params[:review_status].blank?
            app.review_status = params[:review_status]
          end  
          if !params[:acceptance_status].blank?
            app.acceptance_status = params[:acceptance_status]
          end 
          app.save!     
        end
        flash[:notice] = "Applications successfully updated!"
        redirect_to :back
      else
        flash[:notice] = "You did not select any applications."
        redirect_to :back  
      end
    else 
      @course = Course.find(params[:course])
      unless User.current.admin? || @course.is_manager?
        flash[:error] = "You are not authorized to view this section."
    		redirect_to('/') and return
    	end
      @material_types = params[:application_material_types]
      @file_name = @course.title.gsub(/[^a-zA-Z\d]/, '-')
      @zip_file_path = "#{RAILS_ROOT}/tmp/#{@file_name}-materials.zip"
      filepaths = Array.new
      counter = 1
      material_id_hash = Hash.new
      @ca_materials = Array.new
      if params[:registrant_referral]
        @ca_referrals = Array.new
      end
      registrants = Array.new
      unless params[:registrants_to_zip].nil?
        params[:registrants_to_zip].each do |ja|
          registrants << CourseApplication.find(ja).registrant.id
        end
      end
      @applications = CourseApplication.find(:all, :conditions => ["course_id = ? and registrant_id in (?)", @course.id, registrants])
    
      @applications.each do |app|
        @ca_materials << CourseApplicationMaterial.find(:first, :conditions => {:course_application_id => app.id})
        unless @ca_referrals.nil?
          @ca_referrals << CourseApplicationReferral.find(:all, :conditions => {:course_application_id => app.id})
        end  
      end  
    
      unless @ca_referrals.nil?
        if @material_types.include?("Proposed Work")
          @material_types.insert(@material_types.index("Proposed Work") + 1, "Referral")
        elsif @material_types.include?("Cover Letter")
          @material_types.insert(@material_types.index("Cover Letter") + 1, "Referral")
        elsif @material_types.include?("Resume or CV")
          @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
        else 
          @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
        end  
      end
      
      @material_types.each do |material|
        material_id_hash[material] = "%03d" % counter.to_s + "_" + material.gsub(/ /, '_')
        counter = counter + 1
      end
    
      Zip::ZipFile.open(@zip_file_path, Zip::ZipFile::CREATE) do |zipfile|
        unless @ca_materials.nil?
          @ca_materials.each do |jam|
            jam.attachments.each do |jama|
              @material_types.each do |mt|
                if mt == jama.description
                  ext_name = File.extname("#{RAILS_ROOT}/files/" + jama.disk_filename)
                  new_file_name = "#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{jam.course_application_id}#{ext_name}"
                  orig_file_path = "#{RAILS_ROOT}/files/" + jama.disk_filename
                  if File.exists?(orig_file_path)
                    orig_file_name = File.basename(orig_file_path)
                    if zipfile.find_entry(new_file_name)
                      zipfile.remove(new_file_name)
                    end
                    zipfile.get_output_stream(new_file_name) do |f|
                      input = File.open(orig_file_path)
                      data_to_copy = input.read()
                      f.write(data_to_copy)
                    end
                  else
                    puts "Warning: file #{file_path} does not exist"
                  end
                end  
              end  
            end    
          end 
        end  

        unless @ca_referrals.nil?
          @ca_referrals.each do |jar|
            jar.each do |ref|
              ref.attachments.each do |jara|
                ext_name = File.extname("#{RAILS_ROOT}/files/" + jara.disk_filename)
                new_file_name = "#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{ref.attachments.index(jara)+1}_#{ref.course_application_id}#{ext_name}"
              
                orig_file_path = "#{RAILS_ROOT}/files/" + jara.disk_filename
                if File.exists?(orig_file_path)
                  orig_file_name = File.basename(orig_file_path)
                  if zipfile.find_entry(new_file_name)
                    zipfile.remove(new_file_name)
                  end
                  zipfile.get_output_stream(new_file_name) do |f|
                    input = File.open(orig_file_path)
                    data_to_copy = input.read()
                    f.write(data_to_copy)
                  end
                else
                  puts "Warning: file #{file_path} does not exist"
                end
              end  
            end    
          end
        end
      end
    
      begin
        send_file @zip_file_path, :type => 'application/zip', :disposition => 'attachment', :stream => false
        File.delete(@zip_file_path)
      rescue  
        if File.file?(@zip_file_path)
          File.delete(@zip_file_path)
        end  
        puts "Error sending file"
      end
    end  
  end  
  
  def register
    redirect_to(home_url) && return unless Setting.self_registration? || session[:auth_source_registration]
    if request.post?
      @user = User.new(params[:user])
      @user.admin = false
      @user.register
      
      @user.login = params[:user][:login]
      @user.password, @user.password_confirmation = params[:password], params[:password_confirmation]
      # Automatic activation
      @user.activate
      @user.last_login_on = Time.now
      if @user.save
        self.logged_user = @user
        flash[:notice] = "Your account has been created. You are now logged in."
      else
        flash[:error] = "Your account could not be created."
      end
      redirect_to :back
    else
      redirect_to(home_url)    
    end  
  end
  
  
  def export_to_csv
    @course = Course.find(params[:course_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
    @registrants = @course.registrants
    @course_applications = @course.course_applications
    @file_name = @course.title.gsub(/ /, '-').gsub(/,/, '-')
    
    @course_application_custom_fields = @course.all_course_app_custom_fields
    @registrant_fields = Registrant.column_names - ["id", "created_at", "updated_at"]
    @custom = []
    unless @course_application_custom_fields.empty?
  		@course_application_custom_fields.each do |custom_field|
  		  @custom << custom_field.name
  		end
  	end
  	@columns = @registrant_fields + @custom
    
    csv_string = FasterCSV.generate do |csv| 
      # header row 
      csv << @columns

      # data rows 
      @course_applications.each do |ja|
        row = []
        @registrant_fields.each do |af|
          row << ja.registrant.send(af)
        end
        @custom.each do |c| 
          ja.custom_values.each do |cv|
            if cv.custom_field.name == c
              row << show_value(cv)
            end  
          end
        end  
        csv << row
      end 
    end 

    # send it to the browser
    send_data csv_string, 
            :type => 'text/html; charset=iso-8859-1; header=present', 
            :disposition => "attachment; filename=#{@file_name}-registrants.csv"
  end
  
  def filter
    @course = Course.find(params[:course_id])
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
  	
  	@course_application = CourseApplication.new(:course => @course)
    @course_application_custom_fields = @course.all_course_app_custom_fields
    @registrant_fields = Registrant.column_names - ["id", "created_at", "updated_at"]
    @custom = []
    unless @course_application_custom_fields.empty?
  		@course_application_custom_fields.each do |custom_field|
  		  @custom << custom_field.name
  		end
  	end
  	@columns = @registrant_fields + @custom
    
    unless params[:filter].nil?
      @custom_fields = params[:filter][:custom_field_values]
      @custom_values = []
      # how many custom fields are we searching on
      value_count = 0
      @custom_fields.each_key do |field_id|
        unless @custom_fields[field_id].nil? || @custom_fields[field_id].empty?
          value_count = value_count + 1
          @custom_values += CustomValue.find(:all, :conditions => ["custom_field_id = ? and value like ?", field_id, "%#{@custom_fields[field_id]}%"])
        end  
      end
      course_app_ids = @custom_values.collect {|x| x.customized_id}
      
      # kick out course ids that do not fulfill all custom fields being searched on
      counts = Hash.new(0)
      course_app_ids.each { |app_id| counts[app_id] += 1 }
      course_app_ids.uniq!
      counts.each_key do |app_id|
        if counts[app_id] != value_count
          course_app_ids.delete(app_id)
        end  
      end 
      
      @course_applications = CourseApplication.find(:all, :conditions => ["course_id = ? and id in (?)", params[:course_id], course_app_ids])
    end   
  end
  
  def zip_filtered
    @course = Course.find(params[:course_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
  	
  	@course_applications = CourseApplication.find(:all, :conditions => ["id in (?)", params[:course_applications]])
  	
    # create zip file of filtered results
    @material_types = @course.application_material_types.split(',')
    @file_name = @course.title.gsub(/[^a-zA-Z\d]/, '-')
    @zip_file_path = "#{RAILS_ROOT}/tmp/#{@file_name}-filtered-materials.zip"
    @ca_materials = Array.new
    @ca_referrals = Array.new
    filepaths = Array.new
    counter = 1
    material_id_hash = Hash.new
    
    registrant_ids = @course_applications.collect {|ja| ja.registrant_id }
    @registrants = Registrant.find(:all, :conditions => ["id in (?)", registrant_ids])
    @applications = CourseApplication.find(:all, :conditions => {:course_id => @course.id})

    @course_applications.each do |app|
      @ca_materials << CourseApplicationMaterial.find(:first, :conditions => {:course_application_id => app.id})
      unless @ca_referrals.nil?
        @ca_referrals << CourseApplicationReferral.find(:all, :conditions => {:course_application_id => app.id})
      end  
    end  

    unless @ca_referrals.nil?
      if @material_types.include?("Proposed Work")
        @material_types.insert(@material_types.index("Proposed Work") + 1, "Referral")
      elsif @material_types.include?("Cover Letter")
        @material_types.insert(@material_types.index("Cover Letter") + 1, "Referral")
      elsif @material_types.include?("Resume or CV")
        @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
      else 
        @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
      end  
    end

    @material_types.each do |material|
      material_id_hash[material] = "%03d" % counter.to_s + "_" + material.gsub(/ /, '_')
      counter = counter + 1
    end

    Zip::ZipFile.open(@zip_file_path, Zip::ZipFile::CREATE) do |zipfile|
      @registrants.each do |registrant|
        if zipfile.find_entry("#{registrant.last_name}_#{registrant.first_name}_#{registrant.id}")
          zipfile.remove("#{registrant.last_name}_#{registrant.first_name}_#{registrant.id}")
        end
        zipfile.mkdir("#{registrant.last_name}_#{registrant.first_name}_#{registrant.id}")  
      end  

      unless @ca_materials.nil?
        @ca_materials.each do |jam|
          jam.attachments.each do |jama|
            ext_name = File.extname("#{RAILS_ROOT}/files/" + jama.disk_filename)
            new_file_name = "#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{jam.course_application_id}#{ext_name}"
            orig_file_path = "#{RAILS_ROOT}/files/" + jama.disk_filename
            if File.exists?(orig_file_path)
              orig_file_name = File.basename(orig_file_path)
              if zipfile.find_entry(new_file_name)
                zipfile.remove(new_file_name)
              end
              zipfile.get_output_stream("#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).first_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).id}/" + new_file_name) do |f|
                input = File.open(orig_file_path)
                data_to_copy = input.read()
                f.write(data_to_copy)
              end
            else
              puts "Warning: file #{orig_file_path} does not exist"
            end
          end    
        end
      end   

      unless @ca_referrals.nil?
        @ca_referrals.each do |jar|
          jar.each do |ref|
            ref.attachments.each do |jara|
              ext_name = File.extname("#{RAILS_ROOT}/files/" + jara.disk_filename)
              new_file_name = "#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{ref.attachments.index(jara)+1}_#{ref.course_application_id}#{ext_name}"

              orig_file_path = "#{RAILS_ROOT}/files/" + jara.disk_filename
              if File.exists?(orig_file_path)
                orig_file_name = File.basename(orig_file_path)
                if zipfile.find_entry(new_file_name)
                  zipfile.remove(new_file_name)
                end
                zipfile.get_output_stream("#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).first_name}/" + new_file_name) do |f|
                  input = File.open(orig_file_path)
                  data_to_copy = input.read()
                  f.write(data_to_copy)
                end
              else
                puts "Warning: file #{orig_file_path} does not exist"
              end
            end  
          end    
        end
      end

    end

    begin
      send_file @zip_file_path, :type => 'application/zip', :disposition => 'attachment', :stream => false
      File.delete(@zip_file_path)
    rescue  
      if File.file?(@zip_file_path)
        File.delete(@zip_file_path)
      end  
      puts "Error sending file"
    end
  end 
  
  def zip_filtered_single
    @course = Course.find(params[:course_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
  	
  	@course_applications = CourseApplication.find(:all, :conditions => ["id in (?)", params[:course_applications]])
  	
    # create zip file of filtered results
    @material_types = @course.application_material_types.split(',')
    @file_name = @course.title.gsub(/[^a-zA-Z\d]/, '-')
    @zip_file_path = "#{RAILS_ROOT}/tmp/#{@file_name}-filtered-materials.zip"
    @ca_materials = Array.new
    @ca_referrals = Array.new
    filepaths = Array.new
    counter = 1
    material_id_hash = Hash.new

    @applications = CourseApplication.find(:all, :conditions => {:course_id => @course.id})

    @course_applications.each do |app|
      @ca_materials << CourseApplicationMaterial.find(:first, :conditions => {:course_application_id => app.id})
      unless @ca_referrals.nil?
        @ca_referrals << CourseApplicationReferral.find(:all, :conditions => {:course_application_id => app.id})
      end  
    end  

    unless @ca_referrals.nil?
      if @material_types.include?("Proposed Work")
        @material_types.insert(@material_types.index("Proposed Work") + 1, "Referral")
      elsif @material_types.include?("Cover Letter")
        @material_types.insert(@material_types.index("Cover Letter") + 1, "Referral")
      elsif @material_types.include?("Resume or CV")
        @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
      else 
        @material_types.insert(@material_types.index("Resume or CV") + 1, "Referral")
      end  
    end

    @material_types.each do |material|
      material_id_hash[material] = "%03d" % counter.to_s + "_" + material.gsub(/ /, '_')
      counter = counter + 1
    end

    Zip::ZipFile.open(@zip_file_path, Zip::ZipFile::CREATE) do |zipfile|

      unless @ca_materials.nil?
        @ca_materials.each do |jam|
          jam.attachments.each do |jama|
            ext_name = File.extname("#{RAILS_ROOT}/files/" + jama.disk_filename)
            new_file_name = "#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(jam.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{jam.course_application_id}#{ext_name}"
            orig_file_path = "#{RAILS_ROOT}/files/" + jama.disk_filename
            if File.exists?(orig_file_path)
              orig_file_name = File.basename(orig_file_path)
              if zipfile.find_entry(new_file_name)
                zipfile.remove(new_file_name)
              end
              zipfile.get_output_stream(new_file_name) do |f|
                input = File.open(orig_file_path)
                data_to_copy = input.read()
                f.write(data_to_copy)
              end
            else
              puts "Warning: file #{orig_file_path} does not exist"
            end
          end    
        end
      end   

      unless @ca_referrals.nil?
        @ca_referrals.each do |jar|
          jar.each do |ref|
            ref.attachments.each do |jara|
              ext_name = File.extname("#{RAILS_ROOT}/files/" + jara.disk_filename)
              new_file_name = "#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).last_name}_#{Registrant.find(CourseApplication.find(ref.course_application_id).registrant_id).first_name}_#{material_id_hash[jama.description]}_#{ref.attachments.index(jara)+1}_#{ref.course_application_id}#{ext_name}"

              orig_file_path = "#{RAILS_ROOT}/files/" + jara.disk_filename
              if File.exists?(orig_file_path)
                orig_file_name = File.basename(orig_file_path)
                if zipfile.find_entry(new_file_name)
                  zipfile.remove(new_file_name)
                end
                zipfile.get_output_stream(new_file_name) do |f|
                  input = File.open(orig_file_path)
                  data_to_copy = input.read()
                  f.write(data_to_copy)
                end
              else
                puts "Warning: file #{orig_file_path} does not exist"
              end
            end  
          end    
        end
      end

    end
    begin
      send_file @zip_file_path, :type => 'application/zip', :disposition => 'attachment', :stream => false
      File.delete(@zip_file_path)
    rescue  
      if File.file?(@zip_file_path)
        File.delete(@zip_file_path)
      end  
      puts "Error sending file"
    end  
  end 
  
  def filter_by_status
    @course = Course.find(params[:course_id])
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
  	
  	@course_application_custom_fields = @course.all_course_app_custom_fields
    @registrant_fields = Registrant.column_names - ["id", "created_at", "updated_at"]
    @custom = []
    unless @course_application_custom_fields.empty?
  		@course_application_custom_fields.each do |custom_field|
  		  @custom << custom_field.name
  		end
  	end
  	@columns = @registrant_fields + @custom
  	@course_applications = []
  	unless params[:user_id].blank?
  	  @course_applications << CourseApplication.find(:all, :conditions => {:course_id => params[:course_id], :user_id => params[:user_id]})
  	end
  	unless params[:review_status].blank?
  	  @course_applications << CourseApplication.find(:all, :conditions => {:course_id => params[:course_id], :review_status => params[:review_status]})
  	end 
  	unless params[:acceptance_status].blank?
  	  @course_applications << CourseApplication.find(:all, :conditions => {:course_id => params[:course_id], :acceptance_status => params[:acceptance_status]})
  	end 
  	@course_applications.flatten!
  end
  
  def export_filtered_to_csv
    @course = Course.find(params[:course_id])
    unless User.current.admin? || @course.is_manager?
      flash[:error] = "You are not authorized to view this section."
  		redirect_to('/') and return
  	end
  	@course_applications = CourseApplication.find(:all, :conditions => ["id in (?)", params[:course_app_ids]])
  	
    @file_name = @course.title.gsub(/ /, '-').gsub(/,/, '-')
    
    @course_application_custom_fields = @course.all_course_app_custom_fields
    @registrant_fields = Registrant.column_names - ["id", "created_at", "updated_at"]
    @custom = []
    unless @course_application_custom_fields.empty?
  		@course_application_custom_fields.each do |custom_field|
  		  @custom << custom_field.name
  		end
  	end
  	@columns = @registrant_fields + @custom + ['review_status', 'acceptance_status']
    
    csv_string = FasterCSV.generate do |csv| 
      # header row 
      csv << @columns

      # data rows 
      @course_applications.each do |ja|
        row = []
        @registrant_fields.each do |af|
          row << ja.registrant.send(af)
        end
        @custom.each do |c| 
          ja.custom_values.each do |cv|
            if cv.custom_field.name == c
              row << show_value(cv)
            end  
          end
        end
        row << ja.review_status
        row << ja.acceptance_status  
        csv << row
      end 
    end 

    # send it to the browser
    send_data csv_string, 
            :type => 'text/html; charset=iso-8859-1; header=present', 
            :disposition => "attachment; filename=#{@file_name}-registrant-status.csv"
  end  
  
end
