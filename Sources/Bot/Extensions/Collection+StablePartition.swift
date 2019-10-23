import Foundation

extension Collection {
    func slowStablePartition(isSuffixElement: (Self.Element) -> Bool) -> [Self.Element] {
        // Note: sadly sort() and `partition(by:)` are not guaranteed to be stable according to doc,
        // so we can't use them here until we have stablePartition(by:) in the stdlib
        // https://github.com/apple/swift/blob/master/test/Prototypes/Algorithms.swift#L562
        //
        // The simpler solution below is not the most efficient algorithm (memory-alloc-wise),
        // but for our arrays of likely < 20 items it should be ok.
        let triaged = Dictionary(grouping: self, by: isSuffixElement)
        let prefixSlice = triaged[false] ?? []
        let suffixSlice = triaged[true] ?? []
        return prefixSlice + suffixSlice
    }
}
