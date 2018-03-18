#=
Hashing functions for Str types (to make compatible with String hashes)

Copyright 2018 Gandalf Software, Inc., Scott P. Jones
Licensed under MIT License, see LICENSE.md
=#

V6_COMPAT || import Base: _crc32c

# Support for higher performance hashing, while still compatible with hashed UTF8 String

_memhash(siz, ptr, seed) =
    ccall(Base.memhash, UInt, (Ptr{UInt8}, Csize_t, UInt32), ptr, siz, seed % UInt32)

_hash(siz, ptr, seed) = _memhash(siz, ptr, seed) + seed

# Optimize conversion to ASCII or UTF8 to calculate compatible hash value
                          
function hash(str::Union{S,SubString{S}}, seed::UInt) where {S<:Str}
    @preserve str begin
        len, pnt = _lenpnt(str)
        len == 0 && return _hash(len, pnt, seed + Base.memhash_seed)
        len, flags, num4byte, num3byte, num2byte, latin1 = count_chars(S, pnt, len)
        # could be UCS2, _UCS2, UTF32, _UTF32, Text2, Text4
        buf = (flags == 0
               ? _cvtsize(UInt8, pnt, len)
               : _encode_utf8(pnt, len += latin1 + num2byte + num3byte*2 + num4byte*3))
        _hash(len, buf, seed + Base.memhash_seed)
    end
end

function hash(str::Union{S,SubString{S}}, seed::UInt) where {S<:Str{<:Union{Text1CSE,Latin_CSEs}}}
    @preserve str begin
        len, pnt = _lenpnt(str)
        len != 0 && (cnt = count_latin(len, pnt)) != 0 &&
            (str = _latin_to_utf8(pnt, len += cnt) ; pnt = _pnt(str))
        _hash(len, pnt, seed + Base.memhash_seed)
    end
end

function hash(str::Union{S,SubString{S}}, seed::UInt) where {S<:Str{UTF16CSE}}
    @preserve str begin
        len, pnt = _lenpnt(str)
        len == 0 && return _hash(len, pnt, seed + Base.memhash_seed)
        len, flags, num4byte, num3byte, num2byte, latin1 = count_chars(S, pnt, len)
        buf = (flags == 0
               ? _cvtsize(UInt8, pnt, len)
               : _cvt_16_to_utf8(S, pnt, len += latin1 + num2byte + num3byte*2 + num4byte*3))
        _hash(len, buf, seed + Base.memhash_seed)
    end
end

# Directly calculate hash for "compatible" types

hash(str::Union{S,SubString{S}}, seed::UInt) where {S<:Str{<:Union{ASCIICSE,UTF8CSE,BinaryCSE}}} =
    @preserve str _hash(sizeof(str), pointer(str), seed + Base.memhash_seed)

