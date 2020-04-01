const StarNotary = artifacts.require("StarNotary");

var accounts;
var owner;

contract('StarNotary', (accs) => {
    accounts = accs;
    owner = accounts[0];
});

it('can Create a Star', async() => {
    let tokenId = 1;
    let instance = await StarNotary.deployed();
    await instance.createStar('Awesome Star!', "EUR", tokenId, {from: accounts[0]})
    assert.equal((await instance.tokenIdToStarInfo.call(tokenId))[0], 'Awesome Star!')
});

it('lets user1 put up their star for sale', async() => {
    let instance = await StarNotary.deployed();
    let user1 = accounts[1];
    let starId = 2;
    let starPrice = web3.utils.toWei(".01", "ether");
    await instance.createStar('awesome star', "EUR", starId, {from: user1});
    await instance.putStarUpForSale(starId, starPrice, {from: user1});
    assert.equal(await instance.starsForSale.call(starId), starPrice);
});

it('lets user1 get the funds after the sale', async() => {
    let instance = await StarNotary.deployed();
    let user1 = accounts[1];
    let user2 = accounts[2];
    let starId = 3;
    let starPrice = web3.utils.toWei(".01", "ether");
    let balance = web3.utils.toWei(".05", "ether");
    await instance.createStar('awesome star', "EUR", starId, {from: user1});
    await instance.putStarUpForSale(starId, starPrice, {from: user1});
    let balanceOfUser1BeforeTransaction = await web3.eth.getBalance(user1);
    await instance.buyStar(starId, {from: user2, value: balance});
    let balanceOfUser1AfterTransaction = await web3.eth.getBalance(user1);
    let value1 = Number(balanceOfUser1BeforeTransaction) + Number(starPrice);
    let value2 = Number(balanceOfUser1AfterTransaction);
    assert.equal(value1, value2);
});

it('lets user2 buy a star, if it is put up for sale', async() => {
    let instance = await StarNotary.deployed();
    let user1 = accounts[1];
    let user2 = accounts[2];
    let starId = 4;
    let starPrice = web3.utils.toWei(".01", "ether");
    let balance = web3.utils.toWei(".05", "ether");
    await instance.createStar('awesome star', "EUR", starId, {from: user1});
    await instance.putStarUpForSale(starId, starPrice, {from: user1});
    let balanceOfUser1BeforeTransaction = await web3.eth.getBalance(user2);
    await instance.buyStar(starId, {from: user2, value: balance});
    assert.equal(await instance.ownerOf.call(starId), user2);
});

it('lets user2 buy a star and decreases its balance in ether', async() => {
    let instance = await StarNotary.deployed();
    let user1 = accounts[1];
    let user2 = accounts[2];
    let starId = 5;
    let starPrice = web3.utils.toWei(".01", "ether");
    let balance = web3.utils.toWei(".05", "ether");
    await instance.createStar('awesome star', "EUR", starId, {from: user1});
    await instance.putStarUpForSale(starId, starPrice, {from: user1});
    let balanceOfUser1BeforeTransaction = await web3.eth.getBalance(user2);
    const balanceOfUser2BeforeTransaction = await web3.eth.getBalance(user2);
    await instance.buyStar(starId, {from: user2, value: balance, gasPrice:0});
    const balanceAfterUser2BuysStar = await web3.eth.getBalance(user2);
    let value = Number(balanceOfUser2BeforeTransaction) - Number(balanceAfterUser2BuysStar);
    assert.equal(value, starPrice);
});

// Implement Task 2 Add supporting unit tests

it('can add the star name and star symbol properly', async() => {
    // 1. create a Star with different tokenId
    //2. Call the name and symbol properties in your Smart Contract and compare with the name and symbol provided
    let instance = await StarNotary.deployed();
    let account = accounts[1];
    let starId = 6;
    let name = "New Star";
    let symbol = "EUR";
    // create the Stars
    await instance.createStar(name, symbol, starId, {from: account});
    let starInfo = await instance.tokenIdToStarInfo.call(starId);
    assert.equal(starInfo[0], name);
    assert.equal(starInfo[1], symbol);
});

it('lets 2 users exchange stars', async() => {
    // 1. create 2 Stars with different tokenId
    // 2. Call the exchangeStars functions implemented in the Smart Contract
    // 3. Verify that the owners changed
    let instance = await StarNotary.deployed();
    let account1 = accounts[1];
    let account2 = accounts[2];
    let starId1 = 7;
    let starId2 = 8;
    // create the Stars
    await instance.createStar("Star1", "EUR", starId1, {from: account1});
    await instance.createStar("Star2", "EUR", starId2, {from: account2});
    // verify the owners are the same as in the creation
    assert.equal(await instance.ownerOf(starId1),account1);
    assert.equal(await instance.ownerOf(starId2),account2);
    // exchange the stars
    await instance.exchangeStars(starId1, starId2, {from: account1});
    // verfify the owners changed
    assert.equal(await instance.ownerOf(starId1),account2);
    assert.equal(await instance.ownerOf(starId2),account1);
});

it('lets a user transfer a star', async() => {
    // 1. create a Star with different tokenId
    // 2. use the transferStar function implemented in the Smart Contract
    // 3. Verify the star owner changed.
    let instance = await StarNotary.deployed();
    let account1 = accounts[1];
    let account2 = accounts[2];
    let starId = 9;
    // create the Star
    await instance.createStar("NewStar", "EUR", starId, {from: account1});
    // verify the owner is the one in the creation
    assert.equal(await instance.ownerOf(starId),account1);
    // transfer the Star
    await instance.transferStar(account2, starId, {from: account1});
    // verfify the owner changed
    assert.equal(await instance.ownerOf(starId),account2);
});

it('lookUptokenIdToStarInfo test', async() => {
    // 1. create a Star with different tokenId
    // 2. Call your method lookUptokenIdToStarInfo
    // 3. Verify if you Star name is the same
    let instance = await StarNotary.deployed();
    let account = accounts[1];
    let starId = 10;
    let name = "NewStar";
    let symbol = "EUR";
    // create the Star
    await instance.createStar(name, symbol, starId, {from: account});

    // obtain the star information
    let starName =  await instance.lookUptokenIdToStarInfo(starId);

    // verify the information
    assert.equal("NewStar", starName);
});