require 'redmine'
# TODO find out if all RESTful actions need a matching permission

# Patches to the Redmine core
require 'dispatcher'

Dispatcher.to_prepare :redmine_course_tracker do
  require_dependency 'custom_fields_helper'
  CustomFieldsHelper.send(:include, CustomFieldsHelperCoursePatch) unless CustomFieldsHelper.included_modules.include?(CustomFieldsHelperCoursePatch)
  
  #overriding the 30 character limit on the name attribute for custom fields
  CustomField.class_eval{
    def validate
      super
      remove_name_too_long_error!(errors)
    end

    def remove_name_too_long_error!(errors)
      errors.each_error do |attribute, error|
        if error.attribute == :name && error.type == :too_long
          errors_hash = errors.instance_variable_get(:@errors)
          if Array == errors_hash[attribute] && errors_hash[attribute].size > 1
            errors_hash[attribute].delete_at(errors_hash[attribute].index(error))
          else
            errors_hash.delete(attribute)
          end
        end
      end
    end
  }
  
end

Redmine::Plugin.register :redmine_course_tracker do
  name 'Redmine Course Tracker plugin'
  description 'An course tracker plugin for Redmine.'
  version '0.0.1'

  # Set controller action access permissions
  # - any controller filter (such as before_filter) that sets permissions (such as :require_admin) 
  # will always override any permissions set in this file or in the redmine roles/permission GUI
  # 
  project_module :course_tracker do
    # course tracker privileges
    permission :view_course_trackers, :course_trackers => :index
    permission :create_a_course_tracker, :course_trackers => :new
    permission :edit_a_course_tracker, :course_trackers => :edit
    permission :destroy_a_course_tracker, :course_trackers => :destroy
    
    # job privileges
    permission :view_courses, :courses => :index
    permission :create_a_course, :courses => :new
    permission :manage_course_attachments, :course_attachments => [:create, :update, :destroy]

    # referrer privileges
    permission :create_a_referrer, :referrers => :new
    permission :edit_a_referrer, :referrers => :edit
  end

  # set menu options; commented :if used for setting menu to visible if logged in
  menu(:project_menu, :course_trackers, {:controller => 'course_trackers', :action => 'index'}, :caption => "Course Tracker", :after => :overview, :param => :project_identifier)
  
  if RAILS_ENV == 'development'
    ActiveSupport::Dependencies.load_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
  end  
  
  Redmine::Search.map do |search|
    search.register :registrants
    search.register :courses
    search.register :course_trackers
  end

end
