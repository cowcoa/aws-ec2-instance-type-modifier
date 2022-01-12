#!/bin/bash
# Modify the specified AWS EC2 instances with the specified instance type.
# NOTE: Modify the EC2 instance type will cause these instances to be stopped and restarted.

help_function()
{
    echo ""
    echo "Usage: $0 -i instance_id_1,instance_id_2,... -t m5.xlarge -r ap-northeast-2"
    echo -e "\t-i List of EC2 instance IDs that will be replaced."
    echo -e "\t-t Target EC2 instance type that will be modified."
    echo -e "\t-r AWS region where EC2 instances are located."
    echo ""
    exit 1 # Exit script after printing help.
}

while getopts "i:t:r:" opt
do
    case "$opt" in
        i ) instance_id_list="$OPTARG" ;;
        t ) target_instance_type="$OPTARG" ;;
        r ) deployment_region="$OPTARG" ;;
        ? ) help_function ;; # Print help_function in case parameter is non-existent.
    esac
done

# Print help_function in case parameters are empty.
if [ -z "$instance_id_list" ] || [ -z "$target_instance_type" ] || [ -z "$deployment_region" ]
then
    echo "Some or all of the parameters are empty.";
    help_function
fi

main()
{
    echo ""

    # Check if the specified instance type is valid.
    instance_type_info="$(aws ec2 describe-instance-types \
                        --filters Name=instance-type,Values=$target_instance_type \
                        --region $deployment_region \
                        --query 'InstanceTypes[0]')"

    if [ "$instance_type_info" = null ]; then
        echo "'$target_instance_type' is not a valid ec2 instance type."
        exit -1
    fi

    # Convert instance_id_list argument into an array.
    IFS=',' read -r -a array <<< "$instance_id_list"

    # Check if the specified ec2 instance exists.
    for instance_id in "${array[@]}"
    do
        result="$(aws ec2 wait instance-exists \
                --instance-ids $instance_id \
                --region $deployment_region 2>/dev/null)"
        result="$(echo $?)"

        if [ $result != 0 ]; then
            echo "EC2 instance '$instance_id' does not exist."
            exit -1
        fi
    done

    # Stop each ec2 instance, modify instance type, and start again.
    for instance_id in "${array[@]}"
    do
        echo "Stop EC2 instance '$instance_id'..."
        result="$(aws ec2 stop-instances \
                --instance-ids $instance_id \
                --region $deployment_region \
                --query 'StoppingInstances[0].CurrentState.Code')"

        while [ $result != 80 ]; do
            case $result in
            0 ) echo "EC2 instance '$instance_id' is pending, please wait..." ;;
            16 ) echo "EC2 instance '$instance_id' is running, please wait..." ;;
            32 ) echo "EC2 instance '$instance_id' is shutting-down, please wait..." ;;
            64 ) echo "EC2 instance '$instance_id' is stopping, please wait..." ;;
            esac

            # Sleep for a while and check again. 
            sleep 15
            result="$(aws ec2 describe-instances \
                    --instance-ids $instance_id \
                    --region $deployment_region \
                    --query 'Reservations[0].Instances[0].State.Code')"
        done

        echo "Modify EC2 instance '$instance_id' to '$target_instance_type'."
        result="$(aws ec2 modify-instance-attribute \
                --instance-id $instance_id \
                --instance-type Value=$target_instance_type \
                --region $deployment_region 2>/dev/null)"

        # Check the modification result.
        result="$(aws ec2 describe-instances \
                --instance-id $instance_id \
                --region $deployment_region \
                --output text \
                --query 'Reservations[0].Instances[0].InstanceType')"

        if [ "$result" != $target_instance_type ]; then
            echo "Modify EC2 instance '$instance_id' to '$target_instance_type' failed."
            exit -1
        fi
        echo "Modification Done"

        echo "Start EC2 instance '$instance_id'."
        result="$(aws ec2 start-instances \
                --instance-id $instance_id \
                --region $deployment_region)"
        echo "Successfully modified EC2 instance '$instance_id' to '$target_instance_type'"
        echo ""
    done
}

# Prompt for Yes/No input.
while true; do
    echo ""
    echo "Modify the instance type of [${instance_id_list}] to '${target_instance_type}' will cause these instances to be stopped and restarted"
    read -p "Is this ok [y/N]:" yn
    case $yn in
        [Yy]* ) main; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
