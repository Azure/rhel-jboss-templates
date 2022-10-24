param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '62974874-11fb-4fb8-b158-1c1423c60a2f'
output appgwStart string = '30186e04-251a-48df-8669-3c9bcd4bbb25'
