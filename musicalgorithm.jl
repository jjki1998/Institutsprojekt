function abssquare(vector)

    result = 0

    map(vector) do vectorelement
    result = result + abs(vectorelement) * abs(vectorelement)
    end

    return result

end

function evaluationp(eignoisevech,steeringvec)

    p = abssquare(steeringvec) / abssquare(eignoisevech * steeringvec)
    return p

end

function musicalgorithm(noiseeigenh,aziele)

    maxazimuth = 0
    maxelevation = 0
    maxp = 0

    for row in CSV.File("antenna.csv")

        azimuth = row.azi
        elevation = row.ele
        steerA = row.rA + row.iA * 1im
        steerB = row.rB + row.iB * 1im
        steerC = row.rC + row.iC * 1im
        steerD = row.rD + row.iD * 1im

        p = evaluationp(noiseeigenh,[steerA,steerB,steerC,steerD])

        if p > maxp
            maxp = p
            maxazimuth = azimuth
            maxelevation = elevation
        end

    end

    aziele[1] = maxazimuth
    aziele[2] = maxelevation

end
