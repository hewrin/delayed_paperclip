require 'delayed_paperclip/jobs'
require 'delayed_paperclip/attachment'
require 'delayed_paperclip/url_generator'
require 'delayed_paperclip/railtie'

module DelayedPaperclip

  class << self

    def options
      @options ||= {
        :background_job_class => detect_background_task,
        :url_with_processing  => true,
        :processing_image_url => nil
      }
    end

    def detect_background_task
      return DelayedPaperclip::Jobs::Sidekiq    if defined? ::Sidekiq
      return DelayedPaperclip::Jobs::ActiveJob  if defined? ::ActiveJob::Base
      return DelayedPaperclip::Jobs::DelayedJob if defined? ::Delayed::Job
      return DelayedPaperclip::Jobs::Resque     if defined? ::Resque
    end

    def processor
      options[:background_job_class]
    end

    def enqueue(instance_klass, instance_id, attachment_name)
      puts "*********************" 
      puts "enqueue method starts"
      puts "*********************"
      processor.enqueue_delayed_paperclip(instance_klass, instance_id, attachment_name)
      puts "*********************" 
      puts "enqueue method ends"
      puts "*********************"
    end

    def process_job(instance_klass, instance_id, attachment_name)
       puts "*********************" 
       puts "process job method starts"
       puts "*********************"
      instance_klass.constantize.unscoped.find(instance_id).
        send(attachment_name).
        process_delayed!
        puts "*********************" 
        puts "process job method ends"
        puts "*********************"
    end

  end

  module Glue
    def self.included(base)
      base.extend(ClassMethods)
      base.send :include, InstanceMethods
    end
  end

  module ClassMethods

    def process_in_background(name, options = {})
      # initialize as hash
      puts "*********************" 
      puts "process_in_background method starts"
      puts "*********************"
      paperclip_definitions[name][:delayed] = {}

      # Set Defaults
      only_process_default = paperclip_definitions[name][:only_process]
      only_process_default ||= []
      {
        :priority => 0,
        :only_process => only_process_default,
        :url_with_processing => DelayedPaperclip.options[:url_with_processing],
        :processing_image_url => DelayedPaperclip.options[:processing_image_url],
        :queue => nil
      }.each do |option, default|

        paperclip_definitions[name][:delayed][option] = options.key?(option) ? options[option] : default
        puts "*********************" 
        puts "process_in_background method ends"
        puts "*********************"
      end

      # Sets callback
      if respond_to?(:after_commit)
        after_commit  :enqueue_delayed_processing
      else
        after_save    :enqueue_delayed_processing
      end
    end

    def paperclip_definitions
      @paperclip_definitions ||= if respond_to? :attachment_definitions
        attachment_definitions
      else
        Paperclip::Tasks::Attachments.definitions_for(self)
      end
    end
  end

  module InstanceMethods

    # First mark processing
    # then enqueue
    def enqueue_delayed_processing
      puts "*********************" 
      puts "enqueue_delayed_processing method starts"
      puts "*********************"
      mark_enqueue_delayed_processing
      (@_enqued_for_processing || []).each do |name|

        enqueue_post_processing_for(name)
      end
      @_enqued_for_processing_with_processing = []
      @_enqued_for_processing = []
      puts "*********************" 
      puts "enqueue_delayed_processing method ends"
      puts "*********************"
    end

    # setting each inididual NAME_processing to true, skipping the ActiveModel dirty setter
    # Then immediately push the state to the database
    def mark_enqueue_delayed_processing
      puts "*********************" 
      puts "mark_enqueue_delayed_processing method starts"
      puts "*********************"
      unless @_enqued_for_processing_with_processing.blank? # catches nil and empty arrays
        updates = @_enqued_for_processing_with_processing.collect{|n| "#{n}_processing = :true" }.join(", ")
        updates = ActiveRecord::Base.send(:sanitize_sql_array, [updates, {:true => true}])
        self.class.where(:id => self.id).update_all(updates)
      end
      puts "*********************" 
      puts "mark_enqueue_delayed_processing method ends"
      puts "*********************"
    end

    def enqueue_post_processing_for name
      puts "*********************" 
      puts "enqueue_post_processing_for method starts"
      puts "*********************"
      DelayedPaperclip.enqueue(self.class.name, read_attribute(:id), name.to_sym)
      puts "*********************" 
      puts "enqueue_post_processing_for method ends"
      puts "*********************"

    end

    def prepare_enqueueing_for name
      puts "*********************" 
      puts "prepare_enqueueing_for_ method ends"
      puts "*********************"

      if self.attributes.has_key? "#{name}_processing"
        write_attribute("#{name}_processing", true)
        @_enqued_for_processing_with_processing ||= []
        @_enqued_for_processing_with_processing << name
      end
      @_enqued_for_processing ||= []
      @_enqued_for_processing << name
    end
    puts "*********************" 
    puts "prepare_enqueueing_for_ method ends"
    puts "*********************"

  end
end
