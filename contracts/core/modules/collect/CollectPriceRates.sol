pragma solidity ^0.8.0;

contract CollectPriceRates {

    mapping(uint256 => uint256) public rates;

    address public admin;

    constructor(){
        admin = msg.sender;
    }

    function getPrice(uint256 p1, uint256 n) public view returns(uint256){
        return p1*getRate(n)/100;
    }

    function getRate(uint256 n) public view returns(uint256){
        if (rates[n]>0){
            return rates[n];
        }
        if (n >= 300) return 20000;
        if (n >= 290) return 19999;
        if (n >= 281) return 19998;
        if (n >= 275) return 19997;
        if (n >= 270) return 19996;
        if (n >= 267) return 19995;
        if (n >= 264) return 19994;
        if (n >= 261) return 19993;
        if (n >= 259) return 19992;
        if (n >= 257) return 19991;
        if (n >= 255) return 19990;
        if (n >= 254) return 19989;
        if (n >= 251) return 19987;
        revert('Invalid param.');
    }

    function setRate(uint256[] calldata ns, uint256[] calldata rate) public {
        require(msg.sender == admin, 'Not owner.');
        require(ns.length == rate.length, 'Invalid param.');
        for(uint i=0;i<ns.length;i++){
            rates[ns[i]] = rate[i];
        }
    }
}
