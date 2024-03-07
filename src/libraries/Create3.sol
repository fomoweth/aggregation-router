// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Create3
/// @dev modified from https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol

library Create3 {
	error ContractCreationFailed();
	error ProxyCreationFailed();
	error TargetAlreadyExists();

	event Create3Deployed(address indexed instance, address indexed proxy, bytes32 indexed salt);

	//--------------------------------------------------------------------------------//
	// Opcode     | Opcode + Arguments    | Description      | Stack View             //
	//--------------------------------------------------------------------------------//
	// 0x36       |  0x36                 | CALLDATASIZE     | size                   //
	// 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 size                 //
	// 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 0 size               //
	// 0x37       |  0x37                 | CALLDATACOPY     |                        //
	// 0x36       |  0x36                 | CALLDATASIZE     | size                   //
	// 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 size                 //
	// 0x34       |  0x34                 | CALLVALUE        | value 0 size           //
	// 0xf0       |  0xf0                 | CREATE           | newContract            //
	//--------------------------------------------------------------------------------//
	// Opcode     | Opcode + Arguments    | Description      | Stack View             //
	//--------------------------------------------------------------------------------//
	// 0x67       |  0x67XXXXXXXXXXXXXXXX | PUSH8 bytecode   | bytecode               //
	// 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 bytecode             //
	// 0x52       |  0x52                 | MSTORE           |                        //
	// 0x60       |  0x6008               | PUSH1 08         | 8                      //
	// 0x60       |  0x6018               | PUSH1 18         | 24 8                   //
	// 0xf3       |  0xf3                 | RETURN           |                        //
	//--------------------------------------------------------------------------------//

	bytes internal constant PROXY_BYTECODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";

	bytes32 internal constant PROXY_BYTECODE_HASH =
		0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f; // keccak256(PROXY_BYTECODE);

	function create3(bytes32 salt, bytes memory creationCode) internal returns (address instance) {
		// creation code
		bytes memory bytecode = PROXY_BYTECODE;

		// compute target final address
		instance = addressOf(salt);

		if (isContract(instance)) revert TargetAlreadyExists();

		// create CREATE2 proxy
		address proxy;

		assembly ("memory-safe") {
			proxy := create2(0x00, add(bytecode, 0x20), mload(bytecode), salt)
		}

		if (proxy == address(0)) revert ProxyCreationFailed();

		bool success;

		assembly ("memory-safe") {
			success := call(
				gas(),
				proxy,
				callvalue(),
				add(creationCode, 0x20),
				mload(creationCode),
				0x00,
				0x00
			)
		}

		if (!success || !isContract(instance)) revert ContractCreationFailed();

		emit Create3Deployed(instance, proxy, salt);
	}

	function addressOf(bytes32 salt) internal view returns (address instance) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			// compute the address of proxy to be deployed
			mstore(ptr, add(hex"ff", shl(0x58, address())))
			mstore(add(ptr, 0x15), salt)
			mstore(add(ptr, 0x35), PROXY_BYTECODE_HASH)

			let proxy := and(
				keccak256(ptr, 0x55),
				0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
			)

			// compute the address of contract to be deployed by the proxy above
			mstore(ptr, add(hex"d6_94", shl(0x50, proxy)))
			mstore(add(ptr, 0x16), hex"01")

			instance := and(
				keccak256(ptr, 0x17),
				0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
			)
		}
	}

	function isContract(address target) internal view returns (bool res) {
		assembly ("memory-safe") {
			res := gt(extcodesize(target), 0x00)
		}
	}
}
