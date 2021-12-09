#/bin/bash -ex

# CONTS
VHT_IMAGE_VERSION=1.0.0
IAM_INSTANCE_PROFILE=Proj-s3-orta-vht-role
INSTANCE_TYPE=t2.micro
S3_BUCKET_NAME=gh-orta-vht
S3_KEYPREFIX=ssm
SECURITY_GROUP_ID=sg-04022e04e91197ce3
SUBNET_ID=subnet-00455495b268076f0

ami_id=$(python3 vht_cli.py -v INFO --get-ami-id $VHT_IMAGE_VERSION)
echo "VHT AMI ID = $ami_id"

instance_id=$(python3 vht_cli.py -v INFO --create-ec2-instance \
    ImageId="$ami_id" \
    InstanceType="$INSTANCE_TYPE" \
    MaxCount=1 \
    MinCount=1 \
    SecurityGroupIds=["${SECURITY_GROUP_ID}"] \
    SubnetId="$SUBNET_ID"  \
    IamInstanceProfile="{'Name': '$IAM_INSTANCE_PROFILE'}")
echo "Instance ID = $instance_id"

command_id=$(python3 vht_cli.py -v INFO --send-ssm-shell-command \
    InstanceId=$instance_id \
    commandList='ls -la' \
    s3BucketName=$S3_BUCKET_NAME \
    s3KeyPrefix=$S3_KEYPREFIX)
echo "Command ID = $command_id"

command_id_status=$(python3 vht_cli.py -v INFO --get-ssm-command-id-status $command_id)
echo "Command ID status = $command_id_status"

stdout_s3_key=$(python3 vht_cli.py -v INFO --get-s3-ssm-command-id-key \
    InstanceId=$instance_id \
    CommandId=$command_id \
    s3KeyPrefix=$S3_KEYPREFIX \
    OutputType=stdout)
echo "Stdout S3 Key Location = $stdout_s3_key"

stderr_s3_key=$(python3 vht_cli.py -v INFO --get-s3-ssm-command-id-key \
    InstanceId=$instance_id \
    CommandId=$command_id \
    s3KeyPrefix=$S3_KEYPREFIX \
    OutputType=stderr)
echo "Stderr S3 Key Location = $stderr_s3_key"

python3 vht_cli.py -v INFO --download-s3-file \
    s3BucketName=$S3_BUCKET_NAME \
    key=$stdout_s3_key \
    filename=stdout

python3 vht_cli.py -v INFO --download-s3-file \
    s3BucketName=$S3_BUCKET_NAME \
    key=$stderr_s3_key \
    filename=stderr

python3 vht_cli.py -v INFO --get-s3-file-content \
    s3BucketName=$S3_BUCKET_NAME \
    key=$stdout_s3_key

python3 vht_cli.py -v INFO --get-s3-file-content \
    s3BucketName=$S3_BUCKET_NAME \
    key=$stderr_s3_key

instance_state=$(python3 vht_cli.py -v INFO --get-ec2-instance-state $instance_id)
echo "Instance State = $instance_state"

python3 vht_cli.py -v INFO --stop-ec2-instance $instance_id
python3 vht_cli.py -v INFO --start-ec2-instance $instance_id
python3 vht_cli.py -v INFO --terminate-ec2-instance $instance_id
