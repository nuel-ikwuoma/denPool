// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
pragma abicoder v2;

contract DenPool {
    uint256 public maxPoolLifespan;
    uint256 public maxPoolAllowedToLive;
    uint256 public numPoolsAlive;

    address public admin;

    struct Project {
        uint256 requestedFund;
        uint256 sponsorsCount;
        bytes imageURI;
        address payable owner;
        mapping(address => uint256) sponsors;
        mapping(address => bool) isSponsor;
    }

    // mapping(uint => Project) projects;
    struct Pool {
        uint256 id;
        uint256 poolSize;
        uint256 curSize;
        uint256 totalPoolFund;
        uint256 raisedPoolFund;
        uint256 totalProjectFundRequested;
        uint256 percentThreshold;
        uint256 createdAt;
        uint256 endingAt;
        uint256 nextProjectID;
        bool limitExceeded;
        bool poolClosed;
        mapping(uint256 => Project) poolProjects;
    }

    mapping(uint256 => Pool) pools;
    mapping(uint256 => uint256) poolProjects;
    uint256 nextPoolID;

    constructor(uint256 _maxPoolLifespan, uint256 _maxPoolAllowedToLive) {
        admin = _msgSender();
        maxPoolLifespan = _maxPoolLifespan;
        maxPoolAllowedToLive = _maxPoolAllowedToLive;
    }

    function createPool(uint256 _poolSize, uint256 _percentThreshold)
        external
        onlyAdmin
    {
        require(
            numPoolsAlive < maxPoolAllowedToLive,
            "DenPool::createPool 'No more pools allowed at this time'"
        );
        uint256 _endingAt = _now() + maxPoolLifespan;
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
    function closePool(uint256 _poolID) external adminOrPoolMatured(_poolID) {
        Pool storage _pool = pools[_poolID];
        require(
            _pool.endingAt > _now(),
            "DenPool::closePool 'pool still alive'"
        );
        uint256 poolSize = _pool.curSize;
        for (uint256 i = 0; i <= poolSize; i++) {
            // payout project owners
            Project storage _project = _pool.poolProjects[i];
            uint256 poolShareRatio = _project.requestedFund /
                _pool.totalProjectFundRequested;
            uint256 poolShareAmount = poolShareRatio * _pool.raisedPoolFund;
            _project.owner.transfer(poolShareAmount);
        }
        // delete the pool from the mappin
        delete pools[_poolID];
        numPoolsAlive--;
    }

    // admin can add project to pool
    function addProjectToPool(
        uint256 _reqFund,
        address _owner,
        string memory _imageURI
    ) external onlyAdmin returns (bool) {
        (uint256 poolID, bool poolAvailable) = checkAvailablePool();

        require(poolAvailable, "No Pool available, create a new pool");
        uint256 nextProjectID = pools[poolID].nextProjectID;
        Project storage newProject = pools[poolID].poolProjects[nextProjectID];
        newProject.requestedFund = _reqFund;
        newProject.imageURI = bytes(_imageURI);
        newProject.owner = payable(_owner);
        pools[poolID].nextProjectID++;
        pools[poolID].curSize++;
        pools[poolID].limitExceeded = pools[poolID].curSize < pools[poolID].poolSize;
        return true;
    }

    // a list of projects to be added to the pool

    // Contract State Setters
    function setMaxPoolLifespan(uint256 _maxPoolLifespan) external onlyAdmin {
        maxPoolLifespan = _maxPoolLifespan;
    }

    function setMaxPoolAllowedToLive(uint256 _setMaxPoolAllowedToLive)
        external
        onlyAdmin
    {
        maxPoolAllowedToLive = _setMaxPoolAllowedToLive;
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _now() internal view returns (uint256) {
        return block.timestamp;
    }

    // MODIFIERS //
    modifier onlyAdmin() {
        require(_msgSender() == admin);
        _;
    }

    modifier adminOrPoolMatured(uint256 _poolID) {
        Pool storage _pool = pools[_poolID];
        bool poolMatured = _pool.endingAt > _now();
        bool isAdmin = _msgSender() == admin;
        require(isAdmin || poolMatured, "Not Admin or Pool not matured");
        _;
    }

    modifier poolLimitNotExceeded(uint256 _poolID) {
        Pool storage _pool = pools[_poolID];
        require(!_pool.limitExceeded, "Pool limit exceeded");
        _;
    }

    // checks that a pool is available and has not exceeded its limit
    function checkAvailablePool() internal view returns (uint256, bool) {
        uint256 i = nextPoolID - numPoolsAlive;
        for (i; i < nextPoolID; i++) {
            if (!pools[i].limitExceeded) {
                return (i, true);
            }
        }
        return (0, false);
    }
}
