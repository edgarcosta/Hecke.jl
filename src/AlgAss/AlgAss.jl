export wedderburn_decomposition

################################################################################
#
#  Basic field access
#
################################################################################

base_ring(A::AlgAss{T}) where {T} = A.base_ring::parent_type(T)

has_one(A::AlgAss) = A.has_one

iszero(A::AlgAss) = A.iszero

function Generic.dim(A::AlgAss)
  if iszero(A)
    return 0
  end
  return size(multiplication_table(A, copy = false), 1)
end

degree(A::AlgAss) = dim(A)

elem_type(::Type{AlgAss{T}}) where {T} = AlgAssElem{T, AlgAss{T}}

function multiplication_table(A::AlgAss; copy::Bool = true)
  if copy
    return deepcopy(A.mult_table)
  else
    return A.mult_table
  end
end

################################################################################
#
#  Commutativity
#
################################################################################

iscommutative_known(A::AlgAss) = (A.iscommutative != 0)

function iscommutative(A::AlgAss)
  if iscommutative_known(A)
    return A.iscommutative == 1
  end
  for i = 1:dim(A)
    for j = i + 1:dim(A)
      if multiplication_table(A, copy = false)[i, j, :] != multiplication_table(A, copy = false)[j, i, :]
        A.iscommutative = 2
        return false
      end
    end
  end
  A.iscommutative = 1
  return true
end

################################################################################
#
#  Construction
#
################################################################################

# This only works if base_ring(A) is a field (probably)
# Returns (true, one) if there is a one and (false, something) if not.
function find_one(A::AlgAss)
  if iszero(A)
    return true, elem_type(base_ring(A))[]
  end
  n = dim(A)
  M = zero_matrix(base_ring(A), n^2, n)
  c = zero_matrix(base_ring(A), n^2, 1)
  for k = 1:n
    kn = (k - 1)*n
    c[kn + k, 1] = base_ring(A)(1)
    for i = 1:n
      for j = 1:n
        M[i + kn, j] = deepcopy(multiplication_table(A, copy = false)[j, k, i])
      end
    end
  end
  Mc = hcat(M, c)
  rref!(Mc)
  if iszero(Mc[n, n])
    return false, zeros(A, n)
  end
  if n != 1 && !iszero(Mc[n + 1, n + 1])
    return false, zeros(A, n)
  end
  cc = solve_ut(sub(Mc, 1:n, 1:n), sub(Mc, 1:n, (n + 1):(n + 1)))
  one = [ cc[i, 1] for i = 1:n ]
  return true, one
end

function _zero_algebra(R::Ring)
  A = AlgAss{elem_type(R)}(R)
  A.iszero = true
  A.iscommutative = 1
  A.has_one = true
  A.one = elem_type(R)[]
  return A
end

function AlgAss(R::Ring, mult_table::Array{T, 3}, one::Array{T, 1}) where {T}
  if size(mult_table, 1) == 0
    return _zero_algebra(R)
  end
  return AlgAss{T}(R, mult_table, one)
end

function AlgAss(R::Ring, mult_table::Array{T, 3}) where {T}
  if size(mult_table, 1) == 0
    return _zero_algebra(R)
  end
  A = AlgAss{T}(R)
  A.mult_table = mult_table
  A.iszero = false
  has_one, one = find_one(A)
  A.has_one = has_one
  if has_one
    A.one = one
  end
  return A
end

function AlgAss(R::Ring, d::Int, arr::Array{T, 1}) where {T}
  if d == 0
    return _zero_algebra(R)
  end
  mult_table = Array{T, 3}(undef, d, d, d)
  n = d^2
  for i in 1:d
    for j in 1:d
      for k in 1:d
        mult_table[i, j, k] = arr[(i - 1) * n + (j - 1) * d + k]
      end
    end
  end
  return AlgAss(R, mult_table)
end

# Constructs the algebra R[X]/f
function AlgAss(f::PolyElem)
  R = base_ring(parent(f))
  n = degree(f)
  Rx = parent(f)
  x = gen(Rx)
  B = Array{elem_type(Rx), 1}(undef, 2*n - 1)
  B[1] = Rx(1)
  for i = 2:2*n - 1
    B[i] = mod(B[i - 1]*x, f)
  end
  mult_table = Array{elem_type(R), 3}(undef, n, n, n)
  for i = 1:n
    for j = i:n
      for k = 1:n
        mult_table[i, j, k] = coeff(B[i + j - 1], k - 1)
        mult_table[j, i, k] = coeff(B[i + j - 1], k - 1)
      end
    end
  end
  one = map(R, zeros(Int, n))
  one[1] = R(1)
  A = AlgAss(R, mult_table, one)
  A.iscommutative = 1
  return A
end

function AlgAss(O::Union{NfAbsOrd, AlgAssAbsOrd}, I::Union{NfAbsOrdIdl, AlgAssAbsOrdIdl}, p::Union{Integer, fmpz})
  @assert order(I) === O

  n = degree(O)
  BO = basis(O, copy = false)
  BOmod = elem_type(O)[ mod(v, I) for v in BO ]
  Fp = GF(p, cached=false)
  B = zero_matrix(Fp, n, n)
  for i = 1:n
    _b = coordinates(BOmod[i], copy = false)
    for j = 1:n
      B[i, j] = Fp(_b[j])
    end
  end
  r = rref!(B)
  r == 0 && error("Cannot construct zero dimensional algebra.")
  b = Vector{fmpz}(undef, n)
  bbasis = Vector{elem_type(O)}(undef, r)
  for i = 1:r
    for j = 1:n
      b[j] = lift(B[i, j])
    end
    bbasis[i] = O(b)
  end

  _, perm, L, U = lu(transpose(B))

  mult_table = Array{elem_type(Fp), 3}(undef, r, r, r)

  d = zero_matrix(Fp, n, 1)

  iscom = true
  if O isa AlgAssAbsOrd
    iscom = iscommutative(O)
  end

  aux = O()

  for i = 1:r
    for j = 1:r
      if iscom && j < i
        continue
      end
      mul!(aux, bbasis[i], bbasis[j])
      c = coordinates(mod(aux, I))
      for k = 1:n
        d[perm[k], 1] = c[k]
      end
      d = solve_lt(L, d)
      d = solve_ut(U, d)
      for k = 1:r
        mult_table[i, j, k] = deepcopy(d[k, 1])
        if iscom && i != j
          mult_table[j, i, k] = deepcopy(d[k, 1])
        end
      end
    end
  end

  if isone(bbasis[1])
    one = zeros(Fp, r)
    one[1] = Fp(1)
    A = AlgAss(Fp, mult_table, one)
  else
    A = AlgAss(Fp, mult_table)
  end
  if iscom
    A.iscommutative = 1
  end

  local _image

  let n = n, r = r, d = d, I = I, A = A, L = L, U = U, perm = perm
    function _image(a::Union{NfAbsOrdElem, AlgAssAbsOrdElem})
      c = coordinates(mod(a, I))
      for k = 1:n
        d[perm[k], 1] = c[k]
      end
      d = solve_lt(L, d)
      d = solve_ut(U, d)
      e = A()
      for k = 1:r
        e.coeffs[k] = deepcopy(d[k, 1])
      end
      return e
    end
  end

  local _preimage

  let bbasis = bbasis, r = r
    function _preimage(a::AlgAssElem)
      return sum(lift(a.coeffs[i])*bbasis[i] for i = 1:r)
    end
  end

  OtoA = AbsOrdToAlgAssMor{typeof(O), elem_type(Fp)}(O, A, _image, _preimage)

  return A, OtoA
end

function _modular_basis(pb::Vector{Tuple{T, NfOrdFracIdl}}, p::NfOrdIdl) where T <: RelativeElement{nf_elem}
  L = parent(pb[1][1])
  K = base_ring(L)
  basis = Array{elem_type(L), 1}()
  u = L(K(uniformizer(p)))
  for i = 1:degree(L)
    v = valuation(pb[i][2], p)
    push!(basis, (u^v)*pb[i][1])
  end
  return basis
end

#=
Qx, x = QQ["x"];
f = x^2 + 12*x - 92;
K, a = number_field(f, "a");
OK = maximal_order(K);
Ky, y = K["y"];
g = y^2 - 54*y - 73;
L, b = number_field(g, "b");
OL = maximal_order(L);
p = prime_decomposition(OK, 2)[1][1]
=#

# Assume that O is relative order over OK, I is an ideal of O and p is a prime
# ideal of OK with pO \subseteq I. O/I is an OK/p-algebra.
#
# The idea is to compute pseudo-basis of O and I respectively, for which the
# coefficient ideals have zero p-adic valuation. Then we can think in the
# localization at p and do as in the case of principal ideal domains.
function AlgAss(O::NfRelOrd{T, S}, I::NfRelOrdIdl{T, S}, p::Union{NfOrdIdl, NfRelOrdIdl}) where {T, S}
  basis_pmatI = basis_pmat(I, copy = false)
  basis_pmatO = basis_pmat(O, copy = false)

  new_basis_mat = deepcopy(O.basis_mat)
  new_basis_mat_I = deepcopy(I.basis_mat)

  pi = anti_uniformizer(p)

  new_basis_coeffs = S[]

  for i in 1:degree(O)
    a = pi^valuation(basis_pmat(O).coeffs[i], p)
    push!(new_basis_coeffs, a * basis_pmatO.coeffs[i])
    mul_row!(new_basis_mat, i, inv(a))
    for j in 1:degree(O)
      new_basis_mat_I[j, i] = new_basis_mat_I[j, i] * a
    end
  end

  new_coeff_I = S[]

  for i in 1:degree(O)
    a = pi^valuation(basis_pmatI.coeffs[i], p)
    push!(new_coeff_I, a * basis_pmatI.coeffs[i])
    mul_row!(new_basis_mat_I, i, inv(a))
  end

  Fp, mF = ResidueField(order(p), p)
  mmF = extend(mF, base_ring(nf(O)))
  invmmF = pseudo_inv(mmF)

  basis_elts = Int[]
  reducers = Int[]

  for i in 1:degree(O)
    v = valuation(new_basis_mat_I[i, i], p)
    v2 = valuation(new_coeff_I[i], p)
    #@show (v2, v)
    @assert v >= 0
    if v == 0
    #if valuation(basis_pmatI.coeffs[i], p) + valuation(new_basis_mat_I[i, i], p) == 0
      push!(reducers, i)
    else
      push!(basis_elts, i)
    end
  end

  reverse!(reducers)

  OLL = Order(nf(O), PseudoMatrix(new_basis_mat, new_basis_coeffs))

  newI = ideal(OLL, PseudoMatrix(new_basis_mat_I, new_coeff_I))

  new_basis = pseudo_basis(OLL)

  pseudo_basis_newI = pseudo_basis(newI)

  tmp_matrix = zero_matrix(base_ring(nf(O)), 1, degree(O))

  basis_mat_inv_OLL = basis_mat_inv(OLL)

  function _coeff(c) 
    for i in 0:degree(O) - 1
      tmp_matrix[1, i + 1] = coeff(c, i)
    end
    return tmp_matrix * basis_mat_inv_OLL
  end

  r = length(basis_elts)

  mult_table = Array{elem_type(Fp), 3}(undef, r, r, r)

  for i in 1:r
    for j in 1:r
      c = new_basis[basis_elts[i]][1] * new_basis[basis_elts[j]][1]
      coeffs = _coeff(c)

      for k in reducers
        d = -coeffs[k]//new_basis_mat_I[k, k]
        c = c + d * pseudo_basis_newI[k][1]
      end
      coeffs = _coeff(c)
      for k in 1:degree(O)
        if !(k in basis_elts)
          @assert iszero(coeffs[k])
        end
      end
      for k in 1:r
        mult_table[i, j, k] = mmF(coeffs[basis_elts[k]])
      end
    end
  end

  if isone(new_basis[basis_elts[1]][1])
    one = zeros(Fp, length(basis_elts))
    one[1] = Fp(1)
    A = AlgAss(Fp, mult_table, one)
  else
    A = AlgAss(Fp, mult_table)
  end
  A.iscommutative = 1

  function _image(a::NfRelOrdElem)
    c = a.elem_in_nf
    coeffs = _coeff(c)
    for k in reducers
      d = -coeffs[k]//new_basis_mat_I[k, k]
      c = c + d*pseudo_basis_newI[k][1]
    end
    coeffs = _coeff(c)
    for k in 1:degree(O)
      if !(k in basis_elts)
        @assert iszero(coeffs[k])
      end
    end
    b = A()
    for k in 1:r
      b.coeffs[k] = mmF(coeffs[basis_elts[k]])
    end
    return b
  end

  lifted_basis_of_A = []

  for i in basis_elts
    c = coprime_to(new_basis[i][2], p)
    b = invmmF(inv(mmF(c)))*c*new_basis[i][1]
    @assert b in O
    push!(lifted_basis_of_A, b)
  end

  function _preimage(v::AlgAssElem)
    return O(sum((invmmF(v.coeffs[i])) * lifted_basis_of_A[i] for i in 1:r))
  end

  OtoA = NfRelOrdToAlgAssMor{T, S, elem_type(Fp)}(O, A, _image, _preimage)

  return A, OtoA
end

function AlgAss(A::Generic.MatAlgebra{T}) where { T <: FieldElem }
  n = A.n
  K = base_ring(A)
  n2 = n^2
  # We use the matrices M_{ij} with a 1 at row i and column j and zeros everywhere else as the basis for A.
  # We sort "column major", so A[i + (j - 1)*n] corresponds to the matrix M_{ij}.
  # M_{ik}*M_{lj} = 0, if k != l, and M_{ik}*M_{kj} = M_{ij}
  mult_table = zeros(K, n2, n2, n2)
  oneK = one(K)
  for j = 0:n:(n2 - n)
    for k = 1:n
      kn = (k - 1)*n
      for i = 1:n
        mult_table[i + kn, k + j, i + j] = oneK
      end
    end
  end
  oneA = zeros(K, n2)
  for i = 1:n
    oneA[i + (i - 1)*n] = oneK
  end
  A = AlgAss(K, mult_table, oneA)
  A.iscommutative = ( n == 1 ? 1 : 2 )
  return A
end

function AlgAss(A::AlgAss)
  R = base_ring(A)
  d = dim(A)
  return A, hom(A, A, identity_matrix(R, d), identity_matrix(R, d))
end

###############################################################################
#
#  String I/O
#
################################################################################

function show(io::IO, A::AlgAss)
  print(io, "Associative algebra of dimension ", dim(A), " over ", base_ring(A))
end

################################################################################
#
#  Deepcopy
#
################################################################################

function Base.deepcopy_internal(A::AlgAss{T}, dict::IdDict) where {T}
  B = AlgAss{T}(base_ring(A))
  for x in fieldnames(typeof(A))
    if x != :base_ring && isdefined(A, x)
      setfield!(B, x, Base.deepcopy_internal(getfield(A, x), dict))
    end
  end
  B.base_ring = A.base_ring
  return B
end

################################################################################
#
#  Equality
#
################################################################################

function ==(A::AlgAss, B::AlgAss)
  base_ring(A) != base_ring(B) && return false
  if iszero(A) != iszero(B)
    return false
  end
  if iszero(A) && iszero(B)
    return true
  end
  if has_one(A) != has_one(B)
    return false
  end
  if has_one(A) && has_one(B) && A.one != B.one
    return false
  end
  return multiplication_table(A, copy = false) == multiplication_table(B, copy = false)
end

################################################################################
#
#  Subalgebra
#
################################################################################

# Builds a multiplication table for the subalgebra of A with basis matrix B.
# We assume ncols(B) == dim(A).
# A rref of B will be computed IN PLACE! If return_LU is Val{true}, a LU-factorization
# of transpose(rref(B)) is returned.
function _build_subalgebra_mult_table!(A::AlgAss{T}, B::MatElem{T}, return_LU::Type{Val{S}} = Val{false}) where { T, S }
  K = base_ring(A)
  n = dim(A)
  r = rref!(B)
  if r == 0
    if return_LU == Val{true}
      return Array{elem_type(K), 3}(undef, 0, 0, 0), PermGroup(ncols(B))(), zero_matrix(K, 0, 0), zero_matrix(K, 0, 0)
    else
      return Array{elem_type(K), 3}(undef, 0, 0, 0)
    end
  end

  basis = Vector{elem_type(A)}(undef, r)
  for i = 1:r
    basis[i] = elem_from_mat_row(A, B, i)
  end

  _, p, L, U = lu(transpose(B))

  mult_table = Array{elem_type(K), 3}(undef, r, r, r)
  c = A()
  d = zero_matrix(K, n, 1)
  for i = 1:r
    for j = 1:r
      if iscommutative(A) && j < i
        continue
      end
      c = mul!(c, basis[i], basis[j])
      for k = 1:n
        d[p[k], 1] = c.coeffs[k]
      end
      d = solve_lt(L, d)
      d = solve_ut(U, d)
      for k = 1:r
        mult_table[i, j, k] = deepcopy(d[k, 1])
        if iscommutative(A) && i != j
          mult_table[j, i, k] = deepcopy(d[k, 1])
        end
      end
    end
  end

  if return_LU == Val{true}
    return mult_table, p, L, U
  else
    return mult_table
  end
end

@doc Markdown.doc"""
     subalgebra(A::AlgAss{T}, e::AlgAssElem{T, AlgAss{T}}, idempotent::Bool = false, action::Symbol = :left) where {T}

Returns the algebra e*A (if action == :left) or A*e (if action == :right) and
a map from this algebra to A.
"""
function subalgebra(A::AlgAss{T}, e::AlgAssElem{T, AlgAss{T}}, idempotent::Bool = false, action::Symbol = :left) where {T}
  @assert parent(e) == A
  R = base_ring(A)
  n = dim(A)
  B = representation_matrix(e, action)

  mult_table, p, L, U = _build_subalgebra_mult_table!(A, B, Val{true})
  r = size(mult_table, 1)

  if r == 0
    eA = _zero_algebra(R)
    return eA, hom(eA, A, zero_matrix(R, 0, n))
  end

  # The basis matrix of e*A resp. A*e with respect to A is
  basis_mat_of_eA = sub(B, 1:r, 1:n)

  if idempotent
    c = A()
    d = zero_matrix(R, n, 1)
    for k = 1:n
      d[p[k], 1] = e.coeffs[k]
    end
    d = solve_lt(L, d)
    d = solve_ut(U, d)
    v = Vector{elem_type(R)}(undef, r)
    for i in 1:r
      v[i] = d[i, 1]
    end
    eA = AlgAss(R, mult_table, v)
  else
    eA = AlgAss(R, mult_table)
  end

  if A.iscommutative == 1
    eA.iscommutative = 1
  end

  if idempotent
    # We have the map eA -> A, given by the multiplying with basis_mat_of_eA.
    # But there is also the canonical projection A -> eA, a -> ea.
    # We compute the corresponding matrix.
    B = representation_matrix(e, action)
    C = zero_matrix(R, n, r)
    for i in 1:n
      for k = 1:n
        d[p[k], 1] = B[i, k]
      end
      d = solve_lt(L, d)
      d = solve_ut(U, d)
      for k in 1:r
        C[i, k] = d[k, 1]
      end
    end
    eAtoA = hom(eA, A, basis_mat_of_eA, C)
  else
    eAtoA = hom(eA, A, basis_mat_of_eA)
  end
  return eA, eAtoA
end

@doc Markdown.doc"""
    subalgebra(A::AlgAss{T}, basis::Vector{AlgAssElem{T, AlgAss{T}}}) where T

Returns the subalgebra of A generated by the elements in basis and a map
from this algebra to A.
"""
function subalgebra(A::AlgAss{T}, basis::Vector{AlgAssElem{T, AlgAss{T}}}) where T
  M = zero_matrix(base_ring(A), dim(A), dim(A))
  for i = 1:length(basis)
    elem_to_mat_row!(M, i, basis[i])
  end
  mt = _build_subalgebra_mult_table!(A, M)
  B = AlgAss(base_ring(A), mt)
  return B, hom(B, A, sub(M, 1:length(basis), 1:dim(A)))
end

###############################################################################
#
#  Trace Matrix
#
###############################################################################

function _assure_trace_basis(A::AlgAss{T}) where T
  if !isdefined(A, :trace_basis_elem)
    A.trace_basis_elem = Array{T, 1}(undef, dim(A))
    for i=1:length(A.trace_basis_elem)
      A.trace_basis_elem[i]=sum(multiplication_table(A, copy = false)[i,j,j] for j= 1:dim(A))
    end
  end
  return nothing
end

function trace_matrix(A::AlgAss)
  _assure_trace_basis(A)
  F = base_ring(A)
  n = dim(A)
  M = zero_matrix(F, n, n)
  for i = 1:n
    M[i,i] = tr(A[i]^2)
  end
  for i = 1:n
    for j = i+1:n
      x = tr(A[i]*A[j])
      M[i,j] = x
      M[j,i] = x
    end
  end
  return M
end

################################################################################
#
#  Radical
#
################################################################################

@doc Markdown.doc"""
     radical(A::AlgAss{T}) where { T <: Union{ gfp_elem, Generic.ResF{fmpz}, fmpq, nf_elem } }

Given an algebra over a finite field of prime order, this function
returns the radical of A.
"""
function radical(A::AlgAss{T}) where { T <: Union{ gfp_elem, Generic.ResF{fmpz}, fmpq, nf_elem } }
  return ideal_from_gens(A, _radical(A), :twosided)
end

# Section 2.3.2 in W. Eberly: Computations for Algebras and Group Representations
function _radical(A::AlgAss{T}) where { T <: Union{ gfp_elem, Generic.ResF{fmpz} } }
  F = base_ring(A)
  p = characteristic(F)
  l = clog(fmpz(dim(A)), p)
  # First step: kernel of the trace matrix
  I = trace_matrix(A)
  k, B = nullspace(I)
  # The columns of B give the coordinates of the elements in the order.
  if k == 0
    return elem_type(A)[]
  end
  C = transpose(B)
  if l == 1 && dim(A) != p
    # In this case, we can output I: it is the standard p-trace method.
    return elem_type(A)[ elem_from_mat_row(A, C, i) for i = 1:nrows(C) ]
  end
  # Now, iterate: we need to find the kernel of tr((xy)^(p^i))/p^i mod p
  # on the subspace generated by C
  # Hard to believe, but this is linear!!!!
  pi = fmpz(1)
  for i = 1:l
    pi = p*pi
    M = zero_matrix(F, dim(A), nrows(C))
    for t = 1:nrows(C)
      elm = elem_from_mat_row(A, C, t)
      for s = 1:dim(A)
        a = elm*A[s]
        M1 = representation_matrix(a)
        M2 = zero_matrix(FlintZZ, nrows(M1), ncols(M1))
        for j = 1:nrows(M1)
          for k = 1:ncols(M1)
            M2[j, k] = lift(M1[j, k])
          end
        end
        el = tr(M2^Int(pi))
        @assert iszero(mod(el, pi))
        M[s, t] = F(divexact(el, pi))
      end
    end
    k, B = nullspace(M)
    if k == 0
      return elem_type(A)[]
    end
    C = transpose(B)*C
  end
  return elem_type(A)[ elem_from_mat_row(A, C, i) for i = 1:nrows(C) ]
end

function _radical(A::AlgAss{T}) where { T <: Union{ fmpq, nf_elem } }
  M = trace_matrix(A)
  n, N = nullspace(M)
  b = Vector{elem_type(A)}(undef, n)
  t = zeros(base_ring(A), dim(A))
  for i = 1:n
    for j = 1:dim(A)
      t[j] = N[j, i]
    end
    b[i] = A(t)
  end
  return b
end

###############################################################################
#
#  Center
#
###############################################################################

function _rep_for_center(M::T, A::AlgAss) where T<: MatElem
  n=dim(A)
  for i=1:n
    for j = 1:n
      for k = 1:n
        M[k+(i-1)*n, j] = multiplication_table(A, copy = false)[i, j, k]-multiplication_table(A, copy = false)[j, i, k]
      end
    end
  end
  return nothing
end

@doc Markdown.doc"""
    center(A::AlgAss{T}) where T

Returns the center C of A and the inclusion C \to A.
"""
function center(A::AlgAss{T}) where {T}
  if iscommutative(A)
    B, mB = AlgAss(A)
    return B, mB
  end
  if isdefined(A, :center)
    return A.center::Tuple{AlgAss{T}, morphism_type(AlgAss{T}, AlgAss{T})}
  end
  n=dim(A)
  M=zero_matrix(base_ring(A), n^2, n)
  # I concatenate the difference between the right and left representation matrices.
  _rep_for_center(M,A)
  k,B=nullspace(M)
  res=Array{elem_type(A),1}(undef, k)
  for i=1:k
    res[i]= A(T[B[j,i] for j=1:n])
  end
  C, mC = subalgebra(A, res)
  A.center = C, mC
  return C, mC
end

################################################################################
#
#  Change of ring
#
################################################################################

@doc Markdown.doc"""
    restrict_scalars(A::AlgAss{nf_elem}, Q::FlintRationalField)
    restrict_scalars(A::AlgAss{fq_nmod}, Fp::GaloisField)
    restrict_scalars(A::AlgAss{fq}, Fp::Generic.ResField{fmpz})

Given an algebra over a field L and the prime field K of L, this function
returns the the restriction B of A to K and maps from A to B and from B to A.
"""
# Top level functions to avoid "type mix-ups" (like AlgAss{fq_nmod} with FlintQQ)
function restrict_scalars(A::AlgAss{nf_elem}, Q::FlintRationalField)
  return _restrict_scalars_to_prime_field(A, Q)
end

function restrict_scalars(A::AlgAss{fq_nmod}, Fp::GaloisField)
  return _restrict_scalars_to_prime_field(A, Fp)
end

function restrict_scalars(A::AlgAss{fq}, Fp::Generic.ResField{fmpz})
  return _restrict_scalars_to_prime_field(A, Fp)
end

function restrict_scalars(A::AlgAss{gfp_elem}, Fp::GaloisField)
  function AtoA(x::AlgAssElem)
    return x
  end
  return A, AtoA, AtoA
end

function restrict_scalars(A::AlgAss{Generic.ResF{fmpz}}, Fp::Generic.ResField{fmpz})
  function AtoA(x::AlgAssElem)
    return x
  end
  return A, AtoA, AtoA
end

function _restrict_scalars_to_prime_field(A::AlgAss{T}, prime_field::Union{FlintRationalField, GaloisField, Generic.ResField{fmpz}}) where { T <: Union{nf_elem, fq_nmod, fq} }
  K = base_ring(A)
  n = dim(A)
  m = degree(K)
  nm = n*m
  a = gen(K)
  # We use A[1], a*A[1], ..., a^{m - 1}*A[1], ..., A[n], ..., a^{m - 1}*A[n] as
  # the basis for A over the prime field.
  # Precompute the powers a^k:
  powers_of_a = zeros(K, 2*m - 1)
  powers_of_a[1] = one(K)
  for k = 2:2*m - 1
    powers_of_a[k] = mul!(powers_of_a[k], powers_of_a[k - 1], a)
  end

  function _new_coeffs(x)
    y = Vector{elem_type(prime_field)}(undef, nm)
    yy = coeffs(x, copy = false)
    for i = 1:n
      for j = 1:m
        if prime_field == FlintQQ
          y[(i - 1)*m + j] = coeff(yy[i], j - 1)
        else
          y[(i - 1)*m + j] = prime_field(coeff(yy[i], j - 1))
        end
      end
    end
    return y
  end

  m1 = m - 1
  mult_table = zeros(prime_field, nm, nm, nm)
  Aij = A()
  t = A()
  for i = 1:n
    for j = 1:n
      Aij = mul!(Aij, A[i], A[j])
      if iszero(Aij)
        continue
      end

      mi = m*(i - 1)
      mj = m*(j - 1)
      for s = 0:2*m1 # all possible sums of exponents for a
        t = mul!(t, powers_of_a[s + 1], Aij)
        tcoeffs = _new_coeffs(t)
        for k = max(0, s - m1):min(s, m1)
          mult_table[mi + k + 1, mj + s - k + 1, :] = tcoeffs
        end
      end
    end
  end
  B = AlgAss(prime_field, mult_table, _new_coeffs(one(A)))
  B.iscommutative = A.iscommutative

  function AtoB(x)
    @assert parent(x) == A
    return B(_new_coeffs(x))
  end

  function BtoA(x)
    @assert parent(x) == B
    if prime_field == FlintQQ
      R = parent(K.pol)
    else
      R, z = PolynomialRing(prime_field, "z", cached = false)
    end
    y = Vector{elem_type(K)}(undef, n)
    xcoeffs = coeffs(x) # a copy
    for i = 1:n
      y[i] = K(R(xcoeffs[(i - 1)*m + 1:(i - 1)*m + m]))
    end
    return A(y)
  end

  return B, AtoB, BtoA
end

function restrict_scalars(A::AlgAss{nf_elem}, KtoL::NfToNfMor)
  K = domain(KtoL)
  L = codomain(KtoL)
  @assert L == base_ring(A)
  n = dim(A)
  m = div(degree(L), degree(K))
  nm = n*m
  a = gen(L)
  powers_of_a = zeros(L, 2*m - 1)
  powers_of_a[1] = one(L)
  for k = 2:2*m - 1
    powers_of_a[k] = mul!(powers_of_a[k], powers_of_a[k - 1], a)
  end

  basisK = basis(K)
  basisKinL = map(KtoL, basisK)
  M = zero_matrix(FlintQQ, degree(L), degree(L))
  t = L()
  for i = 1:m
    for j = 1:degree(K)
      t = mul!(t, basisKinL[j], powers_of_a[i])
      for k = 1:degree(L)
        M[k, (i - 1)*m + j] = coeff(t, k - 1)
      end
    end
  end
  M = inv(M)

  function _new_coeffs(x)
    y = zeros(K, nm)
    yy = coeffs(x, copy = false)
    for i = 1:n
      c = matrix(FlintQQ, degree(L), 1, [ coeff(yy[i], j) for j = 0:degree(L) - 1 ])
      Mc = M*c
      for j = 1:m
        for k = 1:degree(K)
          y[(i - 1)*m + j] += Mc[(j - 1)*degree(K) + k, 1]*basisK[k]
        end
      end
    end
    return y
  end

  m1 = m - 1
  mult_table = zeros(K, nm, nm, nm)
  Aij = A()
  t = A()
  for i = 1:n
    for j = 1:n
      Aij = mul!(Aij, A[i], A[j])
      if iszero(Aij)
        continue
      end

      mi = m*(i - 1)
      mj = m*(j - 1)
      for s = 0:2*m1 # all possible sums of exponents for a
        t = mul!(t, powers_of_a[s + 1], Aij)
        tcoeffs = _new_coeffs(t)
        for k = max(0, s - m1):min(s, m1)
          mult_table[mi + k + 1, mj + s - k + 1, :] = tcoeffs
        end
      end
    end
  end
  B = AlgAss(K, mult_table, _new_coeffs(one(A)))
  B.iscommutative = A.iscommutative

  function AtoB(x)
    @assert parent(x) == A
    return B(_new_coeffs(x))
  end

  function BtoA(x)
    @assert parent(x) == B
    y = zeros(L, n)
    xcoeffs = coeffs(x)
    for i = 1:n
      xx = map(KtoL, xcoeffs[(i - 1)*m + 1:(i - 1)*m + m])
      for j = 1:m
        y[i] += xx[j]*powers_of_a[j]
      end
    end
    return A(y)
  end

  return B, AtoB, BtoA
end

function _as_algebra_over_center(A::AlgAss{T}) where { T <: Union{fmpq, gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod} }
  @assert !iszero(A)

  K = base_ring(A)
  C, CtoA = center(A)

  isfq = ( T === fq_nmod || T === fq )
  iscentral = ( dim(C) == 1 )

  if iscentral && isfq
    function AtoA(x::AlgAssElem)
      return x
    end
    return A, AtoA, AtoA
  end

  if T === fmpq
    fields = as_number_fields(C)
    @assert length(fields) == 1
    L, CtoL = fields[1]
  else
    L, CtoL = _as_field_with_isomorphism(C)
  end

  if iscentral
    mult_table_B = Array{elem_type(L), 3}(undef, dim(A), dim(A), dim(A))
    for i = 1:dim(A)
      for j = 1:dim(A)
        for k = 1:dim(A)
          mult_table_B[i, j, k] = L(multiplication_table(A, copy = false)[i, j, k])
        end
      end
    end
    if has_one(A)
      B = AlgAss(L, mult_table_B, map(L, A.one))
    else
      B = AlgAss(L, mult_table_B)
    end

    function AtoB(x::AlgAssElem)
      return B(map(L, coeffs(x, copy = false)))
    end

    function BtoA(x::AlgAssElem)
      return A([ K(coeff(c, 0)) for c in coeffs(x, copy = false) ])
    end
    return B, AtoB, BtoA
  end

  basisC = basis(C)
  basisCinA = Vector{elem_type(A)}(undef, dim(C))
  basisCinL = Vector{elem_type(L)}(undef, dim(C))
  for i = 1:dim(C)
    basisCinA[i] = CtoA(basisC[i])
    basisCinL[i] = CtoL(basisC[i])
  end

  # We construct a basis of A over C (respectively L) by using the following fact:
  # A subset M of basis(A) is a C-basis of A if and only if |M| = dim(A)/dim(C)
  # and all possible products of elements of M and basisCinA form a K-basis of A,
  # with K := base_ring(A).
  AoverK = basis(A)
  AoverC = Vector{Int}()
  M = zero_matrix(K, dim(C), dim(A))
  MM = zero_matrix(K, 0, dim(A))
  r = 0
  for i = 1:dim(A)
    b = AoverK[i]

    for j = 1:dim(C)
      elem_to_mat_row!(M, j, b*basisCinA[j])
    end

    N = vcat(MM, M)
    s = rank(N)
    if s > r
      push!(AoverC, i)
      MM = N
      r = s
    end
    if r == dim(A)
      break
    end
  end

  m = div(dim(A), dim(C))

  @assert length(AoverC) == m
  @assert nrows(MM) == dim(A)

  iMM = inv(MM)

  local _new_coeffs
  let L = L, K = K, iMM = iMM, basisCinL = basisCinL, C = C, m = m, isfq = isfq
    _new_coeffs = x -> begin
      y = zeros(L, m)
      xx = matrix(K, 1, dim(A), coeffs(x, copy = false))
      Mx = xx*iMM
      for i = 1:m
        for j = 1:dim(C)
          if isfq
            t = CtoL.RtoFq(CtoL.R(Mx[1, (i - 1)*dim(C) + j]))
            y[i] = addeq!(y[i], basisCinL[j]*t)
          else
            y[i] = addeq!(y[i], basisCinL[j]*Mx[1, (i - 1)*dim(C) + j])
          end
        end
      end
      return y
    end
  end

  mult_table = zeros(L, m, m, m)
  Aij = A()
  for i = 1:m
    for j = 1:m
      Aij = mul!(Aij, A[AoverC[i]], A[AoverC[j]])
      if iszero(Aij)
        continue
      end

      mult_table[i, j, :] = _new_coeffs(Aij)
    end
  end

  B = AlgAss(L, mult_table, _new_coeffs(one(A)))
  B.iscommutative = A.iscommutative

  local AtoB
  let B = B, _new_coeffs = _new_coeffs
    AtoB = x -> begin
      @assert parent(x) == A
      return B(_new_coeffs(x))
    end
  end

  local BtoA
  let K = K, MM = MM, CtoA = CtoA, CtoL = CtoL, AoverC = AoverC, B = B, m = m
    BtoA = x -> begin
      @assert parent(x) == B
      y = zeros(K, dim(A))
      xx = A()
      for i = 1:dim(B)
        t = CtoA(CtoL\coeffs(x, copy = false)[i])
        xx = add!(xx, xx, t*A[AoverC[i]])
      end
      return xx
    end
  end

  return B, AtoB, BtoA
end

################################################################################
#
#  Idempotents
#
################################################################################

# See W. Eberly "Computations for Algebras and Group Representations" p. 126.
function _find_non_trivial_idempotent(A::AlgAss{T}) where { T <: Union{gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod} }
  if dim(A) == 1
    error("Dimension of algebra is 1")
  end
  while true
    a = rand(A)
    if isone(a) || iszero(a)
      continue
    end
    mina = minpoly(a)
    if isirreducible(mina)
      if degree(mina) == dim(A)
        error("Algebra is a field")
      end
      continue
    end
    if issquarefree(mina)
      e = _find_idempotent_via_squarefree_poly(A, a, mina)
    else
      e = _find_idempotent_via_non_squarefree_poly(A, a, mina)
    end
    if isone(e) || iszero(e)
      continue
    end
    return e
  end
end

function _find_idempotent_via_non_squarefree_poly(A::AlgAss{T}, a::AlgAssElem{T}, mina::Union{gfp_poly, gfp_fmpz_poly, fq_poly, fq_nmod_poly}) where { T <: Union{gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod} }
  fac = factor(mina)
  if length(fac) == 1
    return zero(A)
  end
  sf_part = prod(keys(fac.fac))
  b = sf_part(a)
  # This is not really an algebra, only a right sided ideal
  bA, bAtoA = subalgebra(A, b, false, :left)

  # Find an element e of bA such that e*x == x for all x in bA
  M = zero_matrix(base_ring(A), dim(bA), 0)
  for i = 1:dim(bA)
    M = hcat(M, representation_matrix(bA[i], :right))
  end

  N = zero_matrix(base_ring(A), 0, 1)
  for i = 1:dim(bA)
    N = vcat(N, matrix(base_ring(A), dim(bA), 1, coeffs(bA[i])))
  end
  MN = hcat(transpose(M), N)
  r = rref!(MN)
  be = solve_ut(sub(MN, 1:r, 1:dim(bA)), sub(MN, 1:r, (dim(bA) + 1):(dim(bA) + 1)))
  e = bAtoA(bA([ be[i, 1] for i = 1:dim(bA) ]))
  return e
end

# A should be semi-simple
# See W. Eberly "Computations for Algebras and Group Representations" p. 89.
function _extraction_of_idempotents(A::AlgAss, only_one::Bool = false)
  Z, ZtoA = center(A)
  if dim(Z) == 1
    error("Dimension of centre is 1")
  end

  a = ZtoA(rand(Z))
  f = minpoly(a)
  while isirreducible(f)
    if degree(f) == dim(A)
      error("Cannot find idempotents (algebra is a field)")
    end
    a = ZtoA(rand(Z))
    f = minpoly(a)
  end

  fac = factor(f)
  fi = [ k for k in keys(fac.fac) ]
  l = length(fi)
  R = parent(f)
  if only_one
    r = zeros(R, l)
    r[1] = one(R)
    g = crt(r, fi)
    return g(a)
  else
    oneR = one(R)
    zeroR = zero(R)
    gi = Vector{elem_type(R)}(undef, l)
    r = zeros(R, l)
    for i = 1:l
      r[i] = oneR
      gi[i] = crt(r, fi)
      r[i] = zeroR
    end
    return [ g(a) for g in gi ]
  end
end

function _find_idempotent_via_squarefree_poly(A::AlgAss{T}, a::AlgAssElem{T}, mina::Union{gfp_poly, gfp_fmpz_poly, fq_poly, fq_nmod_poly}) where { T <: Union{gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod} }
  B = AlgAss(mina)
  idemB = _extraction_of_idempotents(B, true)

  e = dot(coeffs(idemB, copy = false), [ a^k for k = 0:(degree(mina) - 1) ])
  return e
end

function _primitive_idempotents(A::AlgAss{T}) where { T <: Union{gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod} }
  if dim(A) == 1
    return [ one(A) ]
  end

  e = _find_non_trivial_idempotent(A)

  idempotents = Vector{elem_type(A)}()

  eA, m1 = subalgebra(A, e, true, :left)
  eAe, m2 = subalgebra(eA, m1\e, true, :right)
  if dim(eAe) == dim(A)
    push!(idempotents, e)
  else
    idems = _primitive_idempotents(eAe)
    append!(idempotents, [ m1(m2(idem)) for idem in idems ])
  end

  f = (1 - e)
  fA, n1 = subalgebra(A, f, true, :left)
  fAf, n2 = subalgebra(fA, n1\f, true, :right)

  if dim(fAf) == dim(A)
    push!(idempotents, f)
  else
    idems = _primitive_idempotents(fAf)
    append!(idempotents, [ n1(n2(idem)) for idem in idems ])
  end

  return idempotents
end

################################################################################
#
#  Matrix Algebra
#
################################################################################

# This computes a "matrix type" basis for A.
# See W. Eberly "Computations for Algebras and Group Representations" p. 121.
function _matrix_basis(A::AlgAss{T}, idempotents::Vector{S}) where { T <: Union{gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod}, S <: AlgAssElem{T, AlgAss{T}} }
  k = length(idempotents)
  # Compute a basis e_ij of A (1 <= i, j <= k) with
  # e_11 + e_22 + ... + e_kk = 1 and e_rs*e_tu = \delta_st*e_ru.
  new_basis = Vector{elem_type(A)}(undef, k^2) # saved column major: new_basis[i + (j - 1)*k] = e_ij
  for i = 1:k
    new_basis[i + (i - 1)*k] = idempotents[i]
  end

  a = idempotents[1]
  for i = 2:k
    b = idempotents[i]
    e = a + b
    eA, m1 = subalgebra(A, e, true, :left)
    eAe, m2 = subalgebra(eA, m1\e, true, :right)

    aa = m2\(m1\(a))
    bb = m2\(m1\(b))

    # We compute an element x of eAe which fulfils
    # aa*x == x, bb*x == 0, x*aa == 0 and x*bb == x.
    M1 = representation_matrix(aa - one(eAe), :left)
    M2 = representation_matrix(bb, :left)
    M3 = representation_matrix(aa, :right)
    M4 = representation_matrix(bb - one(eAe), :right)

    M = hcat(M1, M2, M3, M4)
    xx = eAe(left_kernel_basis(M)[1])
    x = m1(m2(xx))

    new_basis[1 + (i - 1)*k] = x # this is e_1i

    # We compute an element y of eAe which fulfils
    # aa*y == 0, bb*y == y, y*aa == y, y*bb == 0, y*xx == bb, xx*y == aa.
    N1 = representation_matrix(aa, :left)
    N2 = representation_matrix(bb - one(eAe), :left)
    N3 = representation_matrix(aa - one(eAe), :right)
    N4 = representation_matrix(bb, :right)
    N5 = representation_matrix(xx, :right)
    N6 = representation_matrix(xx, :left)
    N = hcat(N1, N2, N3, N4, N5, N6)
    NN = zero_matrix(base_ring(A), 4*dim(eAe), 1)
    NN = vcat(NN, matrix(base_ring(A), dim(eAe), 1, coeffs(bb)))
    NN = vcat(NN, matrix(base_ring(A), dim(eAe), 1, coeffs(aa)))
    b, yy = can_solve(transpose(N), NN)
    @assert b
    y = m1(m2(eAe([ yy[i, 1] for i = 1:dim(eAe) ])))

    new_basis[i] = y # this is e_i1
  end

  for j = 2:k
    jk = (j - 1)*k
    e1j = new_basis[1 + jk]
    for i = 2:k
      new_basis[i + jk] = new_basis[i]*e1j # this is e_ij
    end
  end
  return new_basis
end

# Assumes that A is central and isomorphic to a matrix algebra of base_ring(A)
function _as_matrix_algebra(A::AlgAss{T}) where { T <: Union{gfp_elem, Generic.ResF{fmpz}, fq, fq_nmod}, S <: AlgAssElem{T, AlgAss{T}} }

  idempotents = _primitive_idempotents(A)
  @assert length(idempotents)^2 == dim(A)
  Fq = base_ring(A)

  B = AlgMat(Fq, length(idempotents))

  matrix_basis = _matrix_basis(A, idempotents)

  # matrix_basis is another basis for A. We build the matrix for the basis change.
  M = zero_matrix(Fq, dim(A), dim(A))
  for i = 1:dim(A)
    elem_to_mat_row!(M, i, matrix_basis[i])
  end
  return B, hom(A, B, inv(M), M)
end
