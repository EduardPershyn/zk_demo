// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "hardhat/console.sol";

contract ZkDemo {
    // bn128
    uint256 constant Gx = 1;
    uint256 constant Gy = 2;
    uint256 constant curve_order = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    struct ECPoint {
        uint256 x;
        uint256 y;
    }

    function modExp(uint256 base, uint256 exponent, uint256 modulus) public view returns (uint256) {
        (bool ok, bytes memory result) = address(5).staticcall(abi.encode(0x20, 0x20, 0x20, base, exponent, modulus));
        require(ok, "exp failed");
        return abi.decode(result, (uint256));
    }

    function ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) public view returns (uint256 x, uint256 y) {
        (bool ok, bytes memory result) = address(6).staticcall(abi.encode(x1, y1, x2, y2));
        require(ok, "add failed");
        (x, y) = abi.decode(result, (uint256, uint256));
    }

    function ecMul(uint256 scalar, uint256 x1, uint256 y1) public view returns (uint256 x, uint256 y) {
        (bool ok, bytes memory result) = address(7).staticcall(abi.encode(x1, y1, scalar));
        require(ok, "mul failed");
        (x, y) = abi.decode(result, (uint256, uint256));
    }

    function rationalToECPoint(uint256 num, uint256 den) public view returns (uint256 x, uint256 y) {
        uint256 key = rationalToMod(num, den);
        return ecMul(key, Gx, Gy);
    }

    function rationalToMod(uint256 num, uint256 den) public view returns (uint256) {
        // x/y = x * 1/y = x * pow(y, -1, n)
        return mulmod(num, modExp(den, curve_order - 2, curve_order), curve_order);
    }

    // prove that I know rational a and b that a+b = c
    function rationalAdd(ECPoint calldata A, ECPoint calldata B, uint256 num, uint256 den) public view returns (bool verified) {
        (uint256 abX, uint256 abY) = ecAdd(A.x, A.y, B.x, B.y);
        (uint256 cX, uint256 cY) = rationalToECPoint(num, den);

        return abX == cX && abY == cY;
    }

    //1 2 3  ec_point1  o1*G
    //4 5 6  ec_point2  o2*G
    //7 8 9  ec_point3  o3*G
    //
    // We prove we know points 'keys' (key*G) by giving 'o' vector
    // (Or maybe it proves that I know points sum, but not the points themselves..)
    function matmul(uint256[] calldata matrix,
        uint256 n, // n x n for the matrix
        ECPoint[] calldata s, // n elements
        uint256[] calldata o // n elements
    ) public view returns (bool verified) {
        for(uint256 i = 0; i < n; i++) {
            uint256 indent = n * i;
            ECPoint memory rowSum;
            for(uint256 j = 0; j < n; j++) {
                (uint256 mulX, uint256 mulY) = ecMul(matrix[indent + j], s[j].x, s[j].y);
                if (j == 0) {
                    rowSum.x = mulX;
                    rowSum.y = mulY;
                } else {
                    (rowSum.x, rowSum.y) = ecAdd(rowSum.x, rowSum.y, mulX, mulY);
                }
            }
            (uint256 oX, uint256 oY) = ecMul(o[i], Gx, Gy);
            if (rowSum.x != oX || rowSum.y != oY) {
                return false;
            }
        }
        return true;
    }
}
