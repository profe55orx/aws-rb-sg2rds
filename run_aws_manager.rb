require_relative 'aws_manager'

aws_manager = AWSManager.new(
  region: 'us-west-2', 
  db_instance_identifier: ENV['RDS_INSTANCE_IDENTIFIER'], 
  cidr_block: ENV['CIDR_BLOCK']
)

aws_manager.security_group_id
aws_manager.modify_rds_instance
aws_manager.tag_rds_instance

puts "RDS instance and security group updated and tagged"
