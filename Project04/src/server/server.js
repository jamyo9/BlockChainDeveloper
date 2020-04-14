import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";

import Config from './config.json';
import Web3 from 'web3';

import express from 'express';
import cors from "cors";

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
const flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

const numOracles = 20;
const oracleAddressStart = 29;


const STATUS_CODES = {
  STATUS_CODE_UNKNOWN: 0,
  STATUS_CODE_ON_TIME: 10,
  STATUS_CODE_LATE_AIRLINE: 20,
  STATUS_CODE_LATE_WEATHER: 30,
  STATUS_CODE_LATE_TECHNICAL: 40,
  STATUS_CODE_LATE_OTHER: 50
};

// setup oracles and have them listen for events
async function setupOracles(req, res) {
    const accounts = await web3.eth.getAccounts();
    const oracles = accounts.slice(oracleAddressStart, oracleAddressStart+numOracles+1);
    let idxmap = {};
    let did = [];

    for (let i = 0; i < numOracles; i++) {
        let account = oracles[i];

        let result = await flightSuretyApp.methods.registerOracle().send({from: account, value: oracleRegisterPayment, gas: config.gas});
        did.push(`oracle ${i} account ${account}: ${result.status}`);

        let indexes = await flightSuretyApp.methods.getMyIndexes().call({from: account});
        idxmap[account] = [...indexes];

        // listen
        flightSuretyApp.events.OracleRequest({
          fromBlock: 0,
          filter: {index: [...indexes]}},
          (err, event) => {
            if (err) {
              console.log(err);
            }
            let result = event.returnValues;
            let code = getRandomCode();
            flightSuretyApp.methods.submitOracleResponse(
                result.index,
                result.airline,
                result.flight,
                result.timestamp,
                code
              ).send({
                  from: oracles[i],
                  gas: config.gas
                });
        });
    }

    if (res !== undefined) {
      return res.json({status: "okay", "events": did}).end();
    }
}

function getRandomCode() {
    let statuses = Object.keys(CODES);
    let status = statuses[random.int(0, statuses.length-1)];

    return CODES[status];
}

function updateFlightStatus(req,res) {
  
  const statusCode = req.params.statusCode;

  await flightSuretyApp.methods.processFlightStatus(
        req.params.airline,
        req.params.flight,
        req.params.timestamp,
        statusCode
    ).send();
  
  if (res !== undefined) {
    let oracleReport = "";
    flightSuretyApp.events.OracleReport({fromBlock: 0}, (err, event) => {
      if (err) {
        console.log(err);
      }
      let result = event.returnValues;
      oracleReport = `${result.airline} ${result.flight} ${result.timestamp} ${result.status}`;
      console.log(`OracleReport ${oracleReport}`);
    });

    return res.json({
        status: "okay",
        "OracleReport": `${oracleReport}`
      }).end();
  }
}

async function startup() {
  await setupOracles();
}

const app = express();
app.use(cors());

app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
});

router.put('/api/updateFlightStatus/:airline/:flight/:timestamp/:statusCode', updateFlightStatus);

startup().then(console.log);

export default app;
