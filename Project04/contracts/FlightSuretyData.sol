pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct Airline {
        address airline;
        string name;
        bool isRegistered;
        bool isFunded;
        uint256 amountFunded;
    }

    struct Flight {
        string name;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(address => bool) private appContracts;

    mapping(bytes32 => Flight) private flights;
    mapping(address => Airline) private airlines;
    mapping(address => uint256) private votes;
    mapping(address => address[]) private voters;
    mapping(bytes32 => uint256) private insurance;
    mapping(address => uint256) private payouts;
    mapping(bytes32 => address[]) private passengers;

    uint256 public airlinesCount;
    uint256 public registeredAirlinesCount;
    uint256 public fundedAirlinesCount;

    uint256 private totalFunds;

    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineSentFunds(address airline, uint256 amount, uint256 totalsent);
    event AirlineRegistered(address airline, string name);
    event AirlineFunded(address airline, string name);

    event FlightRegistered(address airline, string name, uint256 timestamp, bytes32 key);
    event InsuranceBought(address passenger, string name, bytes32 key, uint amount);
    event PayableInsurance(address passenger, string name, uint amount);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address airlineAddress, string airlineName) public {
        contractOwner = msg.sender;

        Airline memory firstAirline = newAirline(airlineAddress, airlineName);
        firstAirline.isRegistered = true;
        airlines[airlineAddress] = firstAirline;
        airlinesCount = airlinesCount.add(1);
        registeredAirlinesCount = registeredAirlinesCount.add(1);
        emit AirlineRegistered(airlineAddress, airlineName);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires the app contract(s) to be the caller
     */
    modifier requireAppCaller() {
        require(appContracts[msg.sender], "Caller is not authorized");
        _;
    }

    /**
     * @dev Modifier that requires the function caller be a registered airline
     */
    modifier requireRegisteredAirline(address airline) {
        require(airlines[airline].isRegistered, "Caller airline is not registered.");
        _;
    }

   /**
     * @dev Modifier that requires the function caller be a not registered airline
     */
    modifier requireNotRegisteredAirline(address airline) {
        require(!airlines[airline].isRegistered, "Caller airline is not registered.");
        _;
    }

    /**
     * @dev Modifier that requires the function caller be a registered airline that has paid up
     */
    modifier requireFundedAirline(address airline) {
        require(airlines[airline].isFunded, "Caller airline is not funded.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool) {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /**
     * @dev Create a new airline
     */
    function newAirline(address account, string name_) internal returns (Airline memory) {
        // the airline must have a name if we are registering it
        require(keccak256(abi.encodePacked(name_)) != keccak256(abi.encodePacked("")),
                "Airline must have a name");
        return Airline({
                    airline: account,
                    name: name_,
                    isRegistered: false,
                    isFunded: false,
                    amountFunded: 0
                });
    }

    function hasVoted(address votingAirline, address airline) public view requireAppCaller() returns (bool) {
        address[] memory voted = voters[airline];

        for (uint idx = 0; idx < voted.length; idx++) {
            if (votingAirline == voted[idx]) {
                return true;
            }
        }

        return false;
    }

    function numVotes(address airline) public view requireAppCaller() returns (uint256) {
        return votes[airline];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline(address registeringAirline, address newAirlineAddress, string newAirlineName)
                    external
                    requireIsOperational() requireAppCaller()
                    requireFundedAirline(registeringAirline)
                returns (bool, uint256) {

        Airline memory createdAirline = newAirline(newAirlineAddress, newAirlineName);

        // When there are only less than four registered airlines
        if (registeredAirlinesCount < 4) {
            createdAirline.isRegistered = true;
            airlines[newAirlineAddress] = createdAirline;
            airlinesCount = airlinesCount.add(1);
            registeredAirlinesCount = registeredAirlinesCount.add(1);
            emit AirlineRegistered(newAirlineAddress, newAirlineName);
            return (true, 0);
        }

        // There are more than four airlines funded
        if (registeringAirline != newAirlineAddress) {
            // has registeringAirline voted for this airline before?
            address[] memory voted = voters[newAirlineAddress];
            bool found = false;
            for (uint idx = 0; idx < voted.length; idx++) {
                if (registeringAirline == voted[idx]) {
                    found = true;
                    break;
                }
            }

            require(!found, "Have already voted for this airline");
        }

        createdAirline = airlines[newAirlineAddress];

        // new airline
        if (createdAirline.airline != newAirlineAddress) {
            createdAirline = newAirline(newAirlineAddress, newAirlineName);
            airlines[newAirlineAddress] = createdAirline;
            voters[newAirlineAddress] = new address[](0);
            // if the registering airline is a funded airline, add 1 vote
            if (airlines[registeringAirline].isFunded) {
                voters[newAirlineAddress].push(registeringAirline);
                votes[newAirlineAddress] = 1;
            }
            airlinesCount = airlinesCount.add(1);
            return (false, 1);
        }

        uint256 totalVotes = votes[newAirlineAddress];

        // in the queue already? increment its vote count if a funded airline called register
        // when the vote is > fundedAirlines/2, promote it to registered

        if (airlines[registeringAirline].isFunded) {
            voters[newAirlineAddress].push(registeringAirline);
            votes[newAirlineAddress] = votes[newAirlineAddress].add(1);
        }

        if (votes[newAirlineAddress] > fundedAirlinesCount.div(2)) {
            airlines[newAirlineAddress].isRegistered = true;
            registeredAirlinesCount = registeredAirlinesCount.add(1);
            delete votes[newAirlineAddress];
            delete voters[newAirlineAddress];
            emit AirlineRegistered(newAirlineAddress, airlines[newAirlineAddress].name);
            return (true, 0);
        } else {
            return (false, totalVotes+1);
        }
    }

    /**
     * @dev Returns true if the airline known to the contract, otherwise returns false.
     */
    function isAirline(address airlaneAddress) external requireAppCaller() returns (bool) {
        return (airlines[airlaneAddress].airline == airlaneAddress);
    }

    function registerFlight(address airlineAddress, string flightName, uint256 timestamp)
                external
                requireIsOperational()
                requireAppCaller()
                requireFundedAirline(airlineAddress)
            returns (bytes32) {
        bytes32 key = getFlightKey(airlineAddress, flightName, timestamp);

        if (flights[key].isRegistered && flights[key].statusCode == 0) {
            // nothing to do, already registered and has no flight data
            return key;
        }

        Flight memory newFlight = Flight({
                name: flightName,
                isRegistered: true,
                statusCode: 0,
                updatedTimestamp: timestamp,
                airline: airlineAddress
            });
        flights[key] = newFlight;

        // no passengers right now
        passengers[key] = new address[](0);

        emit FlightRegistered(airlineAddress, flightName, timestamp, key);

        return key;
    }

    function processFlightStatus(address airline, string flight, uint256 timestamp, uint8 statusCode)
        external
        requireIsOperational()
        requireAppCaller() {
        bytes32 key = getFlightKey(airline, flight, timestamp);

        flights[key].statusCode = statusCode;
    }

    function getFlightStatus(address airline, string flight, uint256 timestamp)
        external view returns (uint8) {
        bytes32 key = getFlightKey(airline, flight, timestamp);

        return flights[key].statusCode;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy(address passenger, uint amount, address airline, string name, uint256 timestamp)
                    external payable
                    requireIsOperational()
                    requireAppCaller()
                    requireFundedAirline(airline)
                returns (bool) {
        bytes32 key = getFlightKey(airline, name, timestamp);
        require(flights[key].isRegistered && flights[key].statusCode == 0, "Flight cannot be insured for (already landed)");

        bytes32 ikey = getFlightInsuranceKey(passenger, key);
        require(insurance[ikey] == 0, "Already bought insurance");

        insurance[ikey] = amount;
        passengers[key].push(passenger);

        emit InsuranceBought(passenger, name, key, amount);

        return true;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airline, string flight, uint256 timestamp)
                external
                requireIsOperational()
                requireAppCaller() {

        bytes32 key = getFlightKey(airline, flight, timestamp);
        require(flights[key].statusCode == STATUS_CODE_LATE_AIRLINE, "Flight not late due to airline");

        address[] memory ps = passengers[key];
        for (uint idx = 0; idx < ps.length; idx++) {
            bytes32 ikey = getFlightInsuranceKey(ps[idx], key);
            if (insurance[ikey] > 0) {
                uint refund = insurance[ikey].mul(3).div(2);
                totalFunds = totalFunds.sub(refund); // this can run out
                payouts[ps[idx]] = payouts[ps[idx]].add(refund);
                insurance[ikey] = 0;
                emit PayableInsurance(ps[idx], flight, payouts[ps[idx]]);
            }
        }
        passengers[key] = new address[](0);
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger) external requireIsOperational() requireAppCaller() {
        uint payment = payouts[passenger];
        if (payment > 0) {
            payouts[passenger] = 0;
            passenger.transfer(payment);
        }
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund(address airlineAddress, uint256 amount)
                    public payable
                    requireIsOperational()
                    requireAppCaller()
                    requireRegisteredAirline(airlineAddress)
                returns (bool) {
        require(amount > 0, "Did not send any funds.");

        airlines[airlineAddress].amountFunded = airlines[airlineAddress].amountFunded.add(amount);
        totalFunds = totalFunds.add(amount);
        emit AirlineSentFunds(airlineAddress, amount, airlines[airlineAddress].amountFunded);
        if (airlines[airlineAddress].amountFunded >= 10 ether) {
            airlines[airlineAddress].isFunded = true;
            fundedAirlinesCount = fundedAirlinesCount.add(1);
            emit AirlineFunded(airlineAddress, airlines[airlineAddress].name);
        }

        return airlines[airlineAddress].isFunded;
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp)
                    internal
                returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getFlightInsuranceKey(address passenger, bytes32 flightKey)
                    internal
                returns(bytes32) {
        return keccak256(abi.encodePacked(passenger, flightKey));
    }

    /**
     * @dev Add an app contract that can call into this contract
     */

    function authorizeCaller(address app) external requireContractOwner {
        appContracts[app] = true;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }
}

