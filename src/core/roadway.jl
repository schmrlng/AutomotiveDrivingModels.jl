#######################################

immutable LaneTag
    segment :: Int # segment id
    lane    :: Int # index in segment.lanes of this lane
end
const NULL_LANETAG = LaneTag(0,0)

#######################################

immutable LaneBoundary
    style::Symbol # ∈ :solid, :broken, :double
    color::Symbol # ∈ :yellow, white
end
const NULL_BOUNDARY = LaneBoundary(:unknown, :unknown)

#######################################

const DEFAULT_LANE_WIDTH = 3.0 # [m]

type Lane
    tag            :: LaneTag
    curve          :: Curve
    width          :: Float64 # [m]
    boundary_left  :: LaneBoundary
    boundary_right :: LaneBoundary
    prev           :: LaneTag
    next           :: LaneTag

    function Lane(
        tag::LaneTag,
        curve::Curve;
        width::Float64 = DEFAULT_LANE_WIDTH,
        boundary_left::LaneBoundary = NULL_BOUNDARY,
        boundary_right::LaneBoundary = NULL_BOUNDARY,
        prev::LaneTag = NULL_LANETAG,
        next::LaneTag = NULL_LANETAG,
        )

        retval = new()
        retval.tag = tag
        retval.curve = curve
        retval.width = width
        retval.boundary_left = boundary_left
        retval.boundary_right = boundary_right
        retval.prev = prev
        retval.next = next
        retval
    end
end

has_next(lane::Lane) = lane.next != NULL_LANETAG
has_prev(lane::Lane) = lane.prev != NULL_LANETAG

function connect!(prev::Lane, next::Lane)
    prev.next = next.tag
    next.prev = prev.tag
    (prev, next)
end

#######################################

type RoadSegment
    # a list of lanes forming a single road with a common direction
    id::Int
    lanes::Vector{Lane} # lanes are stored right to left
    RoadSegment(id::Int, lanes::Vector{Lane}=Lane[]) = new(id, lanes)
end

#######################################

type Roadway
    segments::Vector{RoadSegment}

    Roadway(segments::Vector{RoadSegment}=RoadSegment[]) = new(segments)
end

function Base.getindex(lane::Lane, ind::CurveIndex, roadway::Roadway)
    if ind.i != 0
        lane.curve[ind]
    else
        lane_prev = roadway[lane.prev]
        pt_hi = lane.curve[1]
        pt_lo = lane_prev.curve[end]
        s_gap = abs(pt_hi.pos - pt_lo.pos)
        pt_lo = CurvePt(pt_lo.pos, -s_gap, pt_lo.k, pt_lo.kd)
        lerp( pt_lo, pt_hi, ind.t)
    end
end
function Base.getindex(roadway::Roadway, segid::Int)
    for seg in roadway.segments
        if seg.id == segid
            return seg
        end
    end
    error("Could not find segid $segid in roadway")
end
function Base.getindex(roadway::Roadway, tag::LaneTag)
    seg = roadway[tag.segment]
    seg.lanes[tag.lane]
end

Base.next(roadway::Roadway, lane::Lane) = roadway[lane.next]
     prev(roadway::Roadway, lane::Lane) = roadway[lane.prev]

immutable RoadProjection
    curveproj::CurveProjection
    tag::LaneTag
end

"""
    proj(posG::VecSE2, lane::Lane, roadway::Roadway)
Return the RoadProjection for projecting posG onto the lane.
This will automatically project to the next or prev curve as appropriate.
If the pt is between curves the CurveIndex will have i = 0, and it will be on the
curve downstream of that point.
"""
function Vec.proj(posG::VecSE2, lane::Lane, roadway::Roadway)
    curveproj = proj(posG, lane.curve)
    if curveproj.ind == CurveIndex(1,0.0) && has_prev(lane)
        lane_prev = roadway[lane.prev]
        pt_lo = lane_prev.curve[end]
        pt_hi = lane.curve[1]

        t = get_lerp_time_unclamped(pt_lo, pt_hi, posG)
        if t < 0.0
            return proj(posG, lane_prev, roadway)
        end

        @assert(0.0 ≤ t ≤ 1.0)

        if t < 1.0
            footpoint = lerp( pt_lo.pos, pt_hi.pos, t)
            ind = CurveIndex(0.0, t)
        else
            footpoint = pt_hi.pos
            ind = CurveIndex(1.0,0.0)
        end

        curveproj = get_curve_projection(posG, footpoint, ind)

    elseif curveproj.ind == CurveIndex(length(lane.curve)-1,1.0) && has_next(lane)
        lane_next = roadway[lane.next]
        pt_lo = lane.curve[end]
        pt_hi = lane_next.curve[1]

        t = get_lerp_time_unclamped(pt_lo, pt_hi, posG)
        if t ≥ 1.0
            return proj(posG, lane_next, roadway)
        end

        @assert(0.0 ≤ t ≤ 1.0)

        footpoint = lerp( pt_lo.pos, pt_hi.pos, t)
        ind = CurveIndex(0.0, t)
        lane = lane_next
        curveproj = get_curve_projection(posG, footpoint, ind)
    end

    RoadProjection(curveproj, lane.tag)
end

"""
    proj(posG::VecSE2, seg::RoadSegment, roadway::Roadway)
Return the RoadProjection for projecting posG onto the segment.
Tries all of the lanes and gets the closest one
"""
function Vec.proj(posG::VecSE2, seg::RoadSegment, roadway::Roadway)

    best_dist2 = Inf
    best_proj = RoadProjection(CurveProjection(CurveIndex(-1,-1), NaN, NaN), NULL_LANETAG)

    for lane in seg.lanes
        roadproj = proj(posG, lane, roadway)
        footpoint = roadway[roadproj.tag][roadproj.curveproj.ind, roadway]
        dist2 = abs2(posG - footpoint.pos)
        if dist2 < best_dist2
            best_dist2 = dist2
            best_proj = roadproj
        end
    end

    best_proj
end

"""
    proj(posG::VecSE2, seg::RoadSegment, roadway::Roadway)
Return the RoadProjection for projecting posG onto the roadway.
Tries all of the lanes and gets the closest one
"""
function Vec.proj(posG::VecSE2, roadway::Roadway)

    best_dist2 = Inf
    best_proj = RoadProjection(CurveProjection(CurveIndex(-1,-1), NaN, NaN), NULL_LANETAG)

    for seg in roadway.segments
        for lane in seg.lanes
            roadproj = proj(posG, lane, roadway)
            footpoint = roadway[roadproj.tag][roadproj.curveproj.ind, roadway]
            dist2 = abs2(posG - footpoint.pos)
            if dist2 < best_dist2
                best_dist2 = dist2
                best_proj = roadproj
            end
        end
    end

    best_proj
end

############################################

immutable RoadIndex
    ind::CurveIndex
    tag::LaneTag
end
function Base.getindex(roadway::Roadway, roadind::RoadIndex)
    lane = roadway[roadind.tag]
    lane[roadind.ind]
end

"""
    move_along(roadind::RoadIndex, road::Roadway, Δs::Float64)
Return the RoadIndex at ind's s position + Δs
"""
function move_along(roadind::RoadIndex, roadway::Roadway, Δs::Float64)

    lane = roadway[roadind.tag]
    curvept = lane[roadind.ind, roadway]

    if curvept.s + Δs < 0.0
        if has_prev(lane)
            lane_prev = roadway[lane.prev]
            pt_lo = lane_prev.curve[end]
            pt_hi = lane.curve[1]
            s_gap = abs(pt_hi.pos - pt_lo.pos)

            if curvept.s + Δs < -s_gap
                curveind = CurveIndex(length(lane_prev.curve)-1,1.0)
                roadind = RoadIndex(curveind, lane_prev.tag)
                return move_along(roadind, roadway, Δs + curvept.s + s_gap)
            else # in the gap between lanes
                t = (s_gap + curvept.s + Δs) / s_gap
                curveind = CurveIndex(0, t)
                RoadIndex(curveind, lane.tag)
            end

        else # no prev lane, return the beginning of this one
            curveind = CurveIndex(1, 0.0)
            return RoadIndex(curveind, roadind.tag)
        end
    elseif curvept.s + Δs > lane.curve[end].s
        if has_next(lane)
            lane_next = roadway[lane.next]
            pt_lo = lane.curve[end]
            pt_hi = lane_next.curve[1]
            s_gap = abs(pt_hi.pos - pt_lo.pos)

            if curvept.s + Δs ≥ pt_lo.s + s_gap
                curveind = CurveIndex(1,0.0)
                roadind = RoadIndex(curveind, lane_next.tag)
                return move_along(roadind, roadway, Δs - (lane.curve[end].s + s_gap - curvept.s))
            else # in the gap between lanes
                t = (Δs - (lane.curve[end].s - curvept.s)) / s_gap
                curveind = CurveIndex(0, t)
                RoadIndex(curveind, lane_next.tag)
            end
        else # no next lane, return the end of this lane
            curveind = CurveIndex(length(lane.curve)-1, 1.0)
            return RoadIndex(curveind, roadind.tag)
        end
    else
        ind = get_curve_index(roadind.ind, lane.curve, Δs)
        RoadIndex(ind, roadind.tag)
    end

end