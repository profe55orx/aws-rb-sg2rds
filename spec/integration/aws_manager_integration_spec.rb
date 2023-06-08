require 'aws_manager'

describe 'AWSManager integration test' do
  let(:region) { 'us-west-2' }
  let(:db_instance_identifier) { 'my-rds-instance' }  # Replace with your test RDS instance
  let(:cidr_block) { '0.0.0.0/0' }
  let(:aws_manager) { AWSManager.new(region: region, db_instance_identifier: db_instance_identifier, cidr_block: cidr_block) }
  let(:security_group_id) { aws_manager.security_group_id }

  before(:all) do
    rds_client = Aws::RDS::Client.new(region: region)

    # Create the RDS instance for testing
    rds_client.create_db_instance({
      db_name: db_instance_identifier,
      db_instance_identifier: db_instance_identifier,
      allocated_storage: 5,  # in GB
      db_instance_class: 'db.t2.micro',  # Free tier eligible
      engine: 'mysql',
      master_username: 'testuser',
      master_user_password: 'testpassword',
      multi_az: false,
      vpc_security_group_ids: [],
      publicly_accessible: true,
      tags: [
        {
          key: 'Name',
          value: 'Test RDS Instance'
        }
      ]
    })

    # Wait until the RDS instance is available
    rds_client.wait_until(:db_instance_available, db_instance_identifier: db_instance_identifier)
  end

  after(:all) do
    # Cleanup: Detach the security group from the RDS instance and delete the security group
    rds_client = Aws::RDS::Client.new(region: region)
    rds_instance = rds_client.describe_db_instances({
      db_instance_identifier: db_instance_identifier
    }).db_instances.first
    existing_security_groups = rds_instance.vpc_security_groups.map(&:vpc_security_group_id)
    rds_client.modify_db_instance({
      db_instance_identifier: db_instance_identifier,
      vpc_security_group_ids: existing_security_groups - [security_group_id],
      apply_immediately: true
    })
    sleep(60)  # Wait for the changes to apply

    # Delete the RDS instance
    rds_client.delete_db_instance({
      db_instance_identifier: db_instance_identifier,
      skip_final_snapshot: true
    })

    # Wait until the RDS instance is deleted
    rds_client.wait_until(:db_instance_deleted, db_instance_identifier: db_instance_identifier)

    # Delete the security group
    ec2_client = Aws::EC2::Client.new(region: region)
    ec2_client.delete_security_group({
      group_id: security_group_id
    })
  end

  it 'creates a security group, attaches it to the RDS instance, and tags the RDS instance' do
    security_group_id = aws_manager.security_group_id

    # Check that the security group was created
    ec2_client = Aws::EC2::Client.new(region: region)
    security_group = ec2_client.describe_security_groups({
      group_ids: [security_group_id]
    }).security_groups.first
    expect(security_group).not_to be_nil

    aws_manager.modify_rds_instance

    # Check that the security group is attached to the RDS instance
    rds_client = Aws::RDS::Client.new(region: region)
    rds_instance = rds_client.describe_db_instances({
      db_instance_identifier: db_instance_identifier
    }).db_instances.first
    expect(rds_instance.vpc_security_groups.any? { |sg| sg.vpc_security_group_id == security_group_id }).to be_truthy

    aws_manager.tag_rds_instance

    # Check that the RDS instance is tagged
    rds_tags = rds_client.list_tags_for_resource({
      resource_name: rds_instance.db_instance_arn
    }).tag_list
    expect(rds_tags.any? { |tag| tag.key == 'Name' && tag.value == 'my-tag' }).to be_truthy
  end
end
