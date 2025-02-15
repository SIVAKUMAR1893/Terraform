#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012 Ansible
#
# This script will dynamically generate an inventory based on EC2 instances
# on AWS.

import sys
import boto3
import argparse
import json

# Set up the AWS session and EC2 resource
def get_ec2_instances(region):
    ec2 = boto3.client('ec2', region_name=region)
    response = ec2.describe_instances(
        Filters=[{
            'Name': 'tag:Role',
            'Values': ['master', 'slave']  # Only include master and slave instances
        }]
    )
    return response['Reservations']

# Grouping logic to divide instances based on tags
def group_instances(instances):
    inventory = {
        'jenkins_master': {
            'hosts': [],
            'vars': {}
        },
        'jenkins_slave': {
            'hosts': [],
            'vars': {}
        }
    }

    # Process EC2 instances and add them to the respective groups
    for reservation in instances:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            instance_ip = instance.get('PublicIpAddress', None)

            # Grouping by 'Role' tag
            if 'Tags' in instance:
                for tag in instance['Tags']:
                    if tag['Key'] == 'Role' and tag['Value'] == 'master':
                        inventory['jenkins_master']['hosts'].append(instance_ip)
                    elif tag['Key'] == 'Role' and tag['Value'] == 'slave':
                        inventory['jenkins_slave']['hosts'].append(instance_ip)
    
    return inventory

# Main execution
def main():
    parser = argparse.ArgumentParser(description='Generate dynamic inventory from AWS EC2 instances.')
    parser.add_argument('--region', help='AWS region', required=True)
    args = parser.parse_args()

    instances = get_ec2_instances(args.region)
    inventory = group_instances(instances)

    # Print the inventory as JSON
    print(json.dumps(inventory, indent=2))

if __name__ == '__main__':
    main()
