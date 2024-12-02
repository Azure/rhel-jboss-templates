param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output dbEnd string = 'b742ad57-826f-5a4f-981f-eb4d152c3c21'
output dbStart string = 'fc3c1d44-5bb6-56af-bc0f-9e6c1d5bf810'

output paygSingleEnd string = '13bfd1d1-d616-42b1-b109-4dd815273f53'
output paygSingleStart string = '618fb513-a80a-42c4-946f-e39319fcc353'
