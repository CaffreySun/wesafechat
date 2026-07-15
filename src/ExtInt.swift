extension Int {
    func then(_ transform: (Int) -> Int) -> Int {
        transform(self)
    }
}
