from diagrams import Diagram, Cluster
from diagrams.aws.compute import EC2
from diagrams.aws.network import VPC, InternetGateway, Route53
from diagrams.aws.storage import S3
from diagrams.aws.management import Cloudwatch
from diagrams.aws.general import Users, Client
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.vcs import Github
from diagrams.aws.network import PublicSubnet

# Define graph attributes for horizontal layout
graph_attr = {
    "splines": "ortho",  # Straight lines
    "rankdir": "LR",     # Left to Right layout
    "nodesep": "1.0",    # Horizontal node separation
    "ranksep": "1.0"     # Vertical separation between ranks
}

with Diagram("AWS Landing Zone Architecture", 
             show=False, 
             direction="LR",
             graph_attr=graph_attr,
             filename="aws_landing_zone_architecture",
             outformat="png"):

    # Developer/User section
    dev = Users("Developer")
    github = Github("GitHub Repo")
    ci_cd = GithubActions("CI/CD Pipeline")
    
    # Connect developer flow
    dev >> github >> ci_cd

    # AWS Resources - Networking
    with Cluster("AWS Resources"):
        igw = InternetGateway("Internet Gateway")
        
        with Cluster("VPC"):
            vpc = VPC("poc-<env>-vpc")
            
            with Cluster("Public Subnets"):
                subnet1 = PublicSubnet("poc-pre-prod-subnet1")
                subnet2 = PublicSubnet("poc-prod-subnet1")
                subnet3 = PublicSubnet("poc-prod-subnet2")
                
                route_table = Route53("Route Table")
                
                # Compute instances
                with Cluster("EC2 Instances"):
                    ec2_1 = EC2("poc-pre-prod-instance1")
                    ec2_2 = EC2("poc-prod-instance1")
                    ec2_3 = EC2("poc-prod-instance2")
        
        # Logging resources
        with Cluster("Logging"):
            s3 = S3("poc-prod-logs-bucket")
            cw = Cloudwatch("CloudWatch Logs")
            flow_logs = Cloudwatch("VPC Flow Logs")

    # Connect networking components
    vpc - igw
    vpc - subnet1 >> route_table >> igw
    vpc - [subnet2, subnet3] >> route_table
    
    # Connect compute to subnets
    subnet1 - ec2_1
    subnet2 - ec2_2
    subnet3 - ec2_3
    
    # Connect logging
    vpc >> flow_logs >> [s3, cw]
    
    # Connect CI/CD to infrastructure
    ci_cd >> vpc
    ci_cd >> ec2_1
    ci_cd >> [ec2_2, ec2_3]
    ci_cd >> [s3, cw]