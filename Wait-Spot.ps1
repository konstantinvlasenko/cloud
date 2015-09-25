Begin {
  Set-DefaultAWSRegion $env:AWSRegion
}

Process {
  "waiting for spot request fulfilment..." | Out-Default
  do {
    Sleep 30
    # update spot requests information
    $spot = Get-EC2SpotInstanceRequest -SpotInstanceRequestId $_
    $spot.Status.Message | Out-Default
  } while( $spot.State -eq 'open' )

  "wait for instances running..." | Out-Default 
  do {
    Sleep 30
  } while( (Get-EC2InstanceStatus -InstanceId $spot.InstanceId).InstanceState.Name -ne 'running' )

  "wait for reachability test..." | Out-Default
  do {
    Sleep 30
  } while( (Get-EC2InstanceStatus -InstanceId $spot.InstanceId).Status.Status.Value -ne 'ok' )
}

End {
  # Executes once after last pipeline object is processed
}