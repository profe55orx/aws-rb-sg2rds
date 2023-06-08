require 'aws-sdk-rds'
require 'aws-sdk-ec2'

class AWSManager
  def initialize(region: 'us-west-2', db_instance_identifier: ENV['RDS_INSTANCE_IDENTIFIER'], cidr_block: ENV['CIDR_BLOCK'])
    @ec2_client = Aws::EC2::Client.new(region: region)
    @rds_client = Aws::RDS::Client.new(region: region)
    @db_instance_identifier = db_instance_identifier
    @cidr_block = cidr_block
    @security_group_name = 'my-security-group'
    @tag_key = 'Name'
    @tag_value = 'my-tag'
  end

  def existing_security_group
    @existing_security_group ||= @ec2_client.describe_security_groups({
      filters: [
        {name: "tag:#{@tag_key}", values: [@tag_value]},
      ]
    }).security_groups.first
  end

  def security_group_id
    @security_group_id ||= if existing_security_group.nil?
      # Create a security group
      sg = @ec2_client.create_security_group({
        group_name: @security_group_name,
        description: 'Security group for RDS DB instance'
      })

      id = sg.group_id

      # Authorize ingress traffic for the security group
      @ec2_client.authorize_security_group_ingress({
        group_id: id,
        ip_permissions: [{
          ip_protocol: "tcp",
          from_port: 3306,
          to_port: 3306,
          ip_ranges: [{cidr_ip: @cidr_block}]
        }]
      })

      # Tag the security group
      @ec2_client.create_tags({
        resources: [id],
        tags: [{key: @tag_key, value: @tag_value}]
      })

      id
    else
      existing_security_group.group_id
    end
  end

  def existing_rds_security_group_binding
    existing_rds_instance = @rds_client.describe_db_instances({
      db_instance_identifier: @db_instance_identifier
    }).db_instances.first

    existing_rds_instance&.vpc_security_groups&.find { |sg| sg.vpc_security_group_id == security_group_id }
  end

  def modify_rds_instance
    return if existing_rds_security_group_binding

    @rds_client.modify_db_instance({
      db_instance_identifier: @db_instance_identifier,
      vpc_security_group_ids: [security_group_id],
      apply_immediately: true
    })
  end

  def tag_rds_instance
    existing_rds_instance = @rds_client.describe_db_instances({
      db_instance_identifier: @db_instance_identifier
    }).db_instances.first

    return if existing_rds_instance&.tag_list&.find { |tag| tag.key == @tag_key && tag.value == @tag_value }

    @rds_client.add_tags_to_resource({
      resource_name: existing_rds_instance.db_instance_arn, 
      tags: [{key: @tag_key, value: @tag_value}]
    })
  end
end
