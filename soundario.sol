pragma solidity >=0.5.0;

contract Royalties { 
    Distribution distridb;
    address public creator;
    bytes32 public filehash;
    address owner;
    constructor(bytes32 fhash, address _creator) public {
        filehash = fhash;
        creator = _creator;
        owner = msg.sender;
    } 
    
    function play(uint secs) public returns (bytes1) {        
        if (distridb.timeCheck(msg.sender, secs)) {
            distridb.play(mgs.sender,secs);
            return 0xf0;
        } else return 0x01;
        
    }

}

contract Distribution {

    address owner;
    uint public lastSettlementTime;
    uint public lastSettlementDay;
    uint maxTimePerDay = 86400;

    constructor() public {
        owner = msg.sender;
        lastSettlementDay = 0; 
        lastSettlementTime = now; 
    }

    struct CreatorAcc {
        uint dbcoin;
        bool freez;
        bool exist;
    }
    mapping(address => CreatorAcc) public creator;
    
    struct RoyaltiesBalance {
        address creator;
        uint timetoken;
        uint transmitting_time;
        uint dbcoin;
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

    function createRoyalty(bytes32 fhash, address _creator) public returns (address) {
        RoyaIndex storage p = deployedRoya[fhash];
        if (p.exist) return p.roya;        
        Royalties a = new Royalties(fhash, _creator);
        address ar =address(a);
        deployedRoya[fhash].exist = true;
        deployedRoya[fhash].roya = ar;
        royaltyAcc[ar].creator = _creator;
        royaltyAcc[ar].exist = true;
        royaltyAcc[ar].timetoken = 0;
        royaltyAcc[ar].transmitting_time = 0;
        royaltyAcc[ar].dbcoin = 0;
        royaltyAcc[ar].lastSettlement = lastSettlementDay;
        royaltyAcc[ar].lastSettlement2 = lastSettlementDay;
        CreatorAcc storage pa = creator[_creator];
        if (pa.exist) return ar;
        creator[_creator].freez = false;
        creator[_creator].exist = true;
        return ar;
    }

    function queryCoin(address _creator) external view returns (uint) {
        return creator[_creator].dbcoin;
    }

    function createSubscription(bytes32 _name) public returns (Subscription subs) {
        return new Subscription(_name);
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

    function play(address subs, uint secs) internal returns (bytes1) {
        Sub storage p1 = subscriptions[msg.sender];
        if (!p1.exist) return 0x02;
        RoyaltiesBalance storage p2 = royaltyAcc[royalty];
        ReleasedB storage p3 = releaseRecord[lastSettlementDay+1];
        doRecharge(msg.sender);
        doM1Settlement(royalty);
        doM2Settlement(royalty, p2.creator);        
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
        ReleasedB storage p3 = releaseRecord[lastSettlementDay+1];
        doRecharge(sub);
        doM1Settlement(royalty);
        doM2Settlement(royalty, p2.creator);        
        if (p1.balance - secs>0) {
            p1.balance -= secs;
            p3.time += secs;
            p2.timetoken += secs;
            return 0xf0;
        } else return 0x03;
        
    }

    function bplay(address roya, address broker, address Sub, uint secs) public returns(bytes1) {
        
        if (msg.sender != owner) return 0x01;
        Sub storage p1 = subscriptions[sub];
        if (!p1.exist) return 0x02;
        doRecharge(sub);        
        RoyaltiesBalance storage p2 = royaltyAcc[roya];
        if (!p2.exist) return 0x03;
        
        doM1Settlement(roya);
        doM2BSettlement(roya, broker);
        doM2Settlement(roya, p2.creator);
        if(p1.balance > secs) {
            ReleasedB storage p3 = releaseRecord[lastSettlementDay+1];
            TransmitBalance storage pb = transmitUser[roya][broker];
            p1.balance -= secs;
            p2.timetoken += secs;
            p3.time += secs;
            p2.transmitting_time += secs;
            pb.timet1 += secs;
            return 0xf0;
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
            ReleasedB storage p5 = releaseRecord[p2.lastSettlement + 1];
            RoyaSettlementHist storage pr = royaHist[_roya][p2.lastSettlement + 1];
            if (p5.time > 0) {
                uint clrCoin = uint(p2.timetoken * p5.distribute / p5.time);
                pr.dbcoin = clrCoin;
                p2.dbcoin += clrCoin;
            }
            pr.timetoken = p2.timetoken;
            pr.transmitting_time = p2.transmitting_time;
            p2.timetoken = 0;
            p2.transmitting_time = 0;
            p2.lastSettlement = lastSettlementDay;
            return;
        } else return;
    
    }

    function doM2Settlement(address _roya, address _creator) internal {
        CreatorAcc storage pa = creator[_creator];
        RoyaltiesBalance storage pra = royaltyAcc[_roya];

        if (pra.lastSettlement2 < pra.lastSettlement) {
            RoyaSettlementHist storage pr = royaHist[_roya][pra.lastSettlement2+1];
            if (pr.timetoken+pr.transmitting_time > 0) {
                pa.dbcoin += uint(pr.timetoken * pr.dbcoin / (pr.timetoken+pr.transmitting_time));
            }
            pra.lastSettlement2 = lastSettlementDay - 1;
        }
        
    }

    function doM2BSettlement(address _roya, address _broker) internal {
        TransmitBalance storage pb = transmitUser[_roya][_broker];
        RoyaltiesBalance storage prb = royaltyAcc[_roya];
        if (pb.lastSettlement < prb.lastSettlement2) {
            RoyaSettlementHist storage pr = royaHist[_roya][pb.lastSettlement+1];
            if (pr.timetoken + pr.transmitting_time > 0) {
                uint coins = uint(pb.timet1 * pr.dbcoin / (pr.timetoken+pr.transmitting_time));
                pb.dbcoin += coins;
                transmitUserAcc[_broker].dbcoin += coins;    
            }
            pb.timet2 = pb.timet1;
            pb.timet1 = 0;
            pb.lastSettlement = lastSettlementDay - 1;

        } 
        
    }

    
    function startCurrentSettlement() public returns(bool){
        if (now - lastSettlementTime >= 1 days - 600 ) {
            ReleasedB storage ps = releaseRecord[lastSettlementDay+1];
            if (ps.distribute > 0) {
                releaseRecord[lastSettlementDay+1].cleared = true;
                lastSettlementDay += 1;
                lastSettlementTime = now;
                releaseRecord[lastSettlementDay+1].cleared = false;
                return true;
            }            
        } else return false;
    }

    function releasedB(uint amount) public {
        if (msg.sender != owner) return;

        releaseRecord[lastSettlementDay+1].distribute = amount;
        return;
    }

    function timeCheck(address Sub, uint secs)
        public
        view
        returns (bool ok) {
        Sub storage a = subscriptions[sub];
        if ( !a.freez && a.balance > secs) {
            return true;
        } else {
            return false;
        }
    }

    function querySettlement(uint f) public view returns(uint) {
        ReleasedB storage p1 = releaseRecord[f];
        if (p1.cleared) return p1.distribute;
        return 0;
    }

}