#!/bin/bash

# Reference: https://checkout.atlassian.net/wiki/spaces/CHEC/pages/4396811491/034+-+Create+an+SFTP+account+on+AWS+for+NAS+Merchant+Reporting
# https://spin.atomicobject.com/2021/06/08/jq-creating-updating-json/
# https://www.py4u.net/discuss/1192644
# https://aws.amazon.com/blogs/storage/simplify-your-aws-sftp-structure-with-chroot-and-logical-directories/
# https://docs.aws.amazon.com/fr_fr/cli/latest/reference/transfer/create-user.html

# --tags unavailable, solution update awscli to latest version: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-upgrade
# aws cli version used 2.3.3

#AWS account
export AWS_PROFILE=cko-playground

## Pre-checks

# Ensure that there are no Route 53 entries with the same name that are already present on cko-prod-legacy.
# Ensure that there are no AWS Transfer Family service entries with the same name that are already present on cko-prod-legacy.
# Ensure that there are no folder on S3 with the same name that are already present on cko-prod-legacy.

##  Variables
# Merchant name

echo ""
echo ">> Please note that this is the automation for SFTP Automated Reporting and Token Migration. <<"
echo "IMPORTANT: Merchant Name is used for Token Migration and Merchant Account Id and Merchant Name is used for automated reporting:


- New user on AWS Transfer Family -->  merchantid
- Entry on Route53                -->  merchantname.sftp.checkout.com
- S3 Bucket                       -->  sftp-aws-cko/merchantid
"
echo ""
read -p "Enter the type of SFTP (Token or Automated): " accounttype


if [[ $accounttype == token ]];
then
    echo ""
    read -p "Enter merchant name to be used: " merchantname
    s3folder=$merchantname
    sftpuser=$merchantname

elif [[ $accounttype == automated ]]
    then
        
        echo ""
        read -p "Enter merchant name to be used: " merchantname

        echo ""
        read -p "Enter merchant account id to be used: " merchantid
        s3folder=$merchantid
        sftpuser=$merchantid
else
    echo "Invalid Account Type"
    exit
fi

## Validation
# Merchant name variable validation, checks if variable is empty, or contains spaces.
re="[[:space:]]+"

if [ -z "$merchantname" ]
then
    echo ""
    echo ">> Merchant name cannot be empty, please refer to the above example. <<"
    exit
else
    #echo "Variable merchant name is not empty"
    
    if [[ $merchantname =~ $re ]]; then
        echo ""
        echo ">> Merchant name cannot contain spaces, please refer to the above example. <<"
        exit
    fi

fi

echo ""
read -p "Enter merchant name to be used as AWS Tags, e.g Curve OS Ltd: " merchantnametag
#merchantnametag="Merchant Test"

# Change number
echo ""
read -p "Enter the change number, e.g CHN-1234: " changenumber
#changenumber="1234"

# Creator
echo ""
read -p "Enter the creator name for AWS Tags, e.g Nirvan: " creator
#creator="Vellen"

# Purpose
echo ""
read -p "Enter the purpose of this change, e.g Automated Reporting: " purpose
#purpose="Automated Reporting"

# Requester
echo ""
read -p "Enter the name of the requester, e.g Nirvan: " requester
#requester="Vellen"

# SSh Key
echo ""
read -p "Enter the SSH Key: " public_key

clear 

echo "Merchant name to be used: $merchantname"
echo "Merchant id to be used: $merchantid"

echo ">> AWS Tag Used <<"

echo "AWS Tag for merchant name: $merchantnametag"
echo "Change number: $changenumber"
echo "Creator: $creator"
echo "Purpose of this change: $purpose"
echo "Requester: $requester"
echo "SSH key: $public_key"

echo ""
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo ""


playground_server_id="s-a3c053263ced44f5b"

home_directory_mapping='Entry=/,Target=/sftp-test-nb/'$s3folder''
home_directory='/sftp-test-nb/'$s3folder''
role_arn="arn:aws:iam::528130383285:role/aws-sftp-nb-test"
policy_arn="arn:aws:iam::528130383285:policy/aws-sftp-policy-nb-test"

# Creates Folder on S3 Bucket

echo ""
echo ">> Creating Folder on S3 Bucket <<"
echo ""

aws s3api put-object --bucket sftp-test-nb --key $s3folder/


echo ""
echo ">> Creating user on AWS Transfer Family <<"
echo ""

aws --profile cko-playground transfer create-user \
    --server-id $playground_server_id \
    --user-name $sftpuser \
    --role $role_arn \
    --policy file://policy.json\
    --home-directory $home_directory \
    --ssh-public-key-body "$public_key" \
    --tags "Key"="Change","Value"="$changenumber" \
           "Key"="Creator","Value"="$creator" \
           "Key"="Merchant","Value"="$merchantnametag" \
           "Key"="Purpose","Value"="$purpose" \
           "Key"="Requester","Value"="$requester"

# Creates route 53 records 

echo ""
echo ">> Creating Route 53 record <<"
echo ""

dns=$playground_server_id.server.transfer.eu-west-1.amazonaws.com

# Update JSON policy with merchant name folder line 22
cp record.json $merchantname-record.json
tmp=$(mktemp)
cat record.json | jq --arg name "$merchantname.cko-playground.ckotech.co" '.Changes[0].ResourceRecordSet.Name |= $name' > "$tmp" && mv "$tmp" $merchantname-record.json
cat $merchantname-record.json | jq --arg dns "$dns" '.Changes[0].ResourceRecordSet.ResourceRecords[0].Value |= $dns'> "$tmp" && mv "$tmp" $merchantname-record.json

cat $merchantname-record.json

# hosted zone on playground cko-playground.ckotech.co
aws --profile cko-playground route53 change-resource-record-sets --hosted-zone-id Z08800003NARTIMTZS14F --change-batch file://$merchantname-record.json


echo -e "\n>> POST-CHECKS <<"

echo -e "\nUser on AWS Transfer Family:"
aws transfer list-users --server-id $playground_server_id | grep $sftpuser

echo -e "\nRecord on Route53:"
aws route53 list-resource-record-sets --hosted-zone-id Z08800003NARTIMTZS14F | grep $merchantname

echo -e "\nFolder in S3 Bucket:"
aws s3 ls s3://sftp-test-nb | grep $s3folder


# deleting tmp files
rm $merchantname-record.json