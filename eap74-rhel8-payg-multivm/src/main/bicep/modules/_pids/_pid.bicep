param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '62974874-11fb-4fb8-b158-1c1423c60a2f'
output appgwStart string = '30186e04-251a-48df-8669-3c9bcd4bbb25'
output dbEnd string = '52b3cf6f-9e56-5df8-8b2d-50c7ba732fdc'
output dbStart string = '7779325d-7cf5-5601-b807-e6c47c5d7120'
