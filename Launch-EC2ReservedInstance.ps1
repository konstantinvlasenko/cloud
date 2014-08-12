Param(
  [parameter(Mandatory=$true)]
  $ReservedInstancesId,
  [parameter(Mandatory=$true)]
  $ami,
  [parameter(Mandatory=$true)]
  $user_data_file,
  [parameter(Mandatory=$true)]
  $key,
  [parameter(Mandatory=$true)]
  $ec2SecurityGroup,
  [parameter(Mandatory=$true)]
  $iamRoleName
)

$ri = Get-EC2ReservedInstance $ReservedInstancesId
$type = $ri.InstanceType                          # Instance type from the reservation
$az = $ri.AvailabilityZone                        # Availability Zone from the reservation

$userdata = gc $user_data_file -Raw
$userdata64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))

$instance = (New-EC2Instance -ImageId $ami -MinCount 1 -MaxCount 1 -InstanceType $type -SecurityGroupId $ec2SecurityGroup -KeyName $key -UserData $userdata64 -InstanceProfile_Id $iamRoleName -Placement_AvailabilityZone $zone).RunningInstance
$instance.InstanceId