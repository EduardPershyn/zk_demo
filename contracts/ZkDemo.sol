// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "hardhat/console.sol";

contract ZkDemo {
    // bn128
    uint256 constant Gx = 1;
    uint256 constant Gy = 2;
    uint256 constant PRIME_Q =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256 constant curve_order =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    struct ECPoint {
        uint256 x;
        uint256 y;
    }

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    function modExp(
        uint256 base,
        uint256 exponent,
        uint256 modulus
    ) public view returns (uint256) {
        (bool ok, bytes memory result) = address(5).staticcall(
            abi.encode(0x20, 0x20, 0x20, base, exponent, modulus)
        );
        require(ok, "exp failed");
        return abi.decode(result, (uint256));
    }

    function ecAdd(
        uint256 x1,
        uint256 y1,
        uint256 x2,
        uint256 y2
    ) public view returns (uint256 x, uint256 y) {
        (bool ok, bytes memory result) = address(6).staticcall(
            abi.encode(x1, y1, x2, y2)
        );
        require(ok, "add failed");
        (x, y) = abi.decode(result, (uint256, uint256));
    }

    function ecMul(
        uint256 scalar,
        uint256 x1,
        uint256 y1
    ) public view returns (uint256 x, uint256 y) {
        (bool ok, bytes memory result) = address(7).staticcall(
            abi.encode(x1, y1, scalar)
        );
        require(ok, "mul failed");
        (x, y) = abi.decode(result, (uint256, uint256));
    }

    /* @return The result of computing the pairing check
     *         e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
     *         For example,
     *         pairing([P1(), P1().negate()], [P2(), P2()]) should return true.
     */
    function pairing(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {
        G1Point[4] memory p1 = [a1, b1, c1, d1];
        G2Point[4] memory p2 = [a2, b2, c2, d2];

        uint256 inputSize = 24;
        uint256[] memory input = new uint256[](inputSize);

        for (uint256 i = 0; i < 4; i++) {
            uint256 j = i * 6;
            input[j + 0] = p1[i].X;
            input[j + 1] = p1[i].Y;
            input[j + 2] = p2[i].X[1];
            input[j + 3] = p2[i].X[0];
            input[j + 4] = p2[i].Y[1];
            input[j + 5] = p2[i].Y[0];
        }

        uint256[1] memory out;
        bool success;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(
                sub(gas(), 2000),
                8,
                add(input, 0x20),
                mul(inputSize, 0x20),
                out,
                0x20
            )
            // Use "invalid" to make gas estimation work
//            switch success
//            case 0 {
//                invalid()
//            }
        }

        require(success, "pairing-opcode-failed");

        return out[0] != 0;
    }

    function negate(G1Point memory p) public pure returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        if (p.X == 0 && p.Y == 0) {
            return G1Point(0, 0);
        } else {
            return G1Point(p.X, PRIME_Q - (p.Y % PRIME_Q));
        }
    }

    function rationalToECPoint(
        uint256 num,
        uint256 den
    ) public view returns (uint256 x, uint256 y) {
        uint256 key = rationalToMod(num, den);
        return ecMul(key, Gx, Gy);
    }

    function rationalToMod(
        uint256 num,
        uint256 den
    ) public view returns (uint256) {
        // x/y = x * 1/y = x * pow(y, -1, n)
        return
            mulmod(num, modExp(den, curve_order - 2, curve_order), curve_order);
    }

    //////////////////////////////////////////////////
    //Proves
    // prove that I know rational a and b that a+b = c
    function rationalAdd(
        ECPoint calldata A,
        ECPoint calldata B,
        uint256 num,
        uint256 den
    ) public view returns (bool verified) {
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
    function matmul(
        uint256[] calldata matrix,
        uint256 n, // n x n for the matrix
        ECPoint[] calldata s, // n elements
        uint256[] calldata o // n elements
    ) public view returns (bool verified) {
        for (uint256 i = 0; i < n; i++) {
            uint256 indent = n * i;
            ECPoint memory rowSum;
            for (uint256 j = 0; j < n; j++) {
                (uint256 mulX, uint256 mulY) = ecMul(
                    matrix[indent + j],
                    s[j].x,
                    s[j].y
                );
                if (j == 0) {
                    rowSum.x = mulX;
                    rowSum.y = mulY;
                } else {
                    (rowSum.x, rowSum.y) = ecAdd(
                        rowSum.x,
                        rowSum.y,
                        mulX,
                        mulY
                    );
                }
            }
            (uint256 oX, uint256 oY) = ecMul(o[i], Gx, Gy);
            if (rowSum.x != oX || rowSum.y != oY) {
                return false;
            }
        }
        return true;
    }

    function initG1(uint256 k) public view returns (G1Point memory) {
        (uint256 x, uint256 y) = ecMul(k, Gx, Gy);
        return G1Point(x, y);
    }

    G1Point a1 = initG1(2);
    G2Point b2 =
        G2Point(
            [
                2725019753478801796453339367788033689375851816420509565303521482350756874229,
                7273165102799931111715871471550377909735733521218303035754523677688038059653
            ],
            [
                2512659008974376214222774206987427162027254181373325676825515531566330959255,
                957874124722006818841961785324909313781880061366718538693995380805373202866
            ]
        );
    G2Point c2 =
        G2Point(
            [
                18936818173480011669507163011118288089468827259971823710084038754632518263340,
                18556147586753789634670778212244811446448229326945855846642767021074501673839
            ],
            [
                18825831177813899069786213865729385895767511805925522466244528695074736584695,
                13775476761357503446238925910346030822904460488609979964814810757616608848118
            ]
        );
    G2Point d2 =
        G2Point(
            [
                18029695676650738226693292988307914797657423701064905010927197838374790804409,
                14583779054894525174450323658765874724019480979794335525732096752006891875705
            ],
            [
                2140229616977736810657479771656733941598412651537078903776637920509952744750,
                11474861747383700316476719153975578001603231366361248090558603872215261634898
            ]
        );

    // Verify
    // 0 = -A1B2 + a1b2 + X1c2 + C1d2
    // X1 = x1G1 + x2G1 + x3G1
    function ecComputation(
        G1Point calldata A1,
        G2Point calldata B2,
        G1Point calldata C1,
        uint256 x1,
        uint256 x2,
        uint256 x3
    ) external view returns (bool verified) {
        G1Point memory X1 = initG1(x1 + x2 + x3);

//        console.log("A1");
//        console.log(A1.X, A1.Y);
//        console.log("B2");
//        console.log(B2.X[0], B2.X[1], B2.Y[0], B2.Y[1]);
//        console.log("a1");
//        console.log(a1.X, a1.Y);
//        console.log("b2");
//        console.log(b2.X[0], b2.X[1], b2.Y[0], b2.Y[1]);
//        console.log("X1");
//        console.log(X1.X, X1.Y);
//        console.log("c2");
//        console.log(c2.X[0], c2.X[1], c2.Y[0], c2.Y[1]);
//        console.log("C1");
//        console.log(C1.X, C1.Y);
//        console.log("d2");
//        console.log(d2.X[0], d2.X[1], d2.Y[0], d2.Y[1]);

        verified = pairing(A1, B2, a1, b2, X1, c2, C1, d2);
        console.log(verified);
    }
}
