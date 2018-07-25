module Util
export julienne, fcat, @try_defconst, @λ, @reshape, batch, includeall

julienne(args...; view=true) = view ? _julienne_view(args...) : _julienne_copy(args...)

_julienne_view(A, dims) = _julienne_view(identity, A, dims)
function _julienne_view(f, A, dims)
    nd = ndims(A)
    other_dims = [n for n = 1:nd if !(n in dims)]
    ret = similar(A, other_dims...)
    for ixs in CartesianRange(size(A, other_dims...))
        jxs = (d in dims ? (:) : ixs[i] #=
            =# for (i, d) in enumerate(ixs))
        v = view(A, jxs...)
        ret[ixs] = f(v)
    end

    ret
end

_julienne_copy(A, dims) = mapslices(x -> [x], A, dims)
_julienne_copy(f, A, dims) = mapslices(x -> [f(x)], A, dims)

macro try_defconst(expr)
    isdefined(expr.args[1]) ? nothing : Expr(:const, esc(expr))
end

_λ!(expr, splat_sym::Symbol) = ([], false)
function _λ!(expr::Expr, splat_sym::Symbol)
    syms = []
    splat = false

    map!(expr.args, expr.args) do x
        if x == :_ 
            _sym = gensym()
            push!(syms, _sym)
            _sym
        elseif x == :___
            splat = true
            Expr(:..., splat_sym)
        else
            expr.head == :call ? :($(current_module() |> module_name).@λ $x) : x
        end
    end
    
    if expr.head != :call for x in expr.args
        sym_vec, s = _λ!(x, splat_sym)
        splat |= s
        append!(syms, sym_vec)
    end end

    (syms, splat)
end
macro λ(expr)
    splat_sym = gensym()
    syms, splat = _λ!(expr, splat_sym)

    isempty(syms) && !splat ? esc(expr) : #=
                   =# splat ? esc(:(($(syms...), $(splat_sym)...) -> $expr)) #=
                         =# : esc(:(($(syms...),) -> $expr))
end

fcat(f1, fs...) = (xs...) -> map(f -> f(xs...), (f1, fs...))
fcat(itr) = (xs...) -> map(f -> f(xs...), collect(itr))

countcolons(x::Symbol) = x == :(:) ? 1 : x == :(::) ? 2 : 0
countcolons(x::Expr) = countcolons(x.head) + sum(countcolons, x.args)
countcolons(x) = sum(countcolons, x)

iscolons(x::Symbol) = x == :(:) || x == :(::)
iscolons(x::Expr) = iscolons(x.head) && all(iscolons, x.args)

macro reshape(expr::Expr)
    @assert expr.head == :ref
    arr = expr.args[1]
    arr_sym = gensym()
    tot_colons = countcolons(expr.args[2:end])
    colonnum = 0
    args = map(expr.args[2:end]) do ix
        @assert ix == :_ || iscolons(ix)
        if ix == :_
            1
        elseif tot_colons != 1
            colons = countcolons(ix)
            cs = colonnum+1:colonnum+colons
            colonnum += colons
            :(prod(size($arr_sym,  $(cs...))))
        else
            :(length($arr_sym))
        end
    end

    quote
        $arr_sym = $(esc(arr))
        reshape($arr_sym, $(args...))
    end
end

includeall(dir) = for f in readdir(dir) if isfile(dir*"/"*f) && f[end-2:end] == ".jl"
    include(dir*"/"*f)
end end

function batch(xs, sz; dim=-1) where N
    dim = ndims(xs) + dim + 1

    s = size(xs, dim)
    ret = []
    for i in 1:div(s, sz)
        push!(ret, slicedim(xs, dim, 1+(i-1)*sz:min(s, i*sz)))
    end

    ret
end

end # module Util
