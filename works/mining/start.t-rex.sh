address=0x39ac580865cC67bb2ec4e04385f9dc3c462B511b
addressLocation='Coinbase @unicornnet'
pool='us1.ethermine.org'

./t-rex -a ethash -o stratum+tcp://$pool:4444 -u $address
# -p 
