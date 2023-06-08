require 'aws_manager'

describe AWSManager do
  let(:ec2_client) { instance_double("Aws::EC2::Client") }
  let(:rds_client) { instance_double("Aws::RDS::Client") }
  let(:aws_manager) { AWSManager.new(region: 'us-west-2', db_instance_identifier: 'my-rds-instance', cidr_block: '0.0.0.0/0') }

  before do
    allow(Aws::EC2::Client).to receive(:new).and_return(ec2_client)
    allow(Aws::RDS::Client).to receive(:new).and_return(rds_client)
  end

  describe '#security_group_id' do
    context 'when the security group does not exist' do
      before do
        allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: []))
        allow(ec2_client).to receive(:create_security_group).and_return(double(group_id: 'sg-123'))
        allow(ec2_client).to receive(:authorize_security_group_ingress)
        allow(ec2_client).to receive(:create_tags)
      end

      it 'creates a new security group' do
        expect(aws_manager.security_group_id).to eq('sg-123')
      end
    end

    context 'when the security group already exists' do
      before do
        allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
      end

      it 'returns the id of the existing security group' do
        expect(aws_manager.security_group_id).to eq('sg-456')
      end
    end
  end

  describe '#modify_rds_instance' do
    context 'when the security group is not attached to the RDS instance' do
      before do
        allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
        allow(rds_client).to receive(:describe_db_instances).and_return(double(db_instances: [double(vpc_security_groups: [])]))
        allow(rds_client).to receive(:modify_db_instance).and_return(double(db_instance_arn: 'arn-123'))
      end

      it 'modifies the RDS instance' do
        expect(aws_manager.modify_rds_instance.db_instance_arn).to eq('arn-123')
      end
    end

    context 'when the security group is already attached to the RDS instance' do
      before do
        allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
        allow(rds_client).to receive(:describe_db_instances).and_return(double(db_instances: [double(vpc_security_groups: [double(vpc_security_group_id: 'sg-456')])]))
      end

      it 'does not modify the RDS instance' do
        expect(rds_client).not_to receive(:modify_db_instance)
        aws_manager.modify_rds_instance
      end
    end
  end

  describe '#tag_rds_instance' do
    context 'when the RDS instance is not tagged' do
      before do
        allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
        allow(rds_client).to receive(:describe_db_instances).and_return(double(db_instances: [double(db_instance_arn: 'arn-123', tag_list: [])]))
        allow(rds_client).to receive(:add_tags_to_resource)
      end

      it 'tags the RDS instance' do
        expect { aws_manager.tag_rds_instance }.not_to raise_error
      end
    end

    context 'when the RDS instance is already tagged' do
      before do
        allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
        allow(rds_client).to receive(:describe_db_instances).and_return(double(db_instances: [double(db_instance_arn: 'arn-123', tag_list: [double(key: 'Name', value: 'my-tag')])]))
      end

      it 'does not tag the RDS instance again' do
        expect(rds_client).not_to receive(:add_tags_to_resource)
        aws_manager.tag_rds_instance
      end
    end
  end
end
