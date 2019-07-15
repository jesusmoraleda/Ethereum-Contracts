pragma solidity >=0.5.0;

library SdArio {
    struct Creators {
        int8[] shares;
        address[] holders;
        int8 length;
    }
}

contract Royalties { 
    dBCoin distridb;
    address[] public creators;
    int8[] public shares;
    bytes32 public filehash;
    uint public msize;
    address owner;
    constructor(bytes32 fhash, address[] memory _creators, int8[] memory _shares) public {
        filehash = fhash;
        creators = _creators;
        shares = _shares;
        msize = _creators.length;
        owner = msg.sender;
    } 
    
    function play(uint secs) public returns (bytes1) {        
        if (distridb.timeCheck(msg.sender, secs)) {
            distridb.play(msg.sender,secs);
            return 0xf0;
        } else return 0x01;
        
    }

    function getShareList() public view returns (int8[] memory) {
        return shares;
    }

    function getHolderList() public view returns (address[] memory) {
        return creators;
    }

}

contract dBCoin {

    address owner;
    uint public lastSettlementTime;
    uint public lastSettlementDay;
    uint maxTimePerDay = 86400;
    Royalties royaltycontract;

    constructor() public {
        owner = msg.sender;
        lastSettlementDay = 1; 
        lastSettlementTime = now; 
    }

    struct CreatorAcc {
        uint dbcoin;
        bool freez;
        bool exist;
    }
    mapping(address => CreatorAcc) public creator;
    
    struct RoyaltiesBalance {
        uint timetoken;
        uint transmitting_time;
        uint dbcoin;
        uint totalcoin;
        uint lastSettlement;
        uint lastSettlement2;
        bool exist;
    }
    mapping(address => RoyaltiesBalance) public royaltyAcc;
    
    struct TransmitBalance {
        uint timet1;
        uint timet2;
        uint dbcoin;
        uint lastSettlement;
        bool exist;
    }
    mapping(address => mapping(address => TransmitBalance )) public transmitUser;
    
    struct SettlementUser {
        uint dbcoin;
        bool exist;
    }
    mapping(address => SettlementUser) public transmitUserAcc;

    struct RoyaSettlementHist {
        uint timetoken;
        uint transmitting_time;
        uint dbcoin;
    }

    mapping(address => mapping(uint => RoyaSettlementHist)) public royaHist;

    struct Sub {
        uint balance;
        uint lastRechargeDay;
        bool freez;
        bool exist;
    }
    mapping(address => Sub) public subscriptions;
    
    

    struct ReleasedB {
        uint time;
        uint distribute;
        bool cleared;
    }
    mapping(uint => ReleasedB) public releaseRecord;

    struct RoyaIndex {
        address roya;
        bool exist;
    }
    mapping(bytes32 => RoyaIndex) public deployedRoya;

    function createRoyaltyMulti(bytes32 fhash,  address[] memory _holders, int8[] memory _shares) public returns (address) {
        RoyaIndex storage p = deployedRoya[fhash];
        if (p.exist) return p.roya;        
        Royalties a = new Royalties(fhash, _holders, _shares);
        address ar =address(a);
        deployedRoya[fhash].exist = true;
        deployedRoya[fhash].roya = ar;
        royaltyAcc[ar].exist = true;
        royaltyAcc[ar].timetoken = 0;
        royaltyAcc[ar].transmitting_time = 0;
        royaltyAcc[ar].dbcoin = 0;
        royaltyAcc[ar].totalcoin = 0;
        royaltyAcc[ar].lastSettlement = lastSettlementDay;
        royaltyAcc[ar].lastSettlement2 = lastSettlementDay;
        return ar;
    }

    function queryCoin(address _creator) external view returns (uint) {
        return creator[_creator].dbcoin;
    }

    function enableSubsAddr(address subs) external returns (bool) {
        if (msg.sender != owner) return false;
        uint inter = now - lastSettlementTime;
        if (inter > maxTimePerDay) {
            subscriptions[subs].balance = maxTimePerDay;
        } else {
            subscriptions[subs].balance = maxTimePerDay - inter;
        }
        subscriptions[subs].freez = false;
        subscriptions[subs].exist = true;
        subscriptions[subs].lastRechargeDay = 0;
        return true;
    }

    function querySubs(address subs) external view returns(uint) {
        return subscriptions[subs].balance;
    }

    function play(address royalty, uint secs) public returns (bytes1) {
        Sub storage p1 = subscriptions[msg.sender];
        if (!p1.exist) return 0x02;
        RoyaltiesBalance storage p2 = royaltyAcc[royalty];
        ReleasedB storage p3 = releaseRecord[lastSettlementDay+1];
        rechargeA(msg.sender);
        doM1Settlement(royalty);  
        if (p1.balance - secs>0) {
            p1.balance -= secs;
            p3.time += secs;
            p2.timetoken += secs;
            return 0xf0;
        } else return 0x03;
    }


    function withdraw(address _creator) public returns(uint _coin) {
        if (msg.sender != owner) return 0;
        _coin = creator[_creator].dbcoin;
        creator[_creator].dbcoin = 0;
        return _coin;
    }

    function splay(address royalty, address sub, uint secs) public returns (bytes1) {
        if (msg.sender != owner) return 0x01;
        Sub storage p1 = subscriptions[sub];
        if (!p1.exist) return 0x02;
        RoyaltiesBalance storage p2 = royaltyAcc[royalty];
        ReleasedB storage p3 = releaseRecord[lastSettlementDay];
        rechargeA(sub);
        doM1Settlement(royalty);     
        if (p1.balance - secs>0) {
            p1.balance -= secs;
            p3.time += secs;
            p2.timetoken += secs;
            return 0xf0;
        } else return 0x03;
        
    }

    function bplay(address roya, address broker, address _sub, uint secs) public returns(bytes1) {
        
        if (msg.sender != owner) return 0x01;
        Sub storage p1 = subscriptions[_sub];
        if (!p1.exist) return 0x02;
        rechargeA(_sub);        
        RoyaltiesBalance storage p2 = royaltyAcc[roya];
        if (!p2.exist) return 0x03;
        
        doM1Settlement(roya);
        doM2BSettlement(roya, broker);
        if(p1.balance > secs) {
            ReleasedB storage p3 = releaseRecord[lastSettlementDay];
            TransmitBalance storage pb = transmitUser[roya][broker];
            p1.balance -= secs;
            p2.timetoken += secs;
            p3.time += secs;
            p2.transmitting_time += secs;
            pb.timet1 += secs;
            return 0xf0;
        } else return 0x04;

    }

    function bplaytest(address roya, address broker, address _sub, uint secs) public returns(uint) {
        Sub storage p1 = subscriptions[_sub];
        if (!p1.exist) return 1;
        rechargeA(_sub);        
        RoyaltiesBalance storage p2 = royaltyAcc[roya];
        if (!p2.exist) return 2;
        doM1Settlement(roya);
        uint settled = doM2BSettlement(roya, broker);
        if(p1.balance > secs) {
            ReleasedB storage p3 = releaseRecord[lastSettlementDay];
            TransmitBalance storage pb = transmitUser[roya][broker];
            p1.balance -= secs;
            p2.timetoken += secs;
            p3.time += secs;
            p2.transmitting_time += secs;
            pb.timet1 += secs;
            return 16 + settled;
        } else return 0x04;
    }

    function rechargeA(address subs) internal {
        Sub storage p1 = subscriptions[subs];
        if (lastSettlementDay - p1.lastRechargeDay > 0) {
            if (now - lastSettlementTime < 1 days) {
                p1.balance = maxTimePerDay - (now - lastSettlementTime);
            } else {
                p1.balance = maxTimePerDay;
            }
            p1.lastRechargeDay = lastSettlementDay;
            return;
        } else return;
    }

    function doM1Settlement(address _roya) internal {
        RoyaltiesBalance storage p2 = royaltyAcc[_roya];
        if (p2.lastSettlement < lastSettlementDay) {
            ReleasedB storage p5 = releaseRecord[p2.lastSettlement];
            RoyaSettlementHist storage pr = royaHist[_roya][p2.lastSettlement];
            if (p5.time > 0) {
                uint clrCoin = uint(p2.timetoken * p5.distribute / p5.time);
                pr.dbcoin = clrCoin;
                p2.dbcoin += clrCoin;
                p2.totalcoin += clrCoin;
            }
            pr.timetoken = p2.timetoken;
            pr.transmitting_time = p2.transmitting_time;
            p2.timetoken = 0;
            p2.transmitting_time = 0;
            p2.lastSettlement = lastSettlementDay;
            return;
        } else return;
    
    }

    function doM2Settlement(address _roya) internal {
        RoyaltiesBalance storage pra = royaltyAcc[_roya];

        if (pra.lastSettlement2 < pra.lastSettlement) {
            pra.lastSettlement2 = lastSettlementDay;
        }
        
    }

    function doM2BSettlement(address _roya, address _broker) internal returns(uint) {
        TransmitBalance storage pb = transmitUser[_roya][_broker];
        RoyaltiesBalance storage prb = royaltyAcc[_roya];
        if ( 1 - pb.lastSettlement == 1) {
            pb.lastSettlement = 1;
        }
        uint res = 0;
        if (pb.lastSettlement < prb.lastSettlement) {
            RoyaSettlementHist storage pr = royaHist[_roya][pb.lastSettlement];
            if (pr.timetoken + pr.transmitting_time > 0) {
                uint coins = uint(pb.timet1 * pr.dbcoin / (pr.timetoken+pr.transmitting_time));
                pb.dbcoin += coins;
                transmitUserAcc[_broker].dbcoin += coins;    
                res = coins;
            }
            pb.timet2 = pb.timet1;
            pb.timet1 = 0;
            pb.lastSettlement = lastSettlementDay;
            return res;
        } else {
            return 0;
        }
        
    }

    
    function startCurrentSettlement() public returns(bool){
        if (now - lastSettlementTime >= 600 ) {
            ReleasedB storage ps = releaseRecord[lastSettlementDay];
            if (ps.distribute > 0) {
                uint lastvalue = ps.distribute;
                releaseRecord[lastSettlementDay].cleared = true;
                lastSettlementDay += 1;
                lastSettlementTime = now;
                releaseRecord[lastSettlementDay].cleared = false;
                releaseRecord[lastSettlementDay].distribute = lastvalue;
                return true;
            }            
        } else return false;
    }

    function releasedB(uint amount) public {
        if (msg.sender != owner) return;

        releaseRecord[lastSettlementDay].distribute = amount;
        return;
    }

    function timeCheck(address _sub, uint secs)
        public
        view
        returns (bool ok) {
        Sub storage a = subscriptions[_sub];
        if ( !a.freez && a.balance > secs) {
            return true;
        } else {
            return false;
        }
    }

    function settleRoyaShareList(address[] memory _creators, uint[] memory _shares, Royalties _roya) public returns (bytes1) {
        if (msg.sender != owner) return 0x01;
        RoyaltiesBalance storage prb = royaltyAcc[address(_roya)];
        for (uint i = 0; i< _shares.length; i++) {
            CreatorAcc storage pa = creator[_creators[i]];
            pa.dbcoin += uint(prb.dbcoin * _shares[i] / 100);
        }
        prb.dbcoin = 0;
        return 0x0f;
    }

    function settleRoyaShareBatch(Royalties _roya) public returns (bytes1) {
        RoyaltiesBalance storage prb = royaltyAcc[address(_roya)];
        (bool success, bytes memory output) = address(_roya).call("getHolderList()");
        require(success);
        (address[] memory _holders) = abi.decode(output, (address[]));
        (bool success2, bytes memory output2) = address(_roya).call("getShareList()");
        require(success2);
        (int8[] memory _shares) = abi.decode(output2, (int8[]));

        for (uint i=0; i<_holders.length; i++) {
            address crt = _holders[i]; //
            CreatorAcc storage pa = creator[crt];
            pa.dbcoin += uint(prb.dbcoin * uint(_shares[i]) / 100);//
        } //
        if (_shares[0] > 0) {
            prb.dbcoin = 0;
            return 0x0f;
        } else {
            return 0x01;
        }
        
    }

    function querySettlement(uint f) public view returns(uint) {
        ReleasedB storage p1 = releaseRecord[f];
        if (p1.cleared) return p1.distribute;
        return 0;
    }

}