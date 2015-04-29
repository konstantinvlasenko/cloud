Param(
  [parameter(Mandatory=$true)]
  [string]
  $ami,
  [parameter(Mandatory=$true)]
  [string]
  $type
)

Set-DefaultAWSRegion $env:AWSRegion

if($env:EC2UserData) { $userdata64 = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( $env:EC2UserData ) ) }
if($env:EC2KeyName -eq $null) { $env:EC2KeyName = (Get-EC2KeyPair)[0].KeyName }

$role = Get-IAMInstanceProfileForRole $env:IAMRole

if($env:SubnetId)
{
  $sg = new-object Amazon.EC2.Model.GroupIdentifier
  $sg.GroupId = $env:SecurityGroup
  $spot =  Request-EC2SpotInstance -SpotPrice $env:SpotPrice -LaunchSpecification_InstanceType $type -LaunchSpecification_ImageId $ami -LaunchSpecification_AllSecurityGroup $sg -IamInstanceProfile_Arn $role.Arn -LaunchSpecification_UserData $userdata64 -LaunchSpecification_SubnetId $env:SubnetId -LaunchSpecification_KeyName $env:EC2KeyName
}
else
{
  $spot =  Request-EC2SpotInstance -SpotPrice $env:SpotPrice -LaunchSpecification_InstanceType $type -LaunchSpecification_ImageId $ami -LaunchSpecification_SecurityGroup $env:SecurityGroup -IamInstanceProfile_Arn $role.Arn -LaunchSpecification_UserData $userdata64 -LaunchSpecification_KeyName $env:EC2KeyName
}

$spot.SpotInstanceRequestId