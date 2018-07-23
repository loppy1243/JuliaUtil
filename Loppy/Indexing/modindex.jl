export modindex
modindex(dims::NTuple{N, Int}, ixs::NTuple{N, Int}) where N = modindex(dims, ixs...)
modindex(a::AbstractArray{T, N}, ixs::Vararg{Int, N}) where {T, N} = modindex(size(a), ixs...)
modindex(a::AbstractArray{T, N}, ixs::NTuple{N, Int}) where {T, N} = modindex(size(a), ixs...)
@generated function modindex(dims::NTuple{N, Int}, ixs::Vararg{Int, N}) where N
    js(i) = :(mod(ixs[$i], dims[$i]))

    quote
        tuple($((:($(js(i)) == 0 ? dims[$i] : $(js(i))) for i = 1:N)...))
    end
end

export modgetindex
modgetindex(a::AbstractArray{T, N}, ixs::NTuple{N, Int}) where {T, N} = modgetindex(a, ixs...)
@generated function modgetindex(a::AbstractArray{T, N}, ixs::Vararg{Int, N}) where {T, N}
    js(i) = :(mod(ixs[$i], size(a, $i)))

    quote
        a[$((:($(js(i)) == 0 ? size(a, $i) : $(js(i))) for i = 1:N)...)]
    end
end
