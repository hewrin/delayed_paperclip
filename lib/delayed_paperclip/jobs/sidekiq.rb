require 'sidekiq/worker'

module DelayedPaperclip
  module Jobs
    class Sidekiq
      include ::Sidekiq::Worker
      sidekiq_options :queue => :paperclip

      def self.enqueue_delayed_paperclip(instance_klass, instance_id, attachment_name)
        puts "*********************" 
        puts "enqueue_delayed_paperclip method starts"
        puts "*********************"
        perform_async(instance_klass, instance_id, attachment_name)
        #Image.find(instance_id).update(finished: true)
        puts "*********************" 
        puts "prepare_enqueueing_for_ method ends"
        puts "*********************"
      end

      def perform(instance_klass, instance_id, attachment_name)
        puts "*********************" 
        puts "perforn method starts"
        puts "*********************"
        DelayedPaperclip.process_job(instance_klass, instance_id, attachment_name)
        Image.find(instance_id).update_columns(finished: true)
        puts "*********************" 
        puts "perforn method ends"
        puts "*********************"
      end
    end
  end
end
