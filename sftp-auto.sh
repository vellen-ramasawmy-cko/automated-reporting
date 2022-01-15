#!/bin/bash

# Reference: https://checkout.atlassian.net/wiki/spaces/CHEC/pages/4396811491/034+-+Create+an+SFTP+account+on+AWS+for+NAS+Merchant+Reporting
# https://spin.atomicobject.com/2021/06/08/jq-creating-updating-json/
# https://www.py4u.net/discuss/1192644
# https://aws.amazon.com/blogs/storage/simplify-your-aws-sftp-structure-with-chroot-and-logical-directories/
# https://docs.aws.amazon.com/fr_fr/cli/latest/reference/transfer/create-user.html

# --tags unavailable, solution update awscli to latest version: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-upgrade
# aws cli version used 2.3.3

#AWS account
#export AWS_PROFILE=cko-playground

## Pre-checks

# Ensure that the folder is present in the S3 bucket merlin-financial-reports-prod on cko-prod environment.
# Ensure that there are no policies and role with the same name that are already present on cko-prod-legacy.
# Ensure that there are no Route 53 entries with the same name that are already present on cko-prod-legacy.
# Ensure that there are no AWS Transfer Family service entries with the same name that are already present on cko-prod-legacy.

##  Variables
# Merchant name
#loky

echo ""
echo ">> Please note that this is the automation for SFTP Automated Reporting. <<"
echo "IMPORTANT: Merchant Name and Merchant ID will be used as follows:

- New user on AWS Transfer Family -->  merchantid
- Entry on Route53                -->  merchantname.sftp.checkout.com
- S3 Bucket                       -->  sftp-aws-cko/merchantid
"

echo ""
read -p "Enter merchant name to be used: " merchantname

echo ""
read -p "Enter merchant account id to be used: " merchantid


## Validation to be included

echo ""
read -p "Enter merchant name to be used as AWS Tags, e.g Curve OS Ltd: " merchantnametag
#merchantnametag="Merchant Test"

# Change number
echo ""
read -p "Enter the change number, e.g CHN-1234: " changenumber
#changenumber="1234"

# Creator
echo ""
read -p "Enter the creator name for AWS Tags, e.g Vellen Ramasawmy: " creator
#creator="Vellen"

# Purpose
echo ""
read -p "Enter the purpose of this change, e.g Automated reporting: " purpose
#purpose="Automated Reporting"

# Requester
echo ""
read -p "Enter the name of the requester, e.g Vellen Ramasawmy: " requester
#requester="Vellen"

# SSh Key
echo ""
read -p "Enter the SSH Key: " public_key

clear 

echo "Merchant name to be used: $merchantname"
echo "Merchant id to be used: $merchantid"
echo "AWS Tag for merchant name: $merchantnametag"
echo "Change number: $changenumber"
echo "Creator: $creator"
echo "Purpose of this change: $purpose"
echo "Requester: $requester"
echo "SSH key: $public_key"

echo ""
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo ""

playground_server_id="s-e1027b976d2b4e67b"

#home_directory_mapping="{ "Entry": "/", "Target": "/sftp-test-nb/test" }"
home_directory_mapping='Entry=/,Target=/sftp-test-vr/'$merchantid''

echo ""
echo ">> Creating user on AWS Transfer Family <<"
echo ""

#aws --profile cko-playground transfer create-user \
#    --server-id $playground_server_id \
#    --user-name $merchantid \
#    --role aws-sftp \
#    --policy aws-sftp  \
#    --home-directory-type LOGICAL \
#    --home-directory-mappings $home_directory_mapping \
#    --ssh-public-key-body "$public_key" \
#    --tags "Key"="Change","Value"="$changenumber" \
#           "Key"="Creator","Value"="$creator" \
#           "Key"="Merchant","Value"="$merchantnametag" \
#           "Key"="Purpose","Value"="$purpose" \
#           "Key"="Requester","Value"="$requester"

# Creates Folder on S3 Bucket

echo ""
echo ">> Creating Folder on S3 Bucket <<"
echo ""

#aws s3api put-object --bucket vellen-sftp-test --key $merchantid/

# Creates route 53 records 

echo ""
echo ">> Creating Route 53 record <<"
echo ""

#dns=$playground_server_id.server.transfer.eu-west-1.amazonaws.com

# Update JSON policy with merchant name folder line 22
cp record.json $merchantname-record.json
tmp=$(mktemp)
cat record.json | jq --arg name "$merchantname.cko-playground.ckotech.co" '.Changes[0].ResourceRecordSet.Name |= $name' > "$tmp" && mv "$tmp" $merchantname-record.json
cat $merchantname-record.json | jq --arg dns "$dns" '.Changes[0].ResourceRecordSet.ResourceRecords[0].Value |= $dns'> "$tmp" && mv "$tmp" $merchantname-record.json

cat $merchantname-record.json

# hosted zone on playground cko-playground.ckotech.co
#aws --profile cko-playground route53 change-resource-record-sets --hosted-zone-id Z08800003NARTIMTZS14F --change-batch file://$merchantname-record.json

# deleting tmp files
rm $merchantname-record.json



