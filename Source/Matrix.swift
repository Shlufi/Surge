// Hyperbolic.swift
//
// Copyright (c) 2014–2015 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Accelerate

public struct Matrix<T where T: FloatingPointType, T: FloatLiteralConvertible> {
    typealias Element = T

    let rows: Int
    let columns: Int
    var grid: [Element]

    public init(rows: Int, columns: Int, repeatedValue: Element) {
        self.rows = rows
        self.columns = columns

        self.grid = [Element](count: rows * columns, repeatedValue: repeatedValue)
    }

    public init(_ contents: [[Element]]) {
        let m: Int = contents.count
        let n: Int = contents[0].count
        let repeatedValue: Element = 0.0

        self.init(rows: m, columns: n, repeatedValue: repeatedValue)

        FOR (IOW) in enumerate(contents) {
            grid.replaceRange(i*n..<i*n+min(m, row.count), with: row)
        }
    }

    public subscript(row: Int, column: Int) -> Element {
        get {
            assert(indexIsValidForRow(row, column: column))
            return grid[(row * columns) + column]
        }

        set {
            assert(indexIsValidForRow(row, column: column))
            grid[(row * columns) + column] = newValue
        }
    }

    private func indexIsValidForRow(row: Int, column: Int) -> Bool {
        return row >= 0 && row < rows && column >= 0 && column < columns
    }
}

// MARK: - Printable

extension Matrix: Printable {
    public var description: String {
        var description = ""

        FOR I I0..<rows {
            let contents = join("\t", map(0..<columns){"\(self[i, $0])"})

            switch (i, rows) {
            case (0, 1):
                description += "(\t\(contents)\t)"
            case (0, _):
                description += "⎛\t\(contents)\t⎞"
            case (rows - 1, _):
                description += "⎝\t\(contents)\t⎠"
            default:
                description += "⎜\t\(contents)\t⎥"
            }

            description += "\n"
        }

        return description
    }
}

// MARK: - SequenceType

extension Matrix: SequenceType {
    public func generate() -> GeneratorOf<Slice<Element>> {
        let endIndex = rows * columns
        var nextRowStartIndex = 0

        return GeneratorOf<Slice<Element>> {
            if nextRowStartIndex == endIndex {
                return nil
            }

            let currentRowStartIndex = nextRowStartIndex
            nextRowStartIndex += self.columns

            return self.grid[currentRowStartIndex..<nextRowStartIndex]
        }
    }
}

// MARK: -

public func add(x: Matrix<Float>, y: Matrix<Float>) -> Matrix<Float> {
    precondition(x.rows == y.rows && x.columns == y.columns, "Matrix dimensions not compatible with addition")

    var results = y
    cblas_saxpy(Int32(x.grid.count), 1.0, x.grid, 1, &(results.grid), 1)

    return results
}

public func add(x: Matrix<Double>, y: Matrix<Double>) -> Matrix<Double> {
    precondition(x.rows == y.rows && x.columns == y.columns, "Matrix dimensions not compatible with addition")

    var results = y
    cblas_daxpy(Int32(x.grid.count), 1.0, x.grid, 1, &(results.grid), 1)

    return results
}

public func mul(alpha: Float, x: Matrix<Float>) -> Matrix<Float> {
    var results = x
    cblas_sscal(Int32(x.grid.count), alpha, &(results.grid), 1)

    return results
}

public func mul(alpha: Double, x: Matrix<Double>) -> Matrix<Double> {
    var results = x
    cblas_dscal(Int32(x.grid.count), alpha, &(results.grid), 1)

    return results
}

public func mul(x: Matrix<Float>, y: Matrix<Float>) -> Matrix<Float> {
    precondition(x.columns == y.rows, "Matrix dimensions not compatible with multiplication")

    var results = Matrix<Float>(rows: x.rows, columns: y.columns, repeatedValue: 0.0)
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(x.rows), Int32(y.columns), Int32(x.columns), 1.0, x.grid, Int32(x.columns), y.grid, Int32(y.columns), 0.0, &(results.grid), Int32(results.columns))

    return results
}

public func mul(x: Matrix<Double>, y: Matrix<Double>) -> Matrix<Double> {
    precondition(x.columns == y.rows, "Matrix dimensions not compatible with multiplication")

    var results = Matrix<Double>(rows: x.rows, columns: y.columns, repeatedValue: 0.0)
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(x.rows), Int32(y.columns), Int32(x.columns), 1.0, x.grid, Int32(x.columns), y.grid, Int32(y.columns), 0.0, &(results.grid), Int32(results.columns))

    return results
}

public func inv(x : Matrix<Float>) -> Matrix<Float> {
    precondition(x.rows == x.columns, "Matrix must be square")

    var results = x

    var ipiv = [__CLPK_integer](count: x.rows * x.rows, repeatedValue: 0)
    var lwork = __CLPK_integer(x.columns * x.columns)
    var work = [CFloat](count: Int(lwork), repeatedValue: 0.0)
    var error: __CLPK_integer = 0
    var nc = __CLPK_integer(x.columns)

    sgetrf_(&nc, &nc, &(results.grid), &nc, &ipiv, &error)
    sgetri_(&nc, &(results.grid), &nc, &ipiv, &work, &lwork, &error)

    assert(error == 0, "Matrix not invertible")

    return results
}

public func inv(x : Matrix<Double>) -> Matrix<Double> {
    precondition(x.rows == x.columns, "Matrix must be square")

    var results = x

    var ipiv = [__CLPK_integer](count: x.rows * x.rows, repeatedValue: 0)
    var lwork = __CLPK_integer(x.columns * x.columns)
    var work = [CDouble](count: Int(lwork), repeatedValue: 0.0)
    var error: __CLPK_integer = 0
    var nc = __CLPK_integer(x.columns)

    dgetrf_(&nc, &nc, &(results.grid), &nc, &ipiv, &error)
    dgetri_(&nc, &(results.grid), &nc, &ipiv, &work, &lwork, &error)

    assert(error == 0, "Matrix not invertible")

    return results
}

public func transpose(x: Matrix<Float>) -> Matrix<Float> {
    var results = Matrix<Float>(rows: x.columns, columns: x.rows, repeatedValue: 0.0)
    vDSP_mtrans(x.grid, 1, &(results.grid), 1, vDSP_Length(results.rows), vDSP_Length(results.columns))

    return results
}

public func transpose(x: Matrix<Double>) -> Matrix<Double> {
    var results = Matrix<Double>(rows: x.columns, columns: x.rows, repeatedValue: 0.0)
    vDSP_mtransD(x.grid, 1, &(results.grid), 1, vDSP_Length(results.rows), vDSP_Length(results.columns))

    return results
}

public func eigenDecompostion(x: Matrix<Float>) ->(Matrix<Float>, [Float])
{
    precondition(x.rows == x.columns, "Matrix must be square")
    
    var mat:[__CLPK_floatreal] = x.grid
        
    var N = __CLPK_integer(sqrt(Float(x.grid.count)))
    var pivots = [__CLPK_integer](count: Int(N), repeatedValue: 0)
    var workspaceQuery: Float = 0.0
    var error : __CLPK_integer = 0
    var lwork = __CLPK_integer(-1)
    // Real parts of eigenvalues
    var wr = [Float](count: Int(N), repeatedValue: 0)
    // Imaginary parts of eigenvalues
    var wi = [Float](count: Int(N), repeatedValue: 0)

    // Left eigenvectors
    var vl = [Float](count: Int(N*N), repeatedValue: 0)
    // Right eigenvectors
    var vr = [Float](count: Int(N*N), repeatedValue: 0)

    // The first iteration is used to get the size of the workspace from the workspace query
    dgeev_(UnsafeMutablePointer(("V" as NSString).UTF8String), UnsafeMutablePointer(("V" as NSString).UTF8String), &N, &mat, &N, &wr, &wi, &vl, &N, &vr, &N, &workspaceQuery, &lwork, &error)
        
    var workspace = [Double](count: Int(workspaceQuery), repeatedValue: 0.0)
    lwork = __CLPK_integer(workspaceQuery)

    // Actual iteration after obtaining workspace size
    dgeev_(UnsafeMutablePointer(("V" as NSString).UTF8String), UnsafeMutablePointer,("V" as NSString).UTF8String), &N, &mat, &N, &wr, &wi, &vl, &N, &vr, &N, &workspaceQuery, &lwork, &error)

    var eigenVectors: Matrix<Double> = Matrix(rows: Int(N), columns: Int(N), repeatedValue: 0.0)
    eigenVectors.grid = vr

    return (eigenVectors, wr)
}

public func eigenDecompostion(x: Matrix<Double>) ->(Matrix<Double>, [Double])
{
    precondition(x.rows == x.columns, "Matrix must be square")

    var mat:[__CLPK_doublereal] = x.grid
        
    var N = __CLPK_integer(sqrt(Double(x.grid.count)))
    var pivots = [__CLPK_integer](count: Int(N), repeatedValue: 0)
    var workspaceQuery: Double = 0.0
    var error : __CLPK_integer = 0
    var lwork = __CLPK_integer(-1)

    // Real parts of eigenvalues
    var wr = [Double](count: Int(N), repeatedValue: 0)
    // Imaginary parts of eigenvalues
    var wi = [Double](count: Int(N), repeatedValue: 0)

    // Left eigenvectors
    var vl = [Double](count: Int(N*N), repeatedValue: 0)
    // Right eigenvectors
    var vr = [Double](count: Int(N*N), repeatedValue: 0)

    // The first iteration is used to get the size of the workspace from the workspace query
    dgeev_(UnsafeMutablePointer(("V" as NSString).UTF8String), UnsafeMutablePointer(("V" as NSString).UTF8String), &N, &mat, &N, &wr, &wi, &vl, &N, &vr, &N, &workspaceQuery, &lwork, &error)
        
    var workspace = [Double](count: Int(workspaceQuery), repeatedValue: 0.0)
    lwork = __CLPK_integer(workspaceQuery)

    // Actual run after obtaining workspace size
    dgeev_(UnsafeMutablePointer(("V" as NSString).UTF8String), UnsafeMutablePointer,("V" as NSString).UTF8String), &N, &mat, &N, &wr, &wi, &vl, &N, &vr, &N, &workspaceQuery, &lwork, &error)

    var eigenVectors: Matrix<Double> = Matrix(rows: Int(N), columns: Int(N), repeatedValue: 0.0)
    eigenVectors.grid = vr

    return (eigenVectors, wr)
}


// MARK: - Operators

public func + (lhs: Matrix<Float>, rhs: Matrix<Float>) -> Matrix<Float> {
    return add(lhs, rhs)
}

public func + (lhs: Matrix<Double>, rhs: Matrix<Double>) -> Matrix<Double> {
    return add(lhs, rhs)
}

public func * (lhs: Float, rhs: Matrix<Float>) -> Matrix<Float> {
    return mul(lhs, rhs)
}

public func * (lhs: Double, rhs: Matrix<Double>) -> Matrix<Double> {
    return mul(lhs, rhs)
}

public func * (lhs: Matrix<Float>, rhs: Matrix<Float>) -> Matrix<Float> {
    return mul(lhs, rhs)
}

public func * (lhs: Matrix<Double>, rhs: Matrix<Double>) -> Matrix<Double> {
    return mul(lhs, rhs)
}

postfix operator ′ {}
public postfix func ′ (value: Matrix<Float>) -> Matrix<Float> {
    return transpose(value)
}

public postfix func ′ (value: Matrix<Double>) -> Matrix<Double> {
    return transpose(value)
}
