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
    before do
      allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
      allow(rds_client).to receive(:modify_db_instance).and_return(double(db_instance_arn: 'arn-123'))
    end

    it 'modifies the RDS instance' do
      expect(aws_manager.modify_rds_instance.db_instance_arn).to eq('arn-123')
    end
  end

  describe '#tag_rds_instance' do
    before do
      allow(ec2_client).to receive(:describe_security_groups).and_return(double(security_groups: [double(group_id: 'sg-456')]))
      allow(rds_client).to receive(:modify_db_instance).and_return(double(db_instance_arn: 'arn-123'))
      allow(rds_client).to receive(:add_tags_to_resource)
    end

    it 'tags the RDS instance' do
      expect { aws_manager.tag_rds_instance }.not_to raise_error
    end
  end
end
