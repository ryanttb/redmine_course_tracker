require_dependency 'custom_fields_helper'

module CustomFieldsHelperCoursePatch
  def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :custom_fields_tabs, :course_application_tab
      end
    end

    module InstanceMethods
      # Adds a course application tab to the user administration page
      def custom_fields_tabs_with_course_application_tab
        tabs = custom_fields_tabs_without_course_application_tab
        tabs << {:name => 'CourseApplicationCustomField', :partial => 'custom_fields/index', :label => :label_course_application_plural}
        return tabs
      end
    end
end