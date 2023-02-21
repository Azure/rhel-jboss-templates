param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '2b5a8686-c2f1-4c89-bcdc-678045c01b42'
output appgwStart string = 'bf7ed489-44fc-47ac-8981-a9f486821cba'
output dbEnd string = '52b3cf6f-9e56-5df8-8b2d-50c7ba732fdc'
output dbStart string = '7779325d-7cf5-5601-b807-e6c47c5d7120'
output paygMultivmEnd string = '5d3e3e2b-1d18-451d-b46e-d576104345b7'
output paygMultivmStart string = '4cd6c1f3-1195-465f-b0e7-6b9a00252786'
