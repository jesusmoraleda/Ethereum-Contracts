pragma solidity >=0.5.0;


library SdArio {
    struct Creators {
        int16[] shares;
        address[] holders;
        int16 length;
    }
}

contract Royalties { 
    dBCoin distridb;
    uint256 public totalcoin;
    address[] public creators;
    int16[] public shares;
    bytes32 public filehash;
    uint256 public msize;
    uint256 public balance;
    address owner;
    constructor(bytes32 fhash, address[] memory _creators, int16[] memory _shares) public {
        filehash = fhash;
        creators = _creators;
        shares = _shares;
        msize = _creators.length;
        owner = 0x71b0751b5070b1eD8c9643bBeE87BDa8BB0F3c42;
    }
    
    function play(uint256 secs) public returns (bytes1) {
        if (distridb.timeCheck(msg.sender, secs)) {
            distridb.play(msg.sender,secs);
            return 0xf0;
        } else return 0x01;
        
    }

    function reassign(address[] memory _creators, int16[] memory _shares) public {
        if (msg.sender != owner) {
            return;
        }
        creators = _creators;
        shares = _shares;
    }

    function setCoincon(dBCoin _dbc) public {
        if (msg.sender != owner) {
            return;
        }
        distridb = _dbc;
    }

    function sendCoin(uint256 _coin) public {
        if (msg.sender != owner) {
            return;
        }
        balance += _coin;
        totalcoin += _coin;
    }

    function clearing() public {
        if (msg.sender != owner) {
            return;
        }
        balance = 0;
    }


    function getShareList() public view returns (int16[] memory) {
        return shares;
    }

    function getHolderList() public view returns (address[] memory) {
        return creators;
    }

}

contract Subscription {
    struct Subs {
        bool valid;
    }

    address owner;
    mapping(address => Subs) public subs;
    constructor() public {
        owner = msg.sender;
    }

    function enable(address _sub) public {
        if (msg.sender != owner) return;
        Subs storage s = subs[_sub];
        s.valid = true;
    }

    function disable(address _sub) public {
        if (msg.sender != owner) return;
        Subs storage s = subs[_sub];
        s.valid = false;
    }

    function query(address _sub) public view returns (bool) {
        if (subs[_sub].valid) {
            return true;
        } else {
            return false;
        }
    }
}

contract dBCoin {
    using SafeMath for uint256;
    address owner;
    address public pubowner;
    uint256 public lastSettlementTime;
    uint256 public lastSettlementDay;
    uint256 maxTimePerDay = 86400;
    Royalties royaltycon;
    Subscription subc;

    constructor() public {
        owner = msg.sender;
        pubowner = msg.sender;
        lastSettlementDay = 1;
        lastSettlementTime = now;
    }

    struct CreatorAcc {
        uint256 dbcoin;
        bool freez;
        bool exist;
    }
    mapping(address => CreatorAcc) public creator;
    
    struct RoyaltiesBalance {
        uint256 timetoken;
        uint256 transmitting_time;
        uint256 cdbcoin;
        uint256 tdbcoin;
        uint256 totalcoin;
        uint256 lastSettlement;
        uint256 lastSettlement2;
        bool exist;
    }
    mapping(address => RoyaltiesBalance) public royaltyAcc;
    
    struct TransmitBalance {
        uint256 timet1;
        uint256 timet2;
        uint256 dbcoin;
        uint256 lastSettlement;
        bool exist;
    }
    mapping(address => mapping(address => TransmitBalance )) public transmitUser;
    
    struct SettlementUser {
        uint256 dbcoin;
        bool exist;
    }
    mapping(address => SettlementUser) public transmitUserAcc;

    struct RoyaSettlementHist {
        uint256 timetoken;
        uint256 transmitting_time;
        uint256 dbcoin;
    }

    mapping(address => mapping(uint256 => RoyaSettlementHist)) public royaHist;

    struct Sub {
        uint256 balance;
        uint256 lastRechargeDay;
        bool freez;
        bool exist;
    }
    mapping(address => Sub) public subscriptions;

    struct ReleasedB {
        uint256 time;
        uint256 distribute;
        bool cleared;
    }
    mapping(uint256 => ReleasedB) public releaseRecord;

    struct RoyaIndex {
        address roya;
        bool exist;
    }
    mapping(bytes32 => RoyaIndex) public deployedRoya;

    function createRoyaltyMulti(bytes32 fhash,  address[] memory _holders, int16[] memory _shares) public returns (address) {
        RoyaIndex storage p = deployedRoya[fhash];
        if (p.exist) return p.roya;        
        Royalties a = new Royalties(fhash, _holders, _shares);
        address ar =address(a);
        deployedRoya[fhash].exist = true;
        deployedRoya[fhash].roya = ar;
        royaltyAcc[ar].exist = true;
        royaltyAcc[ar].timetoken = 0;
        royaltyAcc[ar].transmitting_time = 0;
        royaltyAcc[ar].cdbcoin = 0;
        royaltyAcc[ar].tdbcoin = 0;
        royaltyAcc[ar].totalcoin = 0;
        royaltyAcc[ar].lastSettlement = lastSettlementDay;
        royaltyAcc[ar].lastSettlement2 = lastSettlementDay;
        return ar;
    }

    function migrateRoyalty(bytes32 fhash, address _roya) public {
        if (msg.sender != owner) return;
        RoyaIndex storage p = deployedRoya[fhash];
        if (p.exist) return;

        deployedRoya[fhash].exist = true;
        deployedRoya[fhash].roya = _roya;
        royaltyAcc[_roya].exist = true;
        royaltyAcc[_roya].timetoken = 0;
        royaltyAcc[_roya].transmitting_time = 0;
        royaltyAcc[_roya].cdbcoin = 0;
        royaltyAcc[_roya].tdbcoin = 0;
        royaltyAcc[_roya].totalcoin = 0;
        royaltyAcc[_roya].lastSettlement = lastSettlementDay;
        royaltyAcc[_roya].lastSettlement2 = lastSettlementDay;
    }


    function queryCoin(address _creator) external view returns (uint) {
        return creator[_creator].dbcoin;
    }

    function setSub(Subscription _subc) public {
        if (msg.sender != owner) return;
        subc = _subc;
    }

    function enableSubsAddr(address subs) external returns (bool) {
        if (msg.sender != owner) return false;
        uint256 n = now;
        uint256 inter = n.sub(lastSettlementTime);
        if (inter > maxTimePerDay) {
            subscriptions[subs].balance = maxTimePerDay;
        } else {
            subscriptions[subs].balance = maxTimePerDay.sub(inter);
        }
        subscriptions[subs].freez = false;
        subscriptions[subs].exist = true;
        subscriptions[subs].lastRechargeDay = 0;
        return true;
    }

    function querySubs(address subs) external view returns(uint) {
        return subscriptions[subs].balance;
    }

    function play(address royalty, uint256 secs) public returns (bytes1) {
        Sub storage p1 = subscriptions[msg.sender];
        if (!p1.exist) {
            if (subc.query(msg.sender)) {
                subscriptions[msg.sender].exist = true;
                subscriptions[msg.sender].balance = maxTimePerDay;
            } else {
                return 0x02;
            }
        }
        RoyaltiesBalance storage p2 = royaltyAcc[royalty];
        ReleasedB storage p3 = releaseRecord[lastSettlementDay.add(1)];
        rechargeA(msg.sender);
        doM1Settlement(royalty);
        if (p1.balance.sub(secs)>0) {
            p1.balance = p1.balance.sub(secs);
            p3.time = p3.time.add(secs);
            p2.timetoken = p2.timetoken.add(secs);
            return 0xf0;
        } else return 0x03;
    }

    function allocate(address _to, uint256 _coin) public returns(uint) {
        if (msg.sender != owner) return 0;
        creator[_to].dbcoin = creator[_to].dbcoin.add(_coin);
        return _coin;
    }

    function allocatebroker(address _to, uint256 _coin) public returns(uint) {
        if (msg.sender != owner) return 0;
        transmitUserAcc[_to].dbcoin = transmitUserAcc[_to].dbcoin.add(_coin);
        return _coin;
    }
    
    function withdraw(address _creator) public returns(uint256 _coin) {
        if (msg.sender != owner) return 0;
        _coin = creator[_creator].dbcoin.add(transmitUserAcc[_creator].dbcoin);
        creator[_creator].dbcoin = 0;
        transmitUserAcc[_creator].dbcoin = 0;
        return _coin;
    }

    function splay(address royalty, address sub, uint256 secs) public returns (bytes1) {
        if (msg.sender != owner) return 0x01;
        Sub storage p1 = subscriptions[sub];
        if (!p1.exist) return 0x02;
        RoyaltiesBalance storage p2 = royaltyAcc[royalty];
        if (!p2.exist) return 0x03;
        ReleasedB storage p3 = releaseRecord[lastSettlementDay];
        rechargeA(sub);
        doM1Settlement(royalty);
    
        if (p1.balance.sub(secs)>0) {
            p1.balance = p1.balance.sub(secs);
            p3.time = p3.time.add(secs);
            p2.timetoken = p2.timetoken.add(secs);
            return 0xf0;
        } else return 0x04;
    }

    function bplay(address roya, address broker, address _sub, uint256 secs) public returns(bytes1) {
        
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
            p1.balance = p1.balance.sub(secs);
            p2.timetoken = p2.timetoken.add(secs);
            p3.time = p3.time.add(secs);
            p2.transmitting_time = p2.transmitting_time.add(secs);
            pb.timet1 = pb.timet1.add(secs);
            return 0xf0;
        } else return 0x04;
    }

    function bplaytest(address roya, address broker, address _sub, uint256 secs) public returns(uint) {
        Sub storage p1 = subscriptions[_sub];
        if (!p1.exist) return 1;
        rechargeA(_sub);
        RoyaltiesBalance storage p2 = royaltyAcc[roya];
        if (!p2.exist) return 2;
        doM1Settlement(roya);
        uint256 settled = doM2TSettlement(roya, broker);
        if(p1.balance > secs) {
            ReleasedB storage p3 = releaseRecord[lastSettlementDay];
            TransmitBalance storage pb = transmitUser[roya][broker];
            p1.balance = p1.balance.sub(secs);
            p2.timetoken = p2.timetoken.add(secs);
            p3.time += p3.time.add(secs);
            p2.transmitting_time = p2.transmitting_time.add(secs);
            pb.timet1 = pb.timet1.add(secs);
            return 16 + settled;
        } else return 0x04;
    }

    function rechargeA(address subs) internal {
        Sub storage p1 = subscriptions[subs];
        if (lastSettlementDay.sub(p1.lastRechargeDay) > 0) {
            if (now.sub(lastSettlementTime) < 1 days) {
                p1.balance = maxTimePerDay.sub(now.sub(lastSettlementTime));
            } else {
                p1.balance = maxTimePerDay;
            }
            p1.lastRechargeDay = lastSettlementDay;
            
        }
    }

    function doM1Settlement(address _roya) internal {
        RoyaltiesBalance storage p2 = royaltyAcc[_roya];
        if (p2.lastSettlement < lastSettlementDay) {
            ReleasedB storage p5 = releaseRecord[p2.lastSettlement];
            RoyaSettlementHist storage pr = royaHist[_roya][p2.lastSettlement];
            if (p5.time > 0) {
                uint256 clrCoin = uint(p2.timetoken.mul(p5.distribute.div(p5.time)));
                pr.dbcoin = clrCoin;
                p2.totalcoin += clrCoin;
                if (p2.transmitting_time.add(p2.timetoken) > 0) {
                    p2.cdbcoin += uint(p2.timetoken.mul(clrCoin.div(p2.transmitting_time.add(p2.timetoken))));
                    p2.lastSettlement2 = lastSettlementDay;
                }
            }
            
            
            pr.timetoken = p2.timetoken;
            pr.transmitting_time = p2.transmitting_time;
            p2.timetoken = 0;
            p2.transmitting_time = 0;
            p2.lastSettlement = lastSettlementDay;
        } 
    
    }

    function doM2TSettlement(address _roya, address _broker) internal returns(uint){
        TransmitBalance storage pb = transmitUser[_roya][_broker];
        RoyaltiesBalance storage prb = royaltyAcc[_roya];
        if ( 1 - pb.lastSettlement == 1) {
            pb.lastSettlement = 1;
        }

        if (pb.lastSettlement < prb.lastSettlement) {
            RoyaSettlementHist storage pr = royaHist[_roya][pb.lastSettlement];
            if (pr.timetoken.add(pr.transmitting_time) > 0) {
                uint256 coins = uint(pb.timet1.mul(pr.dbcoin.div(pr.timetoken+pr.transmitting_time)));
                pb.dbcoin += coins;
                transmitUserAcc[_broker].dbcoin += coins;    
                return coins;
            }
            pb.timet2 = pb.timet1;
            pb.timet1 = 0;
            pb.lastSettlement = lastSettlementDay;
            
            return 0;
        }
        
        
    }

    function doM2BSettlement(address _roya, address _broker) internal {
        TransmitBalance storage pb = transmitUser[_roya][_broker];
        RoyaltiesBalance storage prb = royaltyAcc[_roya];
        if ( 1 - pb.lastSettlement == 1) {
            pb.lastSettlement = 1;
        }

        if (pb.lastSettlement < prb.lastSettlement) {
            RoyaSettlementHist storage pr = royaHist[_roya][pb.lastSettlement];
            if (pr.timetoken.add(pr.transmitting_time) > 0) {
                uint256 coins = uint(pb.timet1.mul(pr.dbcoin.div(pr.timetoken.add(pr.transmitting_time))));
                pb.dbcoin += coins;
                transmitUserAcc[_broker].dbcoin += coins;
            }
            pb.timet2 = pb.timet1;
            pb.timet1 = 0;
            pb.lastSettlement = lastSettlementDay;
            
        }
    }

    
    function startCurrentSettlement() public returns(bool){
        uint256 n = now;
        if (n.sub(lastSettlementTime) >= 600 ) {
            ReleasedB storage ps = releaseRecord[lastSettlementDay];
            if (ps.distribute > 0) {
                uint256 lastvalue = ps.distribute;
                releaseRecord[lastSettlementDay].cleared = true;
                lastSettlementDay += 1;
                lastSettlementTime = now;
                releaseRecord[lastSettlementDay].cleared = false;
                releaseRecord[lastSettlementDay].distribute = lastvalue;
                return true;
            }
        } else return false;
    }

    function releasedB(uint256 amount) public {
        if (msg.sender != owner) return;

        releaseRecord[lastSettlementDay].distribute = amount;
        return;
    }

    function timeCheck(address _sub, uint256 secs)
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
        for (uint256 i = 0; i < _shares.length; i = i.add(1)) {
            CreatorAcc storage pa = creator[_creators[i]];
             uint inter = uint(prb.cdbcoin.mul(_shares[i]));
             inter = inter.div(10000);
             pa.dbcoin += inter;
            
        }
        prb.cdbcoin = 0;
        return 0x0f;
    }

    function settleRoyaShareBatch(Royalties _roya) public returns (bytes1) {
        RoyaltiesBalance storage prb = royaltyAcc[address(_roya)];
        address[] memory _holders = _roya.getHolderList();
        int16[] memory _shares = _roya.getShareList();

        for (uint256 i = 0; i < _holders.length; i++) {
            address crt = _holders[i];
            CreatorAcc storage pa = creator[crt];
            pa.dbcoin += uint(prb.cdbcoin * uint(_shares[i]) / 10000);
        }
        if (_shares[0] > 0) {
            prb.cdbcoin = 0;
            return 0x0f;
        } else {
            return 0x01;
        }
    }

    function querySettlement(uint256 f) public view returns(uint) {
        ReleasedB storage p1 = releaseRecord[f];
        if (p1.cleared) return p1.distribute;
        return 0;
    }

}