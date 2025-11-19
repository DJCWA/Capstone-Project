#!/bin/bash
yum update -y
yum install python3-pip -y
pip3 install flask boto3

cat <<EOF >/home/ec2-user/app.py
from flask import Flask
import boto3, datetime

app = Flask(__name__)

@app.route("/")
def home():
    return "Backend running"

@app.route("/failover")
def failover():
    s3 = boto3.client('s3')
    filename = f"failover-{datetime.datetime.now()}.txt"
    s3.put_object(
        Bucket="group6-dr-demo-bucket",
        Key=filename,
        Body="Failover simulation success"
    )
    return "Failover logged into S3"

app.run(host="0.0.0.0", port=5000)
EOF

python3 /home/ec2-user/app.py &
