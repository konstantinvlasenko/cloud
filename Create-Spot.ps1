Param(
  [parameter(Mandatory=$true)]
  [string]
  $ami,
  [parameter(Mandatory=$true)]
  [string]
  $type,
  [parameter(Mandatory=$true)]
  [string]
  $iamRoleName,
  [parameter(Mandatory=$true)]
  [string]
  $key,
  [parameter(Mandatory=$true)]
  [string]
  $domain,
  [string]
  $subdomain = 'www',
  [string]
  $region = 'us-east-1',
  [string]
  $user_data_file
)

Set-DefaultAWSRegion $region
if($user_data_file)
{
  $userdata = gc $user_data_file -Raw
  $userdata64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
}
$role = Get-IAMInstanceProfileForRole $iamRoleName
$spot =  Request-EC2SpotInstance -SpotPrice 0.01 -LaunchSpecification_InstanceType $type -LaunchSpecification_ImageId $ami -LaunchSpecification_SecurityGroups 'AD.FE' -LaunchSpecification_IamInstanceProfile_Arn $role.Arn -LaunchSpecification_UserData $userdata64 -LaunchSpecification_KeyName $key -LaunchSpecification_Placement_AvailabilityZone us-east-1c

"waiting for spot request fulfilment..." | Out-Default
do {
  Sleep 30
  # update spot requests information
  $spot = Get-EC2SpotInstanceRequest $spot.SpotInstanceRequestId
  $spot.Status.Message | Out-Default
} while( $spot.State -eq 'open' )

# set instance name
$config = @{ DomainName = $domain }
$name = "$subdomain.$domain"
$tag = new-object Amazon.EC2.Model.Tag
$tag.Key = "Name"
$tag.Value = $name
New-EC2Tag -ResourceId $spot.InstanceId -Tag $tag

"wait for instances running..." | Out-Default 
do {
  Sleep 30
} while( (Get-EC2InstanceStatus $spot.InstanceId).InstanceState.Name -ne 'running' )

"wait for reachability test..." | Out-Default
do {
  Sleep 30
} while( (Get-EC2InstanceStatus $spot.InstanceId).Status.Status.Value -ne 'ok' )

# get instances
$instance = (Get-EC2Instance $spot.InstanceId).RunningInstance

# update R53
if($subdomain -eq 'www') { 
  # use PublicIpAddress as we want to create the top domain alias (you can use only A record)
  .\Register-CNAME.ps1 $config $name $instance.PublicIpAddress 'A'
}
else {
  .\Register-CNAME.ps1 $config $name $instance.PublicDnsName
}


