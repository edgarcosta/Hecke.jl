add_verbose_scope(:AbExt)
add_assert_scope(:AbExt)

##############################################################################
#
#  Sieves for primes and squarefree numbers
#
##############################################################################

function squarefree_up_to(n::Int; coprime_to::Array{fmpz,1}=fmpz[])

  list= trues(n)
  for x in coprime_to
    t=x
    while t<= n
      @inbounds list[Int(t)]=false
      t+=x
    end
  end
  i=2
  b=Base.sqrt(n)
  while i<=b
    @inbounds if list[i]
      j=i^2
      @inbounds if !list[j]
        i+=1
        continue
      else 
        @inbounds list[j]=false
        t=2*j
        while t<= n
          @inbounds list[t]=false
          t+=j
        end
      end
    end
    i+=1
  end
  @inbounds return Int[i for i=1:n if list[i]]

end

function SqfSet(n::fmpz; coprime_to::Int=-1)
  return (i for i=-n:n if i!= -1 && i!=0 && issquarefree(i))
end

function primes_up_to(n::Int)
  
  list= trues(n)
  list[1]=false
  i=2
  s=4
  while s<=n
    list[s]=false
    s+=2
  end
  i=3
  b=sqrt(n)
  while i<=b
    if list[i]
      j=3*i
      s=2*i
      while j<= n
        list[j]=false
        j+=s
      end
    end
    i+=1
  end
  return Int[i for i=1:n if list[i]]
  
end

                                                                
                                                                               
###########################################################################
#
#  Some useful functions
#
###########################################################################

#This function gets a quotient of the ray class group and the action on
# the ray class group
# In output, we get the quotient group as a ZpnGModule

function _action_on_quo(mq::GrpAbFinGenMap, act::Array{GrpAbFinGenMap,1})
  
  q=mq.header.codomain
  S,mS=snf(q)
  n=Int(S.snf[end])
  R=ResidueField(FlintZZ, n, cached=false)
  quo_action=Array{nmod_mat,1}(undef, length(act))
  for s=1:length(act)
    quo_action[s]= change_base_ring(mS.map*act[i].map*mS.imap, R)
  end
  return ZpnGModule(S, quo_action)

end


# Function that finds an integer in the ideal 
function _min_wild(D::Dict{NfOrdIdl, Int})

  res = fmpz(1)
  primes_done=fmpz[]
  for (p,v) in D
    s=minimum(p)
    if s in primes_done
      continue
    end
    push!(primes_done, s)
    res*=s^v
  end  
  return res  

end

function totally_positive_generators(mr::MapRayClassGrp, wild::Bool=false)
  
  a = minimum(mr.modulus_fin)
  if isdefined(mr, :tame_mult_grp)
    tmg=mr.tame_mult_grp
    for (p, v) in tmg
      new_p = GrpAbFinGenToNfAbsOrdMap(domain(v), codomain(v), [ make_positive(v.generators[1], a) ], v.discrete_logarithm)
      if isdefined(v, :disc_log)
        new_p.disc_log = v.disc_log
      end
      tmg[p] = new_p
      @hassert :RayFacElem 1 istotally_positive(mr.tame_mult_grp[p].generators[1])
    end
  end
  if wild && isdefined(mr, :wild_mult_grp)
    wld=mr.wild_mult_grp
    for (p,v) in wld
      x=v.generators
      for i=1:length(x)
        x[i]=make_positive(x[i],a)
        @hassert :RayFacElem 1 iscoprime(ideal(parent(x[i]), x[i]), ideal(parent(x[i]), a))
      end
      mr.wild_mult_grp[p] = GrpAbFinGenToNfAbsOrdMap(domain(v), codomain(v), x, v.discrete_logarithm)
    end 
  end

end

function make_positive(x::NfOrdElem, a::fmpz)
 
  els=conjugates_real(elem_in_nf(x))
  m=fmpz(0)
  for i=1:length(els)
    y = BigFloat(midpoint(els[i]/a))
    if y > 0
      continue
    else
      m = max(m,1-ceil(fmpz,y))
    end
  end
  @hassert :RayFacElem 1 iscoprime(ideal(parent(x),x), ideal(parent(x), a))
  @hassert :RayFacElem 1 iscoprime(ideal(parent(x),x+fmpz(m)*a), ideal(parent(x), a))
  @hassert :RayFacElem 1 istotally_positive(x+m*a)
  return x+fmpz(m)*a
    
end

function _are_there_subs(G::GrpAbFinGen,gtype::Array{Int,1})

  H=DiagonalGroup(gtype)
  H, _=snf(H)
  G1, _=snf(G)
  if length(G1.snf)<length(H.snf)
    return false
  end
  for i=0:length(H.snf)-1
    if !divisible(G1.snf[end-i],H.snf[end-i])
      return false
    end
  end
  return true
end

function issquarefree(n::Union{Int,fmpz})
  if iszero(n)
    throw(error("Argument must be non-zero"))
  end
  return isone(abs(n)) || maximum(values(factor(n).fac)) == 1
end


##########################################################################################################
#
#  Functions for conductors
#
##########################################################################################################

function tame_conductors_degree_2(O::NfOrd, bound::fmpz)
 
  K=nf(O)
  d=degree(O)
  b1=Int(root(bound,d))
  ram_primes=collect(keys(factor(O.disc).fac))
  sort!(ram_primes)
  filter!(x -> x!=2 ,ram_primes)
  list=squarefree_up_to(b1, coprime_to=vcat(ram_primes,2))

  extra_list=Tuple{Int, fmpz}[(1,fmpz(1))]
  for q in ram_primes
    tr=prime_decomposition_type(O,Int(q))
    e=tr[1][2]
    nq=fmpz(q)^(divexact(d,e))
    if nq> bound
      break
    end
    l=length(extra_list)
    for i=1:l
      n=extra_list[i][2]*nq
      if n> bound
        continue
      end
      push!(extra_list, (extra_list[i][1]*q, n))
    end
  end
  
  final_list=Tuple{Int,fmpz}[]
  l=length(list)
  for (el,norm) in extra_list
    for i=1:l
      if fmpz(list[i])^d*norm>bound
        continue
      end
      push!(final_list, (list[i]*el, fmpz(list[i])^d*norm))
    end
  end
  return final_list
  
end

function squarefree_for_conductors(O::NfOrd, n::Int, deg::Int; coprime_to::Array{fmpz,1}=fmpz[])
  
  sqf= trues(n)
  primes= trues(n)
  
  #remove primes that can be wildly ramified or
  #that are ramified in the base field
  for x in coprime_to
    el=Int(x)
    t=el
    while t<= n
      @inbounds sqf[t]=false
      @inbounds primes[t]=false
      t+=el
    end
  end
  
  #sieving procedure
  
  if !(2 in coprime_to)
    dt=prime_decomposition_type(O,2)
    if gcd(2^dt[1][1]-1, deg)==1
      j=2
      while j<=n
        @inbounds sqf[j]=false
        @inbounds primes[j]=false
        j+=2
      end
    else 
      i=2
      s=4
      while s<=n
        @inbounds primes[s]=false
        s+=2
      end
      s=4
      while s<=n
        @inbounds sqf[s]=false
        s+=4
      end
    end
  end
  i=3
  b=Base.sqrt(n)
  while i<=b
    if primes[i]
      dt = prime_decomposition_type(O, i)
      if gcd(deg, i^dt[1][1]-1) == 1
        @inbounds primes[i] = false
        @inbounds sqf[i] = false
        j = i
        while j <= n
         @inbounds primes[j] = false
         @inbounds sqf[j] = false
         j+=i
        end
      else 
        j=i
        while j <= n
          @inbounds primes[j]=false
          j+=i
        end
        j=i^2
        t=j
        while j<= n
          @inbounds sqf[j]=false
          j+=t
        end
      end
    end
    i+=2
  end
  while i<=n
    if primes[i]
      dt=prime_decomposition_type(O,i)
      if gcd(deg,i^dt[1][1]-1)==1
        @inbounds sqf[i]=false
        j=i
        while j<= n
         @inbounds sqf[j]=false
         j+=i
        end
      end
    end
    i+=2
  end
  
  if degree(O)==1
    i=2
    while i<=length(sqf)
      @inbounds sqf[i]=false
      i+=4
    end
    
  end
   
  return Int[i for i=1:length(sqf) if sqf[i]]
  
end

function conductors_tame(O::NfOrd, n::Int, bound::fmpz)

  if n==2
    return tame_conductors_degree_2(O,bound)
  end
  #
  #  First, conductors coprime to the ramified primes and to the 
  #  degree of the extension we are searching for.
  # 
  d=degree(O)
  K=nf(O)
  wild_ram=collect(keys(factor(fmpz(n)).fac))
  ram_primes=collect(keys(factor(O.disc).fac))
  filter!(x -> !divisible(fmpz(n),x), ram_primes)
  coprime_to=cat(ram_primes, wild_ram, dims = 1)
  sort!(ram_primes)
  m=minimum(wild_ram)
  k=divexact(n,m)
  b1=Int(root(fmpz(bound),Int(degree(O)*(m-1)*k))) 
  list = squarefree_for_conductors(O, b1, n, coprime_to=coprime_to)
  e = Int((m-1)*k)
  extra_list = Tuple{Int, fmpz}[(1, fmpz(1))]
  for q in ram_primes
    tr = prime_decomposition_type(O, Int(q))
    f = tr[1][1]
    nq = q^f 
    if gcd(nq-1,n) == 1
      continue
    end
    nq = nq^(length(tr)*e)
    if nq > bound
      continue
    end
    l = length(extra_list)
    for i=1:l
      no = extra_list[i][2]*nq
      if no > bound
        continue
      end
      push!(extra_list, (extra_list[i][1]*q, no))
    end
  end
  
  final_list=Tuple{Int, fmpz}[]
  l=length(list)
  e = Int((m-1)*k)
  for (el,norm) in extra_list
    for i=1:l
      if (list[i]^(e*d)) * norm > bound
        continue
      end
      push!(final_list, (list[i]*el, (fmpz(list[i])^(e*d))*norm))
    end
  end
  
  return final_list
end


function conductors(O::NfOrd, a::Array{Int, 1}, bound::fmpz, tame::Bool=false)
  
  #Careful: I am assuming that a is in snf!
  
  K=nf(O)
  d=degree(O)
  n = prod(a)
  expo = a[end]
  wild_ram=collect(keys(factor(fmpz(n)).fac))

  #
  # First, conductors for tamely ramified extensions
  #

  list = conductors_tame(O, n, bound)
  
  if tame
    return Tuple{Int, Dict{NfOrdIdl, Int}}[(x[1], Dict{NfOrdIdl, Int}()) for x in list]  
  end
  #
  # now, we have to multiply the obtained conductors by proper powers of wildly ramified ideals. 
  #
  wild_list=Tuple{Int, Dict{NfOrdIdl, Int}, fmpz}[(1, Dict{NfOrdIdl, Int}(), fmpz(1))]
  for q in wild_ram
    lp = prime_decomposition(O,Int(q))
    fq = divexact(d,lp[1][2]*length(lp))
    l = length(wild_list)
    sq = fmpz(q)^(divexact(d,lp[1][2])) #norm of the squarefree part of the integer q
    #=
      we have to use the conductor discriminant formula to understand the maximal possible exponent of q.
      Let ap be the exponent of p in the relative discriminant, let m be the conductor and h_(m,C) the cardinality of the 
      quotient of ray class group by its subgroup C.
      Then 
          ap= v_p(m)h_(m,C)- sum_{i=1:v_p(m)} h_(m/p^i, C)
      Since m is the conductor, h_(m/p^i, C)<= h_(m,C)/q.
      Consequently, we get
        v_p(m)<= (q*ap)/(h_(m,C)*(q-1))
      To find ap, it is enough to compute a logarithm.
    =#
    nisc = gcd(q^(fq)-1, expo)
    v = valuation(expo, q)
    #Bound coming from the analysis on the different in a local extension
    nbound = q^v + lp[1][2] * v * q^v - 1
    boundsubext = root(bound, Int(divexact(n, q^v)))
    #Bound coming from the bound on the discriminant
    obound = flog(boundsubext, sq)
    #Bound coming from ramification groups
    tbound = obound
    #=
    if v == 1
      k = div(lp[1][2]*q, q-1)
      tbound = (k+1)*(q-1)
    end
    if v == 2
      k = div(lp[1][2]*q^v, q-1)
      tbound = q*(q-1) + (k-q+1)*(q^2-1)
    end
    if v == 3
      k = div(lp[1][2]*q^v, q-1)
      tbound = q*(q-1) + q*(q^2-1) + (k-q^2+1)*(q^3-1)
    end
    =#
    #@show (nbound, obound, tbound) 
    bound_max_ap = min(nbound, obound, tbound)  #bound on ap
    bound_max_exp = div(q*bound_max_ap, q^v*(q-1)) #bound on the exponent in the conductor
    if nisc != 1
      fnisc=minimum(keys(factor(nisc).fac))
      nq=sq^((fnisc-1)*(divexact(n, fnisc)))
      for s=1:l
        nn=nq*wild_list[s][3]
        if nn>bound
          continue
        end
        push!(wild_list, (q*wild_list[s][1], wild_list[s][2], nn))
      end
    end
    for i=2:bound_max_exp
      d1=Dict{NfOrdIdl, Int}()
      for j=1:length(lp)
        d1[lp[j][1]]=i
      end
      nq= sq^(i*(q-1)*divexact(n,q))
      for s=1:l
        nn=nq*wild_list[s][3]
        if nn>bound
          continue
        end
        d2 = merge(max, d1, wild_list[s][2]) 
        if nisc!=1
          push!(wild_list, (q*wild_list[s][1], d2, nn))
        else
          push!(wild_list, (wild_list[s][1], d2, nn))
        end
      end
    end
  end
  
  #the final list
  final_list=Tuple{Int, Dict{NfOrdIdl, Int}}[]
  for (el, nm) in list
    for (q,d,nm2) in wild_list
      if nm*nm2 > bound
        continue
      end
      push!(final_list, (el*q,d))
    end
  end
  return final_list
  
end

###############################################################################
#
#  Conductors over QQ
#
###############################################################################


function squarefree_for_conductorsQQ(O::NfOrd, n::Int, a::Array{Int, 1}; coprime_to::Array{fmpz,1}=fmpz[])
  
  G = map(Int, snf(DiagonalGroup(a))[1].snf)
  sqf= trues(n)
  primes= trues(n)
  deg = G[end]
  #remove primes that can be wildly ramified
  for x in coprime_to
    el=Int(x)
    t=el
    while t<= n
      @inbounds sqf[t]=false
      @inbounds primes[t]=false
      t+=el
    end
  end
  
  single = Array{Int, 1}()
  push!(single, 1)
  multiple = Array{Int, 1}()
  
  #sieving procedure
  #First, I can remove all the multiples of 2
  if !(2 in coprime_to)
    i=2
    while i<=length(sqf)
      @inbounds sqf[i]=false
      i+=2
    end
  end  

  i=3
  b=Base.sqrt(n)
  while i<=b
    if primes[i]
      if gcd(deg,i-1)==1
        @inbounds primes[i]=false
        @inbounds sqf[i]=false
        j=i
        while j<= n
         @inbounds primes[j]=false
         @inbounds sqf[j]=false
         j+=i
        end
      else 
        j=i
        while j<= n
          @inbounds primes[j]=false
          j+=i
        end
        j=i^2
        t=2*j
        while j<= n
          @inbounds sqf[j]=false
          j+=t
        end
      end
    end
    i+=2
  end
  while i<=n
    if primes[i]
      if gcd(deg,i-1) == 1
        @inbounds primes[i] = false
        @inbounds sqf[i]=false
        j = i
        while j <= n
         @inbounds sqf[j]=false
         j += i
        end
      end
    end
    i+=2
  end

  if length(G) > 1
    i = 3
    while i < n
      if primes[i]
        push!(single, i)
      elseif sqf[i]
        push!(multiple, i)
      end
      i += 2
    end
  elseif !isprime(deg)
    i = 3
    while i < n
      if primes[i] 
        if rem(i-1, deg) == 0
          push!(multiple, i)
        else
          push!(single, i)
        end
      elseif sqf[i]
        push!(multiple, i)
      end
      i += 2
    end
  else
    multiple = Int[i for i = 2:length(sqf) if sqf[i]]
  end
   
  return single, multiple 
  
end



function conductors_tameQQ(O::NfOrd, a::Array{Int, 1}, bound::fmpz)

  #
  #  First, conductors coprime to the ramified primes and to the 
  #  degree of the extension we are searching for.
  # 
  n = prod(a)
  wild_ram = collect(keys(factor(fmpz(n)).fac))
  m = minimum(wild_ram)
  k = divexact(n, m)
  b1 = Int(root(fmpz(bound),Int((m-1)*k))) 
  
  return squarefree_for_conductorsQQ(O, b1, a, coprime_to=wild_ram)

end

function conductorsQQ(O::NfOrd, a::Array{Int, 1}, bound::fmpz, tame::Bool=false)
  
  K = nf(O)
  d = degree(O)
  n = prod(a)
  expo = a[end]
  wild_ram = collect(keys(factor(fmpz(n)).fac))

  #
  # First, conductors for tamely ramified extensions
  #

  single, multiple = conductors_tameQQ(O,a,bound)

  if tame
    return multiple  
  end
  #
  # now, we have to multiply the obtained conductors by proper powers of wildly ramified ideals. 
  #
  wild_list=Tuple{Int, Int, fmpz}[(1, 1, 1)]
  for q in wild_ram
    l = length(wild_list)
    #=
      we have to use the conductor discriminant formula to understand the maximal possible exponent of q.
      Let ap be the exponent of p in the relative discriminant, let m be the conductor and h_(m,C) the cardinality of the 
      quotient of ray class group by its subgroup C.
      Then 
          ap= v_p(m)h_(m,C)- sum_{i=1:v_p(m)} h_(m/p^i, C)
      Since m is the conductor, h_(m/p^i, C)<= h_(m,C)/q.
      Consequently, we get
        v_p(m)<= (q*ap)/(h_(m,C)*(q-1))
      To find ap, it is enough to compute a logarithm.
    =#
    v = valuation(expo, q)
    
    #I don't need to give a bound for a_p on the big extension but only on the maximum extension of q-power order
    #This is the only thing that matters for the exponent of the conductor
    nisc = gcd(q-1,n)
    nbound = q^v + v * q^v - 1
    boundsubext = root(bound, Int(divexact(n, q^v)))
    obound = flog(boundsubext, q)
    nnbound = valuation_bound_discriminant(n, q)
    k = div(expo, Int(q)-1)
    tbound = nbound
    if v == 1
      tbound = (k+1)*(q-1)
    end
    if v == 2
      tbound = q*(q-1)+(k - q + 1)*(q^2-1)
    end
    bound_max_ap = min(nbound, obound, nnbound, tbound)  #bound on ap
    bound_max_exp = div(q*bound_max_ap, q^v*(q-1)) #bound on the exponent in the conductor
    if nisc != 1
      fnisc=minimum(keys(factor(nisc).fac))
      nq=fmpz(q)^((fnisc-1)*(divexact(n, fnisc)))
      for s=1:l
        nn=nq*wild_list[s][3]
        if nn>bound
          continue
        end
        push!(wild_list, (q*wild_list[s][1], wild_list[s][2], nn))
      end
    end
    t=(q-1)*divexact(n,q)
    for i=2:bound_max_exp
      nq= q^(i*t)
      for s=1:l
        nn=nq*wild_list[s][3]
        if nn>bound
          continue
        end
        push!(wild_list, (wild_list[s][1], wild_list[s][2]*q^i, nn))
      end
    end
  end
  
  #the final list
  final_list = Int[]
  exps = Int((minimum(wild_ram)-1)*divexact(n, minimum(wild_ram)))
  for el in multiple
    for (q,d,nm2) in wild_list
      if (fmpz(el)^exps)*nm2 > bound
        continue
      end
      push!(final_list, (el*q*d))
    end
  end
  
  for el in single
    for j = 2:length(wild_list)
      q,d,nm2 = wild_list[j]
      if (fmpz(el)^exps)*nm2 > bound
        continue
      end
      push!(final_list, (el*q*d))
    end
  end
  return final_list
  
end


###############################################################################
#
#  Abelian extensions
#
###############################################################################

function abelian_extensions(O::Union{FlintIntegerRing, FlintRationalField},
                            gtype::Vector{Int}, discriminant_bound::fmpz;
                            real::Bool = false,
                            tame::Bool = false)

  Qx, x = PolynomialRing(FlintQQ, "x", cached = false)
  K, _ = NumberField(x - 1, "a", cached = false)
  OK = maximal_order(K)
  l = abelian_extensions(OK, gtype, discriminant_bound,
                         real = real,
                         tame = tame)


  newlist = Vector{NfAbsNS}(undef, length(l))
  for j in 1:length(l)
    newlist[j], _ = number_field([Qx([coeff(coeff(f, i), 0) for i in 0:length(f)]) for f in l[j].abs_pol])
  end
  return newlist
end

function abelian_extensions(O::NfOrd, gtype::Array{Int,1}, absolute_discriminant_bound::fmpz; real::Bool=false, tame::Bool=false, with_autos::Type{Val{T}} = Val{false}) where T 
  
  K=nf(O) 
  @assert degree(K)==1
  gtype = map(Int, snf(DiagonalGroup(gtype))[1].snf)
  n = prod(gtype)
    
  expo = lcm(gtype)
    
  #Getting conductors
  l_conductors=conductorsQQ(O, gtype, absolute_discriminant_bound, tame)
  @vprint :AbExt 1 "Number of conductors: $(length(l_conductors)) \n"
  if with_autos==Val{true}
    fields = Tuple{NfRel_ns, Array{NfRel_nsToNfRel_nsMor,1}}[]
  else
    fields = NfRel_ns[]
  end

  #Now, the big loop
  for (i, k) in enumerate(l_conductors)
    @vprint :AbExt 1 "Conductor: $k \n"
    @vprint :AbExt 1 "Left: $(length(l_conductors) - i)\n"
    r,mr=Hecke.ray_class_groupQQ(O,k,!real,expo)
    if !Hecke._are_there_subs(r,gtype)
      continue
    end
    ls=subgroups(r,quotype=gtype, fun= (x, y) -> quo(x, y, false)[2])
    for s in ls
      C=ray_class_field(mr, s)
      if Hecke._is_conductor_minQQ(C,n) && Hecke.discriminant_conductorQQ(O,C,k,absolute_discriminant_bound,n)
        @vprint :AbExt 1 "New Field \n"
        L=number_field(C)
        if with_autos==Val{true}
          push!(fields,(L, automorphism_groupQQ(C)))
        else
          push!(fields, L)
        end
      end
    end
  end

  return fields

end


function abelian_normal_extensions(O::NfOrd, gtype::Array{Int,1}, absolute_discriminant_bound::fmpz; ramified_at_infplc::Bool=true, tame::Bool=false, absolute_galois_group::Symbol = :all,  with_autos::Type{Val{T}} = Val{false}, autos::Array{NfToNfMor,1}=NfToNfMor[]) where T 

  d=degree(O)
  if d==1
    return abelian_extensions(O, gtype, absolute_discriminant_bound, real=!ramified_at_infplc, tame=tame, with_autos=with_autos) 
  end

  K=nf(O) 
  n=prod(gtype)
  inf_plc=InfPlc[]
  
  if with_autos==Val{true}
    fields=Tuple{NfRel_ns,Vector{NfRel_nsToNfRel_nsMor{nf_elem}}}[]
  else
    fields=NfRel_ns[]
  end
  
  bound = div(absolute_discriminant_bound, abs(discriminant(O))^n)
  if bound == 0
    return fields
  end

  if mod(n,2)==0 && ramified_at_infplc
    inf_plc=real_places(K)
  end

  expo=lcm(gtype)
  C,mC=class_group(O)
  cgrp= gcd(n,order(C))!=1
  if cgrp
    S = prime_ideals_up_to(O, max(100,12*clog(abs(discriminant(O)),10)^2))
  end
  allow_cache!(mC)
  
  #
  # Getting a small set of generators
  # for the automorphisms group
  #
  if isempty(autos)
    Aut=Hecke.automorphisms(K)
    @assert length(Aut)==degree(O) #The field is normal over Q
    gens = Hecke.small_generating_set(Aut)
  else
    gens = autos
  end

  #Getting conductors
  l_conductors=conductors(O, gtype, bound, tame)
  @vprint :AbExt 1 "Number of conductors: $(length(l_conductors)) \n"
  

  #Now, the big loop
  for (i, k) in enumerate(l_conductors)
    @vprint :AbExt 1 "Conductor: $k \n"
    @vprint :AbExt 1 "Left: $(length(l_conductors) - i)\n"
    r,mr=ray_class_group_quo(O,expo,k[1], k[2],inf_plc)
    if !_are_there_subs(r,gtype)
      continue
    end
    if cgrp
        mr.prime_ideal_cache = S
    end
    act = induce_action(mr,gens)
    ls = stable_subgroups(r, act, op=(x, y) -> quo(x, y, false)[2], quotype = gtype)
    totally_positive_generators(mr)
    for s in ls
      @hassert :AbExt 1 order(codomain(s))==n
      C = ray_class_field(mr, s)
      if Hecke._is_conductor_min_normal(C) && Hecke.discriminant_conductor(C, bound)
        @vprint :AbExt 1 "New Field \n"
        L = number_field(C)
        if absolute_galois_group != :all
          autabs = absolute_automorphism_group(C, gens)
          G = generic_group(autabs, *)
          if absolute_galois_group == :_16T7
            if isisomorphic_to_16T7(G)
              @vprint :AbExt 1 "I found a field with Galois group 16T7 (C_2 x Q_8)\n"
              @vtime :AbExt 1 push!(fields, L)
            end
          elseif absolute_galois_group == :_8T5
            if isisomorphic_to_8T5(G)
              @vprint :AbExt 1 "I found a field with Galois group 8T5 (Q_8)\n"
              @vtime :AbExt 1 push!(fields, L)
            end
          else
            error("Group not supported (yet)")
          end
        else
          if with_autos==Val{true}
            push!(fields, (L, absolute_automorphism_group(C,gens))) 
          else
            push!(fields, L)
          end
        end
      end
    end
  end

  return fields

end

###############################################################################
#
#  Quadratic Extensions of Q
#
###############################################################################

function quadratic_extensions(bound::Int; tame::Bool=false, real::Bool=false, complex::Bool=false, with_autos::Type{Val{T}}=Val{false}) where T

  @assert !(real && complex)
  Qx,x=PolynomialRing(FlintQQ, "x")
  sqf=squarefree_up_to(bound)
  if real
    deleteat!(sqf,1)
  elseif complex
    sqf=Int[-i for i in sqf]
  else
    sqf= vcat(sqf[2:end], Int[-i for i in sqf])
  end
  if tame
    filter!( x -> mod(x,4)==1, sqf)
    return ( number_field(x^2-x+divexact(1-i,4), cached=false)[1] for i in sqf)
  end
  final_list=Int[]
  for i=1:length(sqf)
    if abs(sqf[i]*4)< bound
      @views push!(final_list,sqf[i])
      continue
    end
    if mod(sqf[i],4)==1
      @views push!(final_list,sqf[i])
    end
  end
  return ( mod(i,4)!=1 ? number_field(x^2-i, cached=false)[1] : number_field(x^2-x+divexact(1-i,4), cached = false)[1] for i in final_list)

end

function _quad_ext(bound::Int, only_real::Bool = false)
  
  Qx, x = PolynomialRing(FlintQQ, "x", cached = false)
  K = NumberField(x-1, cached = false, check = false)[1]
  sqf = squarefree_up_to(bound)
  final_list = Int[]
  for i=2:length(sqf)
    if abs(sqf[i]*4)< bound
      @views push!(final_list, sqf[i])
      continue
    end
    if mod(sqf[i], 4) == 1
      @views push!(final_list, sqf[i])
    end
  end
  if !only_real
    for i = 1:length(sqf)
      if abs(sqf[i]*4)< bound
        @views push!(final_list, -sqf[i])
        continue
      end
      if mod(sqf[i], 4) == 3
        @views push!(final_list, -sqf[i])
      end
    end
  end
  fields_list = Array{Tuple{AnticNumberField, Vector{NfToNfMor}, Vector{NfToNfMor}}, 1}(undef, length(final_list))
  for i = 1:length(final_list)
    if mod(final_list[i],4) != 1
      L, gL = number_field(x^2-final_list[i], cached=false, check = false)
      auts = NfToNfMor[hom(L, L, -gL, check = false)]
      emb = NfToNfMor[hom(K, L, one(L), check = false)]
      fields_list[i] = (L, auts, emb)
    else
      L, gL = number_field(x^2-x+divexact(1-final_list[i], 4), cached=false, check = false)
      auts = NfToNfMor[hom(L, L, 1-gL, check = false)]
      emb = NfToNfMor[hom(K, L, one(L), check = false)]
      fields_list[i] = (L, auts, emb)
    end
  end
  return fields_list

end




###############################################################################
#
#  C2 x C2 extensions of Q
#
###############################################################################

function C22_extensions(bound::Int)
  
  
  Qx,x=PolynomialRing(FlintZZ, "x")
  K, _=NumberField(x-1, cached = false)
  Kx,x=PolynomialRing(K,"x", cached=false)
  b1=ceil(Int,Base.sqrt(bound))
  n=2*b1+1
  pairs, sqf = _find_pairs(bound)
  poszero=b1+1
  return (_ext(Kx,x,i-poszero,j-poszero) for i=1:n for j=i+1:n if i != poszero && j != poszero && sqf[abs(i-poszero)] && sqf[abs(j-poszero)] && pairs[i,j])
  
end

function _C22_exts_abexts(bound::Int, only_real::Bool = false)
  Qx, x = PolynomialRing(FlintZZ, "x")
  if !only_real
    pairs, sqf = _find_pairs(bound)
    b1 = ceil(Int, Base.sqrt(bound))
    n = size(pairs, 1)
    poszero = b1+1
    return (_ext_with_autos(Qx, x, i-poszero, j-poszero) for i = 1:n for j = i+1:n if i != poszero && j != poszero && sqf[abs(i-poszero)] && sqf[abs(j-poszero)] && pairs[i,j])
  else
    pairs, sqf = _find_pairs_real(bound)
    b = length(sqf)
    sqfs = Int[i for i = 2:b if sqf[i]]
    res = Tuple{Int, Int}[(i, j) for i = 1:length(sqfs) for j = i+1:length(sqfs) if pairs[sqfs[i], sqfs[j]]]
    return (_ext_with_autos(Qx, x, sqfs[i], sqfs[j]) for (i, j) in res)
    #return (_ext_with_autos(Qx, x, sqfs[i], sqfs[j]) for i = 1:length(sqfs) for j = i+1:length(sqfs) if pairs[sqfs[i], sqfs[j]])
    #return (_ext_with_autos(Qx, x, i, j) for i = 2:b for j = i+1:b if sqf[i] && sqf[j] && pairs[i,j])
  end
end

function _ext_with_autos(Qx, x, i::Int, j::Int)
  first = i
  second = j
  g = gcd(i, j)
  if g != 1
    third = divexact(i*j, g^2)
    if gcd(first, third) == 1
      second = third
    elseif gcd(second, third) == 1
      first = third
    end
  end
  y1 = mod(first, 4)
  cp1 = Vector{fmpz}(undef, 3)
  cp1[3] = fmpz(1)
  if y1 != 1
    cp1[1] = fmpz(-first)
    cp1[2] = fmpz(0)
  else
    cp1[1] = fmpz(divexact(1-first,4))
    cp1[2] = fmpz(-1)
  end
  y2 = mod(second, 4)
  cp2 = Vector{fmpz}(undef, 3)
  cp2[3] = fmpz(1)
  if y2 != 1
    cp2[1] = fmpz(-second)
    cp2[2] = fmpz(0)
  else
    cp2[1] = fmpz(divexact(1-second, 4))
    cp2[2] = fmpz(-1)
  end
  return Qx(cp1), Qx(cp2)
end

function __get_term(a::fmpq_mpoly, exps::Vector{UInt})
   z = fmpq()
   ccall((:fmpq_mpoly_get_coeff_fmpq_ui, :libflint), Nothing,
         (Ref{fmpq}, Ref{fmpq_mpoly}, Ptr{UInt}, Ref{FmpqMPolyRing}),
         z, a, exps, parent(a))
   return z
end

function _C22_with_max_ord(l)
  list = Vector{Tuple{AnticNumberField, Vector{NfToNfMor}, Vector{NfToNfMor}}}()
  Qx, x = PolynomialRing(FlintQQ, "x", cached = false)
  K = NumberField(x-1, cached = false)[1]
  for (p1, p2) in l
    Kns, g = number_field(fmpz_poly[p1, p2])
    S, mS = simple_extension(Kns, check = false)
    d1 = discriminant(p1)
    d2 = discriminant(p2)
    cf = gcd(d1, d2)
    B = Vector{nf_elem}(undef, degree(S))
    B[1] = S(1)
    B[2] = mS\(g[1])
    B[3] = mS\(g[2])
    B[4] = B[2] * B[3]
    M = basis_mat(B)
    hnf_modular_eldiv!(M.num, M.den, :lowerleft)
    O = NfAbsOrd(S, FakeFmpqMat(M.num, M.den))
    O.disc = d1^2*d2^2
    d3 = numerator(discriminant(S))
    if d3 < 0 
      O.disc = -O.disc
    end
    O.index = divexact(d3, O.disc)
    if cf != 1
      fac = factor(cf)
      for (p, v) in fac
        O = pmaximal_overorder(O, p)        
      end
    end
    O.ismaximal = 1
    Hecke._set_maximal_order_of_nf(S, O) 
    coord1 = __get_term(mS.prim_img.data, UInt[1, 0])
    coord2 = __get_term(mS.prim_img.data, UInt[0, 1])
    auts = Vector{NfToNfMor}(undef, 2)
    if iszero(coeff(p1, 1))
      auts[1] = hom(S, S, (-coord1)*B[2]+coord2*B[3], check = false)
    else
      auts[1] = hom(S, S, 1+(-coord1)*B[2]+coord2*B[3], check = false)
    end
    if iszero(coeff(p2, 1))
      auts[2] = hom(S, S, coord1*B[2]+(-coord2)*B[3], check = false)
    else      
      auts[2] = hom(S, S, coord1*B[2]+1+(-coord2)*B[3], check = false)
    end
    cl_auts = Vector{NfToNfMor}(undef, 4)
    cl_auts[1] = id_hom(S)
    cl_auts[2] = auts[1]
    cl_auts[3] = auts[2]
    cl_auts[4] = auts[1] * auts[2]
    Hecke._set_automorphisms_nf(S, cl_auts)
    push!(list, (S, auts, NfToNfMor[hom(K, S, S(1), check = false)]))
  end
  return list
end

function _find_pairs_real(bound::Int)
  b1 = ceil(Int,Base.sqrt(bound))
  pairs = trues(b1, b1)
  
  #sieve for squarefree  
  list = trues(b1)
  i=2
  b=Base.sqrt(b1)
  while i<=b
    if list[i]
      j=i^2
      if !list[j]
        i+=1
        continue
      else 
        list[j]=false
        t = j + j
        while t <= b1
          list[t]=false
          t += j
        end
      end
    end
    i+=1
  end
  
  #counting extensions  
  for i = 2:b1
    if !list[i]
      continue
    end
    for j = i+1:b1
      if !list[j]
        continue
      end
      if pairs[i, j]
        third = divexact(i*j, gcd(i, j)^2)
        if abs(third) > b1
          pairs[i,j] = false
        else
          pairs[third, i] = false
          pairs[third, j] = false
          pairs[i, third] = false
          pairs[j, third] = false
          d1 = _discn(i)
          d2 = _discn(j)
          g1 = d1*d2
          if abs(g1) < b1
            continue
          end
          d3 = _discn(third)
          g2 = d1*d3
          if abs(g2)<b1
            continue
          end
          g3 = d2*d3
          if abs(g3)<b1
            continue
          end
          g = gcd(g1,g2,g3)
          if abs(g)<b1
            continue
          elseif check_disc(i, j, third, bound)
            pairs[i,j] = false
          end
        end
      end
    end
  end
  return pairs, list
  
end




function _find_pairs(bound::Int)
  
  b1=ceil(Int, Base.sqrt(bound))
  n=2*b1+1
  pairs = trues(n,n)
  poszero = b1+1
  
  pairs[1:poszero, poszero] .= false
  pairs[1:(b1+2), b1+2] .= false
  pairs[poszero, (poszero+1):n] .= false
  pairs[b1+2, (b1+3):n] .= false
  
  #sieve for squarefree  
  list = trues(b1)
  i = 2
  b = Base.sqrt(b1)
  while i <= b
    if list[i]
      j = i^2
      if !list[j]
        i += 1
        continue
      else 
        list[j] = false
        t = 2*j
        while t <= b1
          list[t] = false
          t +=j
        end
      end
    end
    i+=1
  end
  
  #counting extensions  
  for i = 1:n
    if i == poszero || !list[abs(i-poszero)] || i == b1+2
      continue
    end
    for j = i+1:n
      if j == poszero || !list[abs(j-poszero)] || j == b1+2
        continue
      end
      if pairs[i, j]
        first = i-poszero
        second = j-poszero
        third = divexact(first*second, gcd(first, second)^2)
        if abs(third)>b1
          pairs[i, j] = false
        else
          y=third+poszero
          pairs[y,i] = false
          pairs[y,j] = false
          pairs[i,y] = false
          pairs[j,y] = false
          d1=_discn(first)
          d2=_discn(second)
          g1=d1*d2
          if abs(g1) < b1
            continue
          else 
            d3=_discn(third)
            g2=d1*d3
            if abs(g2)<b1
              continue
            else
              g3=d2*d3
              if abs(g3)<b1
                continue
              else
                g = gcd(g1,g2,g3)
                if abs(g)<b1
                  continue
                elseif check_disc(first, second, third, bound)
                  pairs[i, j] = false
                end
              end
            end
          end
        end
      end
    end
  end
  return pairs, list
  
end

function check_disc(a::Int, b::Int, c::Int, bound::Int)
  
  if mod(a,4)!=2 && mod(b,4)!=2
    return true
  end 
  if mod(a,4)==1 || mod(b,4)==1 || mod(c,4)==1
    return true
  end
  if 64*a*b*c>=bound
    return true
  else
    return false
  end
  
end

#given integers i,j, this function returns the extension Q(sqrt(i))Q(sqrt(j))
function _ext(Ox,x,i,j)
 
  y=mod(i,4)
  pol1 = x^2
  if y != 1
    pol1 = x^2-i
  else
    pol1 = x^2-x+divexact(1-i,4)
  end
  y=mod(j,4)
  pol2=Ox(1)
  if y!=1
    pol2=x^2-j
  else
    pol2=x^2-x+divexact(1-j,4)
  end
  return number_field([pol1,pol2], cached = false)

end

# Given a squarefree integer n, this function computes the absolute value
# of the discriminant of the extension Q(sqrt(n))
function _discn(n::Int)
  
  x = mod(n,4)
  if x != 1
    return 4*n
  else
    return n
  end
  
end

function C22_extensions_tame_real(bound::Int)
  
  
  Qx,x=PolynomialRing(FlintZZ, "x")
  K,_=NumberField(x-1)
  Kx,x=PolynomialRing(K,"x", cached=false)

  b1=floor(Int,Base.sqrt(bound))
  n=b1
  pairs=trues(b1,b1)
  
  #sieve for squarefree number congruent to 1 mod 4
  i=2
  k=4
  while k<=b1
    pairs[1:i,i]=false
    pairs[1:k,k]=false
    pairs[i,i+1:n]=false
    pairs[k,k+1:n]=false
    i+=4
    k+=4
  end
  i=3
  b=Base.sqrt(b1)
  while i<=b
    if pairs[1,i]
      j=i^2
      if !pairs[1,j]
        i+=2
        continue
      else 
        pairs[1:j,j]=false
        pairs[j,1:j]=false
        t=2*j
        while t <= b1
          pairs[t,t:n]=false
          pairs[1:t,t]=false
          t+=j
        end
      end
    end
    i+=2
  end
  k=3
  while k<=b1
    pairs[1:k,k]=false
    pairs[k,k:n]=false
    k+=4
  end
  pairs[1,1:n]=false
  
  #counting extensions  
  for i=5:b1
    for j=i+1:b1
      if pairs[i,j]
        k=divexact(i*j, gcd(i, j)^2)
        if k>b1
          pairs[i,j]=false
        else
          if k>i
            pairs[i,k]=false
          else
            pairs[k,i]=false
          end
          if k>j
            pairs[j,k]=false
          else
            pairs[k,j]=false
          end
          if i*j*k<bound
            continue
          else 
            pairs[i,j]=false
          end
        end
      end
    end
  end
  
  return (_ext(Kx,x,i,j) for i=5:b1 for j=i+1:b1 if pairs[i,j])
  
end



################################################################################
#
#  Valuation bounds for discriminants
#
################################################################################

function valuation_bound_discriminant(n::Int, p::Union{Integer, fmpz})
  # First compute the p-adic expansion of n
  S = Vector{typeof(p)}()
	q = typeof(p)(n)
  q, r = divrem(q, p)
  push!(S, r)
  while q >= p
    q, r = divrem(q, p)
    push!(S, r)
  end

	if !iszero(q)
		push!(S, q)
	end

	@assert sum(S[i + 1] * p^i for i in 0:length(S)-1) == n

	b = zero(typeof(p))

	for i in 0:length(S) - 1
		b = b + S[i + 1] * (i + 1) * p^i
		if !iszero(S[i + 1])
			b = b - 1
		end
	end

  return b
end

###############################################################################
#
#  From relative to absolute
#
###############################################################################

function _from_relative_to_absQQ(L::NfRel_ns{T}, auts::Array{NfRel_nsToNfRel_nsMor{T}, 1}) where T

  @vprint :AbExt 2 "Computing maximal orders of subfields\n"
  Qx, x = PolynomialRing(FlintQQ, "x")
  polys = Vector{fmpq_poly}(undef, length(L.pol))
  for i = 1:length(L.pol)
    fK = isunivariate(L.pol[i])[2]
    f = Qx([coeff(coeff(fK, j), 0) for j = 0:degree(fK)])
    polys[i] = f
  end
  NS, gNS = number_field(polys)
  gpols = gens(parent(gNS[1]))
  B, lp = maximal_order_of_components(NS)
  K, mK = simple_extension(NS, check = false)
  BKK = Array{nf_elem, 1}(undef, degree(K))
  ind = degree(polys[1])
  for i = 1:ind
    BKK[i] = mK\(B[1][i])
  end
  for jj = 2:length(polys)
    new_deg = degree(polys[jj])
    for i = 2:new_deg
      el = mK\(B[jj][i])
      for j = 1:ind
        BKK[(i-1)* ind + j] = BKK[j] * el
      end
    end
    ind *= new_deg
  end
  O1 = NfAbsOrd(BKK)
  for p in lp
    if isprime(p)
      O1 = pmaximal_overorder(O1, p)
    else
      fac = factor(p)
      for (k, v) in fac
        O1 = pmaximal_overorder(O1, k)
      end
    end
  end
  #@vtime :AbExt 2 O1 = pmaximal_overorder_at(O1, lp)
  
  _set_maximal_order(K, O1)
  #Now, we translate the automorphisms.
  imgs = Vector{NfAbsNSElem}(undef, length(auts))
  for i = 1:length(auts)
    fK = isunivariate(auts[i].emb[i].data)[2]
    f = Qx([coeff(coeff(fK, j), 0) for j = 0:degree(fK)])
    imgs[i] = NS(evaluate(f, gpols[i]))
  end
  autsNS = Vector{NfAbsNSToNfAbsNS}(undef, length(auts))
  for t = 1:length(auts)
    imgs = Vector{NfAbsNSElem}(undef, length(polys))
    for s = 1:length(polys)
      fK = isunivariate(auts[t].emb[s].data)[2]
      f = Qx([coeff(coeff(fK, j), 0) for j = 0:degree(fK)])
      imgs[s] = NS(evaluate(f, gpols[s]))
    end
    autsNS[t] = NfAbsNSToNfAbsNS(NS, NS, imgs)
  end
  #Now, to the simple field
  auts_abs = Vector{NfToNfMor}(undef, length(autsNS))
  gK = mK(gen(K))
  for i = 1:length(auts_abs)
    auts_abs[i] = hom(K, K, mK\(autsNS[i](gK)), check = false)
  end
  
  
  @vprint :AbExt 2 "Done. Now simplify and translate information\n"
  @vtime :AbExt 2 Ks, mKs = simplify(K)
  #Now, we have to construct the maximal order of this field.
  #I am computing the preimages of mKs by hand, by inverting the matrix.
  arr_prim_img = Array{nf_elem, 1}(undef, degree(Ks))
  arr_prim_img[1] = K(1)
  for i = 2:degree(Ks)
    arr_prim_img[i] = arr_prim_img[i-1]*mKs.prim_img
  end
  M1 = inv(basis_mat(arr_prim_img))
  
  basisO2 = Array{nf_elem, 1}(undef, degree(Ks))
  M = zero_matrix(FlintZZ, 1, degree(Ks))
  for i=1:length(basisO2)
    elem_to_mat_row!(M, 1, denominator(O1.basis_nf[i]), O1.basis_nf[i])
    mul!(M, M, M1.num)
    basisO2[i] = elem_from_mat_row(Ks, M, 1, M1.den*denominator(O1.basis_nf[i]))
  end
  O2 = NfAbsOrd(Ks, basis_mat(O1, copy = false)*M1)
  O2.ismaximal = 1
  _set_maximal_order_of_nf(Ks, O2)

  #Now, the automorphisms.
  autos = Array{NfToNfMor, 1}(undef, length(auts_abs))
  el = mKs(gen(Ks))
  for i = 1:length(auts)
    x = auts_abs[i](el)
    elem_to_mat_row!(M, 1, denominator(x), x)
    mul!(M, M, M1.num)
    y=Hecke.elem_from_mat_row(Ks, M, 1, M1.den*denominator(x))
    @assert iszero(Ks.pol(y))
    autos[i] = hom(Ks, Ks, y, check = false)
  end
  _set_automorphisms_nf(Ks, closure(autos, degree(Ks)))
  
  @vprint :AbExt 2 "Finished\n"
  return Ks, autos

end 

function _from_relative_to_abs(L::NfRel_ns{T}, auts::Array{NfRel_nsToNfRel_nsMor{T}, 1}) where T

  S, mS = simple_extension(L)
  K, mK, mK2 = absolute_field(S, false)
  #First, we compute the maximal order of the absolute field.
  #Since the computation of the relative maximal order is slow, I bring to the absolute field the elements
  # generating the equation order.
  @vprint :AbExt 2 "Computing the maximal order\n"
  
  
  #First, I construct the product basis of the relative extension
  pols = L.pol
  gL = gens(L)
  B = Array{nf_elem, 1}(undef, degree(K))
  B[1] = K(1)
  ind = total_degree(pols[1])
  genjj = mK(mS\gL[1])
  for i = 2:ind
    B[i] = genjj*B[i-1]
  end
  for jj = 2:length(pols)
    genjj = mK(mS\gL[jj])
    el = genjj
    new_deg = total_degree(pols[jj])
    for i = 2:new_deg
      for j = 1:ind
        B[(i-1)* ind + j] = B[j]* el 
      end
      mul!(el, el, genjj)
    end
    ind *= new_deg
  end

  #Now, I add the elements of the maximal order
  if degree(base_ring(L)) > 1
    O = maximal_order(S.base_ring)
    for i = 1:degree(O)
      el = mK(S(O.basis_nf[i]))
      for j = 1:ind
        B[(i-1)* ind + j] = B[j] * el 
      end
    end
  end
  #Now, we compute the maximal order. Then we simplify.
  PO = Order(K, B, check = false, cached = false, isbasis = true)
  @vtime :AbExt 2 O1 = MaximalOrder(PO)
  O1.ismaximal = 1
  _set_maximal_order_of_nf(K, O1)
  @vprint :AbExt 2 "Done. Now simplify and translate information\n"
  @vtime :AbExt 2 Ks, mKs = simplify(K)
  #Now, we have to construct the maximal order of this field.
  #I am computing the preimages of mKs by hand, by inverting the matrix.
  arr_prim_img = Array{nf_elem, 1}(undef, degree(Ks))
  arr_prim_img[1] = K(1)
  for i = 2:degree(Ks)
    arr_prim_img[i] = arr_prim_img[i-1]*mKs.prim_img
  end
  M1 = inv(basis_mat(arr_prim_img))
  basisO2 = Array{nf_elem, 1}(undef, degree(Ks))
  M = zero_matrix(FlintZZ, 1, degree(Ks))
  for i=1:length(basisO2)
    elem_to_mat_row!(M, 1, denominator(O1.basis_nf[i]), O1.basis_nf[i])
    mul!(M, M, M1.num)
    basisO2[i] = elem_from_mat_row(Ks, M, 1, M1.den*denominator(O1.basis_nf[i]))
  end
  O2 = Order(Ks, basisO2, check = false, cached = false)
  O2.ismaximal = 1
  _set_maximal_order_of_nf(Ks, O2)

  #Now, the automorphisms.
  autos=Array{NfToNfMor, 1}(undef, length(auts))
  el=mS(mK\(mKs(gen(Ks))))
  for i=1:length(auts)
    x = mK(mS\(auts[i](el)))
    elem_to_mat_row!(M, 1, denominator(x), x)
    mul!(M, M, M1.num)
    y=Hecke.elem_from_mat_row(Ks, M, 1, M1.den*denominator(x))
    autos[i] = hom(Ks, Ks, y, check = false)
  end
  _set_automorphisms_nf(Ks, closure(autos, degree(Ks)))
  
  @vprint :AbExt 2 "Finished\n"
  return Ks, autos

end 

