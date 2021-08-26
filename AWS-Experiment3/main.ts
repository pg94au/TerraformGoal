import { Construct } from "constructs";
import { App, TerraformStack, TerraformOutput } from "cdktf";
import { AwsProvider, Instance, InternetGateway, RouteTable, RouteTableAssociation, SecurityGroup, Subnet, Vpc } from './.gen/providers/aws';

class MyStack extends TerraformStack {
  constructor(scope: Construct, name: string) {
    super(scope, name);

    // define resources here
    new AwsProvider(this, 'aws', {
      region: 'ca-central-1'
    });

    const vpc = new Vpc(this, "cdktf-vpc", {
      cidrBlock: "10.0.0.0/16",
      enableDnsHostnames: true,
      enableDnsSupport: true,
      tags: { "Name": "CDKTF_VPC" }
    });

    var internetGateway = new InternetGateway(this, "cdktf-ig", {
      vpcId: vpc.id,
      tags: { "Name": "CDKTF_IG" }
    });

    var routeTable = new RouteTable(this, "cdktf-rt", {
      vpcId: vpc.id,
      route: [{
        cidrBlock: "0.0.0.0/0",
        gatewayId: internetGateway.id
      }]
    })

    var subnet = new Subnet(this, "cdktf-public-subnet-1a", {
      vpcId: vpc.id,
      cidrBlock: "10.0.3.0/24",
      availabilityZone: "ca-central-1a",
      tags: { "Name": "CDKTF_Public1a" }
    });

    new RouteTableAssociation(this, "cdktf-public-subnet-1a-rta", {
      subnetId: subnet.id,
      routeTableId: routeTable.id
    });

    var securityGroup = new SecurityGroup(this, "cdktf-allow-ssh-from-home", {
      name: "cdktf-allow-ssh-from-home",
      description: "Allow SSH from home IP",
      vpcId: vpc.id,
      ingress: [{
        fromPort: 22,
        toPort: 22,
        protocol: "tcp",
        cidrBlocks: ["206.248.172.36/32"],
      }],
      tags: { "Name": "CDKTF-allow-ssh-from-home" }
    });

    var instance = new Instance(this, "cdktf-instance", {
      ami: "ami-0801628222e2e96d6",
      instanceType: "t2.nano",
      subnetId: subnet.id,
      associatePublicIpAddress: true,
      keyName: "MyKeyPair",
      vpcSecurityGroupIds: [securityGroup.id],
      tags: { "Name": "CDKTF_Instance" }
    });

    new TerraformOutput(this, "public_dns", {
      value: instance.publicDns
    });

    new TerraformOutput(this, "public_ip", {
      value: instance.publicIp
    });
  }
}

const app = new App();
new MyStack(app, "AWS-Experiment3");
app.synth();
