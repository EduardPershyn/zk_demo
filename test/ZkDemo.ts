import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("ZkDemo", function () {
  async function deployZkDemo() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const ZkDemo = await hre.ethers.getContractFactory("ZkDemo");
    const zkDemo = await ZkDemo.deploy();

    return { zkDemo, owner, otherAccount };
  }

  describe("tests", function () {
    it("53/192 + 61/511 = 38795/9811", async function () {
      const { zkDemo } = await loadFixture(deployZkDemo);

      let A = await zkDemo.rationalToECPoint(53, 192);
      let B = await zkDemo.rationalToECPoint(61, 511);

      expect(await zkDemo.rationalAdd([A[0], A[1]], [B[0], B[1]], 38795, 98112))
        .to.be.true;
    });

    it("matmul", async function () {
      const { zkDemo } = await loadFixture(deployZkDemo);

      let point1 = await zkDemo.ecMul(3, 1, 2);
      let point2 = await zkDemo.ecMul(6, 1, 2);
      let point3 = await zkDemo.ecMul(9, 1, 2);

      let matrix = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      let n = 3;
      let s = [[point1[0], point1[1]], [point2[0], point2[1]], [point3[0], point3[1]]];
      let o = [42, 96, 150];

      expect(await zkDemo.matmul(matrix, n, s, o))
        .to.be.true;
    });
  });
});
