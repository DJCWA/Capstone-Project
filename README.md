# Delivery5Demo


Cloud Architecture Diagram
 <img width="3543" height="3640" alt="Cloud Architecture Diagram" src="https://github.com/user-attachments/assets/e53bce2b-bb53-4876-8e0b-d0268b4d504c" />


Cloud Architecture Explanation
1.	The updated architecture provides a highly available, fault-tolerant, and secure AWS Disaster Recovery environment deployed across multiple Availability Zones.
2.	End users access the web application through Route 53, which directs traffic to the Application Load Balancer (ALB) located in the public subnets. The ALB distributes HTTPS traffic evenly across Frontend EC2 instances from an Auto Scaling Group (ASG) running in AZ-A and AZ-B, ensuring scalability and resilience.
3.	Each frontend instance communicates privately with Backend EC2 instances (also in ASGs) within the same availability zone to process application logic and API requests.
4.	The backend securely connects to Amazon RDS (PostgreSQL) hosted in private DB subnets. Data is synchronously replicated from the RDS Primary (in DB Subnet A) to the RDS Standby (in DB Subnet B) for high availability.
5.	AWS Backup continuously backs up RDS snapshots to an Amazon S3 Bucket for long-term retention and regional recovery.
6.	AWS Backup regularly copies database snapshots to an S3 Bucket for long-term retention.
7.	Administrative access to private resources is controlled through a Bastion Host in the public subnet, while outbound internet traffic from private instances is routed via a NAT Gateway.
This design leverages multi-AZ deployment, Auto Scaling, IAM least-privilege policies, encryption at rest (using KMS), and CloudWatch monitoring to ensure reliability, scalability, and secure disaster-recovery operations.






CI/CD Workflow Diagram
 <img width="1370" height="4016" alt="CICD Workflow Diagram" src="https://github.com/user-attachments/assets/8da5f26b-b045-4965-9528-fad4344796c0" />

CI/CD Workflow Explanation
The DevOps pipeline automates the entire software delivery lifecycle from code commit to production deployment.
Source Stage: Developers push code to GitHub or AWS CodeCommit repositories. A commit event triggers the pipeline.
Build Stage: AWS CodeBuild compiles source code, installs dependencies, and packages artifacts. Build logs and artifacts are stored for later stages.
Test Stage: CodeBuild runs unit and integration tests, followed by static analysis and security scans. Only validated builds move forward.
Deploy Stage: AWS CodeDeploy deploys to a Staging Environment for initial validation. A Manual Approval Gate ensures human review before production release.
Production Stage: Upon approval, CodeDeploy automatically rolls out to the Production Environment, integrating with Auto Scaling Groups and Lambda as needed.
This workflow provides a secure, controlled, and automated deployment process with testing and approvals to ensure system reliability and quality.



github-actions
![action](https://github.com/user-attachments/assets/b3137467-9919-494a-90c0-4365060c7434)

EC2
![ec2](https://github.com/user-attachments/assets/9f40ae83-8143-412d-b4dd-f58647cea5e9)

IAM
![IAM](https://github.com/user-attachments/assets/fbfc2563-2b25-4b24-a487-e1c251e344ba)

S3
![S3](https://github.com/user-attachments/assets/b375b3ca-3eba-462b-a971-b06f3d65c8cb)

VPC
![vpc](https://github.com/user-attachments/assets/edc24f99-baf9-43a3-81f8-b62f36386ab5)

"# Capstone-Project" 
"# Capstone-Project" 
