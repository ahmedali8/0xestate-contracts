// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Estate} from "../src/Estate.sol";

contract EstateScript is Script {
    function setUp() public {}

    function run() public returns (Estate estate) {
        estate = new Estate({_name: "Estate", _symbol: "EST", _initialOwner: msg.sender});
    }

    function mint() public pure {
        // asset details params
        Estate.AssetDetails memory assetDetails = Estate.AssetDetails({
            legalDescription: "Estate",
            assetAddress: "123 Main St",
            geoJson: "123 Main St",
            parcelId: "123 Main St",
            legalOwner: "123 Main St",
            operatingAgreementHash: keccak256(abi.encodePacked("123 Main St")),
            debtToken: address(0),
            debtAmt: 0,
            foreclosed: false,
            manager: address(0x12)
        });
    }
}

// asset details params
// ["Estate","123 Main St","123 Main St","123 Main St","123 Main St","0xef06d37a1ee853d9a02b5029324d48bc1565dce3dddaa22b51820f7eb0136405","0xde43f899587aaa2Ea6aD243F3d68a5027F2C6a94",0,false,"0xde43f899587aaa2Ea6aD243F3d68a5027F2C6a94"]
