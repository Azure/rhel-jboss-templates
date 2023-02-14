param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output dbEnd string = 'b742ad57-826f-5a4f-981f-eb4d152c3c21'
output dbStart string = 'fc3c1d44-5bb6-56af-bc0f-9e6c1d5bf810'
