// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
pragma abicoder v2;


contract DenPool {

    uint public maxPoolLifespan;
    uint public maxPoolAllowedToLive;
    uint public numPoolsAlive;

    address public admin;

    struct Project {
        uint requestedFund;
        uint sponsorsCount;
        bytes imageURI;
        address payable owner;
        mapping(address => uint) sponsors;
        mapping(address => bool) isSponsor;
    }

    // mapping(uint => Project) projects;
    struct Pool {
        uint id;
        uint poolSize;
        uint curSize;
        uint totalPoolFund;
        uint raisedPoolFund;
        uint totalProjectFundRequested;
        uint percentThreshold;
        uint createdAt;
        uint endingAt;
        bool limitExceeded;
        bool poolClosed;
        mapping(uint => Project) poolProjects;
    }
    mapping(uint => Pool) pools;
    mapping(uint => uint) poolProjects;
    uint nextPoolID;

    constructor(uint _maxPoolLifespan, uint _maxPoolAllowedToLive) {
        admin = _msgSender();
        maxPoolLifespan = _maxPoolLifespan;
        maxPoolAllowedToLive = _maxPoolAllowedToLive;
    }

    function createPool(uint _poolSize, uint _percentThreshold) external onlyAdmin {
        require(numPoolsAlive < maxPoolAllowedToLive, "DenPool::createPool 'No more pools allowed at this time'");
        uint _endingAt = _now() + maxPoolLifespan;
        // initialize a new pool
        Pool storage _pool = pools[nextPoolID];
        _pool.id = nextPoolID;
        _pool.poolSize = _poolSize;
        _pool.percentThreshold = _percentThreshold;
        _pool.createdAt = _now();
        _pool.endingAt = _endingAt;

        nextPoolID++;
        numPoolsAlive++;
    }

    // admin or anyone can close a matured pool
    function closePool(uint _poolID) external adminOrPoolMatured(_poolID) {
        Pool storage _pool = pools[_poolID];
        require(_pool.endingAt > _now(), "DenPool::closePool 'pool still alive'");
        uint poolSize = _pool.curSize;
        for(uint i=0; i <= poolSize; i++) {
            // payout project owners
            Project storage _project = _pool.poolProjects[i];
            uint poolShareRatio = _project.requestedFund / _pool.totalProjectFundRequested;
            uint poolShareAmount = poolShareRatio * _pool.raisedPoolFund;
            _project.owner.transfer(poolShareAmount);
        }
        numPoolsAlive--;
    }

    // Contract State Setters
    function setMaxPoolLifespan(uint256 _maxPoolLifespan) external onlyAdmin {
        maxPoolLifespan = _maxPoolLifespan;
    }
    function setMaxPoolAllowedToLive(uint256 _setMaxPoolAllowedToLive) external onlyAdmin {
        maxPoolAllowedToLive = _setMaxPoolAllowedToLive;
    }
    function _msgSender() internal returns(address) {
        return msg.sender;
    }
    function _now() internal returns(uint256) {
        return block.timestamp;
    }

    // MODIFIERS //
    modifier onlyAdmin() {
        require(_msgSender() == admin);
        _;
    }

    modifier adminOrPoolMatured(uint _poolID) {
        Pool storage _pool = pools[_poolID];
        bool poolMatured = _pool.endingAt > _now();
        bool isAdmin = _msgSender() == admin;
        require(isAdmin || poolMatured, "Not Admin or Pool not matured");
        _;
    }
}