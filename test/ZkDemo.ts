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
      let s = [
        [point1[0], point1[1]],
        [point2[0], point2[1]],
        [point3[0], point3[1]],
      ];
      let o = [42, 96, 150];

      expect(await zkDemo.matmul(matrix, n, s, o)).to.be.true;
    });

    it("ecComp", async function () {
      const { zkDemo } = await loadFixture(deployZkDemo);

      let A1 = await zkDemo.initG1(2);
      A1 = await zkDemo.negate([A1[0], A1[1]]);
      let B2 = [
        [
          710971659950299075351025638299543031158944726718316196630017563250057256894n,
          21096988598549379316064222604087070093107208963851932395621890487284397317911n,
        ],
        [
          19625443649200586548833881985732606703875589975722291103262484117838349784384n,
          18248024739783836328211815967314311276769976803340453674090473449195891572055n,
        ],
      ];
      let C1 = await zkDemo.initG1(4);
      let x1 = 10;
      let x2 = 15;
      let x3 = 5;

      let verified = await zkDemo.ecComputation([A1[0], A1[1]], B2, [C1[0], C1[1]], x1, x2, x3);
      expect(verified).to.be.true;
    });
  });
});
