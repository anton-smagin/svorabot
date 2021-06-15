class ClearSessionsTableJob < ActiveJob::Base
  include Delayed::RecurringJob
  run_every 1.day

  def perform
    system 'bundle exec rake db:sessions:trim'
  end
end
