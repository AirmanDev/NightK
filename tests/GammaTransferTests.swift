import Foundation

@main
struct GammaTransferTests {
    static func main() {
        for size in [256, 1024, 4096] {
            guard let lut = GammaTransfer.make(kelvin: 1400, count: size) else { fatalError("no table") }
            precondition(lut.red.count == size && lut.green.count == size && lut.blue.count == size)
            precondition(lut.red[0] == 0 && lut.green[0] == 0 && lut.blue[0] == 0)
            precondition(abs(lut.red.last! - 1) < 0.0001)
            precondition(lut.green.last! < 0.5 && lut.blue.last! == 0)
            precondition(zip(lut.red, lut.red.dropFirst()).allSatisfy { $0 <= $1 })
        }
        let neutral = GammaTransfer.make(kelvin: 6500, count: 1024)!
        precondition(neutral.green.last! > 0.95 && neutral.blue.last! > 0.95)
        precondition(GammaTransfer.make(kelvin: 1400, count: 1) == nil)
        precondition(GammaTransfer.make(kelvin: 1400, count: 4097) == nil)
        precondition(GammaTransfer.make(kelvin: -999, count: 1024)!.blue.last! == 0)
        print("GAMMA_TRANSFER_TESTS_PASS")
    }
}
