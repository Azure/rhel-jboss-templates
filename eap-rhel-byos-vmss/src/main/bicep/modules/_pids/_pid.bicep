param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '62974874-11fb-4fb8-b158-1c1423c60a2f'
output appgwStart string = '30186e04-251a-48df-8669-3c9bcd4bbb25'
output dbEnd string = '97e0dcfa-fb7d-52be-9575-4ef4c5e0205a'
output dbStart string = '52b387ed-c667-5804-8abe-34a7d477366c'
output byosVmssEnd string = '4f83ec5f-9495-49d1-8ec7-f8e57f69b646'
output byosVmssStart string = '71ffc523-c3d2-459e-957f-c847127a9217'
