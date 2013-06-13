Delayed::Worker.destroy_failed_jobs = false
#Delayed::Worker.sleep_delay = 5
Delayed::Worker.max_attempts = 3
Delayed::Worker.max_run_time = 100.minutes
#Delayed::Worker.read_ahead = 5
#Delayed::Worker.delay_jobs = !Rails.env.test?
