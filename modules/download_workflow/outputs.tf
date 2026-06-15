output "state_machine_arn" {
  description = "ARN of the CAGED download state machine."
  value       = aws_sfn_state_machine.this.arn
}

output "schedule_name" {
  description = "Name of the EventBridge Scheduler schedule."
  value       = aws_scheduler_schedule.this.name
}
