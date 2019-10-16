import Foundation

extension Collection {
    func slowStableSort(using predicate: (Self.Element) -> Bool) -> [Self.Element] {
        // Note: sadly sort() and `partition(by:)` are not guaranteed to be stable sort according to doc,
        // so we can't use them here until we have stablePartition(by:)
        // https://github.com/apple/swift/blob/master/test/Prototypes/Algorithms.swift#L562
        // This solution below is not the most efficient algorithm (memory-alloc-wise)
        // but for our arrays of likely < 20 items it should be enough.
        let triaged = Dictionary(grouping: self, by: predicate)
        let trueSlice = triaged[true] ?? []
        let falseSlice = triaged[false] ?? []
        return trueSlice + falseSlice
    }
}
