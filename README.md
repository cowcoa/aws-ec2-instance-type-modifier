## AWS EC2 instances type modifier
Batch modify the specified AWS EC2 instances with the specified instance type.
NOTE: Modify the EC2 instance type will cause these instances to be stopped and restarted.

## Usage
1. Install and configure AWS CLI environment:
   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html
2. Run script:
    ```sh
    ./ec2_instances_type_modifier.sh
    Usage: ./ec2_instances_type_modifier.sh -i instance_id_1,instance_id_2,... -t m5.xlarge -r ap-northeast-2
        -i List of EC2 instance IDs that will be replaced.
        -t Target EC2 instance type that will be modified.
        -r AWS region where EC2 instances are located.
    ```
