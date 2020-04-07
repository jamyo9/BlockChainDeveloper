var HDWalletProvider = require('truffle-hdwallet-provider');

var mnemonic = 'muscle universe recycle tank fan rifle lucky oil embrace behind oval task';

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: function() { 
        return new HDWalletProvider(mnemonic, 'https://rinkeby.infura.io/v3/a3b301689453451dadc6b14902fc2c65') 
      },
      network_id: 4,
      gas: 4500000,
      gasPrice: 10000000000,
    }
  }
};