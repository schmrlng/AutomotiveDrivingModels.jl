export
    ActionContext,
    ContextFree,
    IntegratedContinuous,

    DriveAction,
    NextState,
    AccelTurnrate,
    AccelDesang,
    LatLonAccel,
    LaneFollowingAccel,

    propagate


abstract ActionContext

type ContextFree <: ActionContext end
type IntegratedContinuous <: ActionContext
    Δt::Float64 # timestep
    n_integration_steps::Int # number of substeps taken during integration
end

###############

abstract DriveAction
Base.length{A<:DriveAction}(a::Type{A}) = error("length not defined for DriveAction $a")
Base.convert{A<:DriveAction}(a::Type{A}, v::Vector{Float64}) = error("convert v → a not implemented for DriveAction $a")
Base.copy!(v::Vector{Float64}, a::DriveAction) = error("copy! not implemented for DriveAction $a")
Base.convert{A<:DriveAction}(::Type{Vector{Float64}}, a::A) = copy!(Array(Float64, length(A)), a)
propagate(veh::Vehicle, action::DriveAction, context::ActionContext, roadway::Roadway) = error("propagate not implemented for DriveAction $action and context $context")

immutable AccelTurnrate <: DriveAction
    a::Float64
    ω::Float64
end
Base.show(io::IO, a::AccelTurnrate) = @printf(io, "AccelTurnrate(%6.3f,%6.3f)", a.a, a.ω)
Base.length(::Type{AccelTurnrate}) = 2
Base.convert(::Type{AccelTurnrate}, v::Vector{Float64}) = AccelTurnrate(v[1], v[2])
function Base.copy!(v::Vector{Float64}, a::AccelTurnrate)
    v[1] = a.a
    v[2] = a.ω
    v
end
function propagate(veh::Vehicle, action::AccelTurnrate, context::IntegratedContinuous, roadway::Roadway)

    a = action.a # accel
    ω = action.ω # turnrate

    x = veh.state.posG.x
    y = veh.state.posG.y
    θ = veh.state.posG.θ
    v = veh.state.v

    δt = context.Δt / context.n_integration_steps

    for i in 1 : context.n_integration_steps
        x += v*cos(θ)*δt
        y += v*sin(θ)*δt
        θ += ω*δt
        v += a*δt
    end

    posG = VecSE2(x, y, θ)
    VehicleState(posG, roadway, v)
end

immutable AccelDesang <: DriveAction
    a::Float64
    ϕdes::Float64
end
Base.show(io::IO, a::AccelDesang) = @printf(io, "AccelDesang(%6.3f,%6.3f)", a.a, a.ϕdes)
Base.length(::Type{AccelDesang}) = 2
Base.convert(::Type{AccelDesang}, v::Vector{Float64}) = AccelDesang(v[1], v[2])
function Base.copy!(v::Vector{Float64}, a::AccelDesang)
    v[1] = a.a
    v[2] = a.ϕdes
    v
end
function propagate(veh::Vehicle, action::AccelDesang, context::IntegratedContinuous, roadway::Roadway)

    a = action.a # accel
    ϕdes = action.ϕdes # desired heading angle

    x = veh.state.posG.x
    y = veh.state.posG.y
    θ = veh.state.posG.θ
    v = veh.state.v

    δt = context.Δt/context.n_integration_steps

    for i in 1 : context.n_integration_steps

        posF = Frenet(VecSE2(x, y, θ), roadway)
        ω = ϕdes - posF.ϕ

        x += v*cos(θ)*δt
        y += v*sin(θ)*δt
        θ += ω*δt
        v += a*δt
    end

    posG = VecSE2(x, y, θ)
    VehicleState(posG, roadway, v)
end

###############

"""
    LatLonAccel
Acceleration in the frenet frame
"""
immutable LatLonAccel <: DriveAction
    a_lat::Float64
    a_lon::Float64
end
Base.show(io::IO, a::LatLonAccel) = @printf(io, "LatLonAccel(%6.3f, %6.3f)", a.a_lat, a.a_lon)
Base.length(::Type{LatLonAccel}) = 2
Base.convert(::Type{LatLonAccel}, v::Vector{Float64}) = LatLonAccel(v[1], v[2])
function Base.copy!(v::Vector{Float64}, a::LatLonAccel)
    v[1] = a.a_lat
    v[2] = a.a_lon
    v
end
function propagate(veh::Vehicle, action::LatLonAccel, context::IntegratedContinuous, roadway::Roadway)

    a_lat = action.a_lat
    a_lon = action.a_lon

     v = veh.state.v
     ϕ = veh.state.posF.ϕ
    ds = v*cos(ϕ)
     t = veh.state.posF.t
    dt = v*sin(ϕ)

    ΔT = context.Δt
    ΔT² = ΔT*ΔT
    Δs = ds*ΔT + 0.5*a_lon*ΔT²
    Δt = dt*ΔT + 0.5*a_lat*ΔT²

    ds₂ = ds + a_lon*ΔT
    dt₂ = dt + a_lat*ΔT
    speed₂ = sqrt(dt₂*dt₂ + ds₂*ds₂)
    v₂ = sign(ds₂)*speed₂
    ϕ₂ = atan2(dt₂, ds₂) + (v₂ < 0.0)*π # handle negative speeds

    roadind = move_along(veh.state.posF.roadind, roadway, Δs)
    footpoint = roadway[roadind]
    posG = convert(VecE2, footpoint.pos) + polar(t + Δt, footpoint.pos.θ + π/2)
    posG = VecSE2(posG.x, posG.y, footpoint.pos.θ + ϕ₂)
    VehicleState(posG, roadway, v₂)

    # posF = Frenet(roadind, footpoint.s, t + Δt, ϕ₂)
    # VehicleState(posG, posF, v₂)
end

###############

"""
    LaneFollowingAccel
Longitudinal acceleration
"""
immutable LaneFollowingAccel <: DriveAction
    a::Float64
end
Base.show(io::IO, a::LaneFollowingAccel) = @printf(io, "LaneFollowingAccel(%6.3f)", a.a)
Base.length(::Type{LaneFollowingAccel}) = 1
Base.convert(::Type{LaneFollowingAccel}, v::Vector{Float64}) = LaneFollowingAccel(v[1])
function Base.copy!(v::Vector{Float64}, a::LaneFollowingAccel)
    v[1] = a.a
    v
end
function propagate(veh::Vehicle, action::LaneFollowingAccel, context::IntegratedContinuous, roadway::Roadway)

    a_lon = action.a

    ds = veh.state.v

    ΔT = context.Δt
    ΔT² = ΔT*ΔT
    Δs = ds*ΔT + 0.5*a_lon*ΔT²

    v₂ = ds + a_lon*ΔT

    roadind = move_along(veh.state.posF.roadind, roadway, Δs)
    posG = roadway[roadind].pos
    VehicleState(posG, roadway, v₂)
end
###############

immutable NextState <: DriveAction
    s::VehicleState
end
Base.show(io::IO, a::NextState) = print(io, "NextState(", a.s, ")")
Base.length(::Type{NextState}) = 11
function Base.convert(::Type{NextState}, v::Vector{Float64})
    VehicleState(VecSE2(v[1],v[2],v[3]), # x, y, θ
                 Frenet(
                    RoadIndex(
                        CurveIndex(round(Int, v[4]), v[5]),
                        LaneTag(round(Int, v[6]), round(Int, v[7])),
                    ),
                    v[8], v[9], v[10] # s, t, ϕ
                 ),
                 v[11] # speed
    )
end
function Base.copy!(v::Vector{Float64}, a::NextState)
    v[1] = a.s.posG.x
    v[2] = a.s.posG.y
    v[2] = a.s.posG.θ
    v[2] = a.s.posF.roadind.ind.i
    v[2] = a.s.posG.roadind.ind.t
    v[2] = a.s.posG.roadind.tag.segment
    v[2] = a.s.posG.roadind.tag.lane
    v[2] = a.s.posG.s
    v[2] = a.s.posG.t
    v[2] = a.s.posG.ϕ
    v
end
propagate{C<:ActionContext}(veh::Vehicle, action::NextState, context::C, roadway::Roadway) = action.s