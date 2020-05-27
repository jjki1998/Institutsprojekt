mutable struct ecefcoordinates

    x::Float64
    y::Float64
    z::Float64
end

mutable struct geocoordinates

    h::Float64
    lon::Float64
    lat::Float64

end

mutable struct enucoordinates

    e::Float64
    n::Float64
    u::Float64
    posofself::ecefcoordinates
    
end

mutable struct aercoordinates

    azimuth::Float64
    elevation::Float64
    distance::Float64
    posofself::geocoordinates

end

function Base.:-(ecef1::ecefcoordinates,ecef2::ecefcoordinates)

    return ecefcoordinates(ecef1.x-ecef2.x, ecef1.y-ecef2.y, ecef1.z-ecef2.z)

end

function eceftogeo(ecef::ecefcoordinates)

    temph = distance3d(ecef.x,ecef.y,ecef.z) - 6371e3
    templon = 0.
    templat = 0.

    if ecef.y > 0
        if ecef.x > 0
            templon = atan(ecef.y / ecef.x) / pi * 180
        end
        if ecef.x < 0
            templon = 180 - atan(ecef.y /-ecef.x) / pi * 180
        end
        if ecef.x == 0
            templon == 90
        end
    end

    if ecef.y < 0
        if ecef.x > 0
            templon = atan(ecef.y / ecef.x) / pi * 180
        end
        if ecef.x < 0
            templon = -180 - atan(ecef.y /-ecef.x) / pi * 180
        end
        if ecef.x == 0
            templon == -90
        end

    end

    if ecef.y == 0

        if ecef.x >= 0
            templon = 0
        else
            templon = 180
        end

    end

    if ecef.z == 0
        templat = 0
    else
        templat = atan(ecef.z / distance2d(ecef.x,ecef.y)) / pi * 180
    end


    return geocoordinates(temph,templon,templat)

end

function geotoecef(geo::geocoordinates)

    tempx = 0.
    tempy = 0.
    tempz = 0.

    realh = geo.h + 6371e3

    tempz = sin(geo.lat / 180 * pi) * realh


    tempxy = cos(geo.lat / 180 * pi) * realh

    tempx = cos(geo.lon / 180 * pi) * tempxy
    tempy = sin(geo.lon / 180 * pi) * tempxy

    return ecefcoordinates(tempx,tempy,tempz)

end

function enu(geoself::geocoordinates,geoother::geocoordinates)
    ecefself = geotoecef(geoself)
    ecefother = geotoecef(geoother)

    ecefotherinpersofself = ecefother - ecefself
    lambda = geoself.lon / 180 * pi
    phi = geoself.lat / 180 * pi

    x = ecefotherinpersofself.x
    y = ecefotherinpersofself.y
    z = ecefotherinpersofself.z

    enux = -sin(lambda)            * x + cos(lambda)            * y + 0        * z
    enuy = -cos(lambda) * sin(phi) * x - sin(lambda) * sin(phi) * y + cos(phi) * z
    enuz =  cos(lambda) * cos(phi) * x + sin(lambda) * cos(phi) * y + sin(phi) * z

    return enucoordinates(enux,enuy,enuz,ecefself)

end

function aer(geoself::geocoordinates,geoother::geocoordinates)

    tempenu = enu(geoself,geoother)

    aerdistance = distance3d(tempenu.e,tempenu.n,tempenu.u)
    aerazimuth = 0
    aerelevation = asin(tempenu.u / aerdistance) / pi * 180

    if tempenu.e >= 0
        aerazimuth = acos(tempenu.n / distance2d(tempenu.e,tempenu.n)) / pi * 180
    else
        aerazimuth = acos(-tempenu.n / distance2d(tempenu.e,tempenu.n)) / pi * 180 + 180
    end

    return aercoordinates(aerazimuth,aerelevation,aerdistance,geoself)

end

function distance3d(x,y,z)

    return sqrt(x*x+y*y+z*z)

end

function distance2d(x,y)

    return sqrt(x*x+y*y)

end

println("hallo")

foo = eceftogeo(ecefcoordinates(7.638932573319407e6,-1.266435036859557e7,1.986926779806476e7))
println(foo)

foo = geotoecef(foo)
println(foo)

foo = eceftogeo(ecefcoordinates(1.46716489217378e7,1.2244176580209156e7,1.7363367502810095e7))
println(foo)

foo = geotoecef(foo)
println(foo)

foo = eceftogeo(ecefcoordinates(1.7991359447382748e7,1.493100940250698e7,3.3452592907386366e6))
println(foo)

foo = geotoecef(foo)
println(foo)

foo = geotoecef(geocoordinates(0.0, 6.066027, 50.778747))
println(foo)

aachen1 = geocoordinates(0, 6.066458, 50.779816)
aachen2 = geocoordinates(0, 6.068015, 50.780647)

aachen2toaachen1 = enu(aachen2,aachen1)

println(aachen2toaachen1)

aachen2toaachen1 = aer(aachen2,aachen1)

println(aachen2toaachen1)

println("hey, I got here")
