using RecipesBase
using AstroAngles
using Printf
using PlotUtils: optimize_ticks


@userplot ImPlot
@recipe function f(h::ImPlot)
    if length(h.args) != 1 || !(typeof(h.args[1]) <: AbstractArray)
        error("Image plots require an arugment that is a subtype of AbstractArray.  Got: $(typeof(h.args))")
    end
    img = only(h.args)
    if !(typeof(img) <: AstroImage)
        img = AstroImage(only(h.args))
    end
    T = eltype(img)
    if ndims(img) != 2
        error("Image passed to `implot` must be two-dimensional.  Got ndims(img)=$(ndims(img))")
    end


    # We often plot an AstroImageMat{<:Number} which hasn't yet had
    # its wcs cached (wcs_stale=true) and we make an image view here.
    # That means we may have to keep recomputing the WCS on each plot call
    # since the result is stored in the imview instead of original image.
    # Call wcs(img) here if we are later  going to plot with wcs coordinates
    # to ensure this gets cached beween calls.
    if !haskey(plotattributes, :wcs) || plotattributes[:wcs]
        wcs(img)
    end

    # Use package defaults if not user provided.
    clims   --> _default_clims[]
    stretch --> _default_stretch[]
    cmap    --> _default_cmap[]

    # We currently use the AstroImages defaults. If unset, we could
    # instead follow the plot theme.
    if T <: Colorant
        imgv = img
    else
        clims   = plotattributes[:clims]
        stretch = plotattributes[:stretch]
        cmap    = plotattributes[:cmap]
        imgv = imview(img; clims, stretch, cmap)
    end

    xgrid --> true
    ygrid --> true

    # By default, disable the colorbar.
    # Plots.jl does no give us sufficient control to make sure the range and ticks
    # are correct after applying a non-linear stretch.
    colorbar := false
    # We may be able to make our own colorbar in future using a second image plot
    # off to the side using something like:
        # if typeof(clims) <: AbstractArray || typeof(clims) <: Tuple
        #     if length(clims) != 2
        #         error("clims must have exactly two values if provided.")
        #     end
        #     imgmin = first(clims)
        #     imgmax = last(clims)
        # # Or as a callable that computes them given an iterator
        # else
        #     imgmin, imgmax = clims(skipmissingnan(img))
        # end
        # imview(repeat(range(imgmin, imgmax,length=100), 1,10)'; clims=(imgmin,imgmax), stretch, cmap)

    # we have a wcs flag (from the image by default) so that users can skip over 
    # plotting in physical coordinates. This is especially important
    # if the WCS headers are mallformed in some way.
    if !haskey(plotattributes, :wcs) || plotattributes[:wcs]

        # Note: if the axes are on unusual sides (e.g. y-axis at right, x-axis at top)
        # then these coordinates are not correct. They are only correct exactly
        # along the axis.
        # In astropy, the ticks are actually tilted to reflect this, though in general
        # the transformation from pixel to coordinates can be non-linear and curved.

        ax = [1,1]
        minx = first(dims(imgv,2))
        maxx = last(dims(imgv,2))
        miny = first(dims(imgv,1))
        maxy = last(dims(imgv,1))
        extent = (minx, maxx, miny, maxy)

        @show extent

        # wcsg = WCSGrid(wcs(imgv), extent, ax, coords)
        # gridspec = wcsgridspec(wcsg)
        
        # xticks --> (gridspec.tickpos1x, wcslabels(wcs(imgv), ax[1], gridspec.tickpos1w))
        # xguide --> ctype_label(wcs(imgv).ctype[ax[1]], wcs(imgv).radesys)

        # yticks --> (gridspec.tickpos2x, wcslabels(wcs(imgv), ax[2], gridspec.tickpos2w))
        # yguide --> ctype_label(wcs(imgv).ctype[ax[2]], wcs(imgv).radesys)

        # To ensure the physical axis tick labels are correct the axes must be
        # tight to the image
        xl = first(axes(imgv,2)), last(axes(imgv,2))
        yl = first(axes(imgv,1)), last(axes(imgv,1))
        ylims --> yl
        xlims --> xl
    end

    # Disable equal aspect ratios if the scales are totally different
    if max(size(imgv)...)/min(size(imgv)...) >= 7
        aspect_ratio --> :none
    end

    # We have to do a lot of flipping to keep the orientation corect 
    yflip := false
    xflip := false

    @series begin
        # axes(imgv,2), axes(imgv,1), view(arraydata(imgv), reverse(axes(imgv,1)),:)
        # axes(imgv,2) .- 0.5, axes(imgv,1) .- 0.5, 
        # @show size(view(arraydata(imgv), reverse(axes(imgv,1)),:))
        view(arraydata(imgv), reverse(axes(imgv,1)),:)
        
        # imgv = permutedims(imgv, DimensionalData.commondims(>:, (DimensionalData.ZDim, DimensionalData.YDim, DimensionalData.XDim, DimensionalData.TimeDim, DimensionalData.Dimension, DimensionalData.Dimension), dims(imgv)))
        # y, x = dims(imgv)
        # :xguide --> DimensionalData.label(x)
        # :yguide --> DimensionalData.label(y)
        # :zguide --> DimensionalData.label(imgv)
        # :colorbar_title --> DimensionalData.label(imgv)
        # DimensionalData._xticks!(plotattributes, s, x)
        # DimensionalData._yticks!(plotattributes, s, y)
        # DimensionalData._withaxes(x, y, imgv)
        # arraydata(imgv)
    end

    # # If wcs=true (default) and grid=true (not default), overplot a WCS 
    # # grid.
    # if (!haskey(plotattributes, :wcs) || plotattributes[:wcs]) &&
    #     haskey(plotattributes, :xgrid) && plotattributes[:xgrid] &&
    #     haskey(plotattributes, :ygrid) && plotattributes[:ygrid]

    #     # Plot the WCSGrid as a second series (actually just lines)
    #     @series begin
    #         wcsg, gridspec
    #     end
    # end
    # return
end


"""
    implot(img::AstroImageMat; clims=extrema, stretch=identity, cmap=nothing)

Create a read only view of an array or AstroImageMat mapping its data values
to Colors according to `clims`, `stretch`, and `cmap`.

The data is first clamped to `clims`, which can either be a tuple of (min, max)
values or a function accepting an iterator of pixel values that returns (min, max).
By default, `clims=extrema` i.e. the minimum and maximum of `img`.
Convenient functions to use for `clims` are:
`extrema`, `zscale`, and `percent(p)`

Next, the data is rescaled to [0,1] and remapped according to the function `stretch`.
Stretch can be any monotonic function mapping values in the range [0,1] to some range [a,b].
Note that `log(0)` is not defined so is not directly supported.
For a list of convenient stretch functions, see:
`logstretch`, `powstretch`, `squarestretch`, `asinhstretch`, `sinhstretch`, `powerdiststretch`

Finally the data is mapped to RGB values according to `cmap`. If cmap is `nothing`,
grayscale is used. ColorSchemes.jl defines hundreds of colormaps. A few nice ones for
images include: `:viridis`, `:magma`, `:plasma`, `:thermal`, and `:turbo`.

Crucially, this function returns a view over the underlying data. If `img` is updated
then those changes will be reflected by this view with the exception of `clims` which
is not recalculated.

Note: if clims or stretch is a function, the pixel values passed in are first filtered
to remove non-finite or missing values.

### Defaults
The default values of `clims`, `stretch`, and `cmap` are `extrema`, `identity`, and `nothing`
respectively.
You may alter these defaults using `AstroImages.set_clims!`,  `AstroImages.set_stretch!`, and
`AstroImages.set_cmap!`.

### Automatic Display
Arrays wrapped by `AstroImageMat()` get displayed as images automatically by calling 
`imview` on them with the default settings when using displays that support showing PNG images.

### Missing data
Pixels that are `NaN` or `missing` will be displayed as transparent when `cmap` is set
or black if.
+/- Inf will be displayed as black or white respectively.

### Exporting Images
The view returned by `imview` can be saved using general `FileIO.save` methods.
Example:
```julia
v = imview(data, cmap=:magma, stretch=asinhstretch, clims=percent(95))
save("output.png", v)
```
"""
implot

# @recipe function f(
#     img::AstroImageVec{T};
# ) where {T<:Number}

#     # We don't to override e.g. histograms
#     if haskey(plotattributes, :seriestype)
#         return arraydata(img)

#     else

#         # we have a wcs flag (from the image by default) so that users can skip over 
#         # plotting in physical coordinates. This is especially important
#         # if the WCS headers are mallformed in some way.
#         if !haskey(plotattributes, :wcs) || plotattributes[:wcs]

#             # Note: if the axes are on unusual sides (e.g. y-axis at right, x-axis at top)
#             # then these coordinates are not correct. They are only correct exactly
#             # along the axis.

#             # ax = haskey(plotattributes, :axes) ? plotattributes[:axes] : (1,2)
#             # coords = haskey(plotattributes, :coords) ? plotattributes[:coords] : ones(wcs(img).naxis)
#             ax = findall(==(:), getfield(img, :wcs_axes))
#             j = 0
#             coords = map(getfield(img, :wcs_axes)) do coord
#                 j += 1
#                 if coord === (:)
#                     first(axes(img,j))
#                 else
#                     coord
#                 end
#             end

#             l = ctype_label(wcs(img).ctype[only(ax)], wcs(img).radesys)
#             xguide --> l

#             # minx = first(axes(imgv,ax[2]))
#             # maxx = last(axes(imgv,ax[2]))
#             # miny = first(axes(imgv,ax[1]))
#             # maxy = last(axes(imgv,ax[1]))
#             # extent = (minx, maxx, miny, maxy)

#             # wcsg = WCSGrid(wcs(imgv), extent, ax, coords)
#             # gridspec = wcsgridspec(wcsg)
            
#             # xticks --> (gridspec.tickpos1x, wcslabels(wcs(imgv), 1, gridspec.tickpos1w))
#             # xguide --> ctype_label(wcs(imgv).ctype[1], wcs(imgv).radesys)

#             # yticks --> (gridspec.tickpos2x, wcslabels(wcs(imgv), 2, gridspec.tickpos2w))
#             # yguide --> ctype_label(wcs(imgv).ctype[2], wcs(imgv).radesys)

#             # # To ensure the physical axis tick labels are correct the axes must be
#             # # tight to the image
#             # xl = first(axes(imgv,2)), last(axes(imgv,2))
#             # yl = first(axes(imgv,1)), last(axes(imgv,1))
#             # ylims --> yl
#             # xlims --> xl
#         end

#         # # Disable equal aspect ratios if the scales are totally different
#         # if max(size(imgv)...)/min(size(imgv)...) >= 7
#         #     aspect_ratio --> :none
#         # end

#         # # We have to do a lot of flipping to keep the orientation corect 
#         # yflip := false
#         # xflip := false

#         # @series begin
#         #     axes(imgv,2), axes(imgv,1), view(arraydata(imgv), reverse(axes(imgv,1)),:)
#         # end

#         # If wcs=true (default) and grid=true (not default), overplot a WCS 
#         # grid.
#         # if (!haskey(plotattributes, :wcs) || plotattributes[:wcs]) &&
#         #     haskey(plotattributes, :xgrid) && plotattributes[:xgrid] &&
#         #     haskey(plotattributes, :ygrid) && plotattributes[:ygrid]

#         #     # Plot the WCSGrid as a second series (actually just lines)
#         #     @series begin
#         #         wcsg, gridspec
#         #     end
#         # end
#         @series begin
#             arraydata(img)
#         end
#         return
#     end
# end


struct WCSGrid
    w
    extent
    ax
    coords
end
WCSGrid(w,extent,ax) = WCSGrid(w,extent,ax,ones(length(ax)))


"""
    wcsticks(img, axnum)

Generate nice tick labels for an AstroImageMat along axis `axnum`
Returns a vector of pixel positions and a vector of strings.

Example:
plot(img, xticks=wcsticks(img, 1), yticks=wcsticks(img, 2))
"""
function wcsticks(img::AstroImageMat, axnum)
    gs = wcsgridspec(WCSGrid(img))
    tickposx = axnum == 1 ? gs.tickpos1x : gs.tickpos2x
    tickposw = axnum == 1 ? gs.tickpos1w : gs.tickpos2w
    return tickposx, wcslabels(
        wcs(img),
        axnum,
        tickposw
    )
end

# Function to generate nice string coordinate labels given a WCSTransform, axis number,
# and a vector of tick positions in world coordinates.
# This is used for labelling ticks and for annotating grid lines.
function wcslabels(w::WCSTransform, axnum, tickposw)

    if length(tickposw) == 0
        return String[]
    end

    # Select a unit converter (e.g. 12.12 -> (a,b,c,d)) and list of units
    if w.cunit[axnum] == "deg"
        if startswith(uppercase(w.ctype[axnum]), "RA")
            converter = deg2hms
            units = hms_units
        else
            converter = deg2dmsmμ
            units = dmsmμ_units
        end
    else
        converter = x->(x,)
        units = ("",)
    end

    # Format inital ticklabel 
    ticklabels = fill("", length(tickposw))
    # We only include the part of the label that has changed since the last time.
    # Split up coordinates into e.g. sexagesimal
    parts = map(tickposw) do w
        vals = converter(w)
        return vals
    end

    # Start with something impossible of the same size:
    last_coord = Inf .* converter(first(tickposw))
    zero_coords_i = maximum(map(parts) do vals
        changing_coord_i = findfirst(vals .!= last_coord)
        if isnothing(changing_coord_i)
            changing_coord_i = 1
        end
        last_coord = vals
        return changing_coord_i
    end)


    # Loop through using only the relevant part of the label
    # Start with something impossible of the same size:
    last_coord = Inf .* converter(first(tickposw))
    for (i,vals) in enumerate(parts)
        changing_coord_i = findfirst(vals .!= last_coord)
        if isnothing(changing_coord_i)
            changing_coord_i = 1
        end
        # Don't display just e.g. 00" when we should display 50'00"
        if changing_coord_i > 1 && vals[changing_coord_i] == 0
            changing_coord_i = changing_coord_i -1
        end
        val_unit_zip = zip(vals[changing_coord_i:zero_coords_i],units[changing_coord_i:zero_coords_i])
        ticklabels[i] = mapreduce(*, enumerate(val_unit_zip)) do (coord_i,(val,unit))
            # If the last coordinate we print if the last coordinate we have available,
            # display it with decimal places
            if coord_i + changing_coord_i - 1== length(vals)
                str = @sprintf("%.2f", val)
            else
                str = @sprintf("%02d", val)
            end
            if length(str) > 0
                return str * unit
            else
                return str
            end
        end
        last_coord = vals
    end

    return ticklabels
end

# Extended form of deg2dms that further returns mas, microas.
function deg2dmsmμ(deg)
    d,m,s = deg2dms(deg)
    s_f = floor(s)
    mas = (s - s_f)*1e3
    mas_f = floor(mas)
    μas = (mas - mas_f)*1e3
    return (d,m,s_f,mas_f,μas)
end
const dmsmμ_units = [
    "°",
    "'",
    "\"",
    "mas",
    "μas",
]
const hms_units = [
    "ʰ",
    "ᵐ",
    "ˢ",
]

function ctype_label(ctype,radesys)
    if length(ctype) == 0
        return radesys
    elseif startswith(ctype, "RA")
        return "Right Ascension ($(radesys))"
    elseif startswith(ctype, "GLON")
        return "Galactic Longitude"
    elseif startswith(ctype, "TLON")
        return "ITRS"
    elseif startswith(ctype, "DEC")
        return "Declination ($(radesys))"
    elseif startswith(ctype, "GLAT")
        return "Galactic Latitude"
    # elseif startswith(ctype, "TLAT")
    else
        return ctype
    end
end



"""
    WCSGrid(img::AstroImageMat, ax=(1,2), coords=(first(axes(img,ax[1])),first(axes(img,ax[2]))))

Given an AstroImageMat, return information necessary to plot WCS gridlines in physical
coordinates against the image's pixel coordinates.
This function has to work on both plotted axes at once to handle rotation and general
curvature of the WCS grid projected on the image coordinates.

"""
function WCSGrid(img::AstroImageMat, ax=(1,2), coords=ones(wcs(img).naxis))

    minx = first(axes(img,ax[1]))
    maxx = last(axes(img,ax[1]))
    miny = first(axes(img,ax[2]))
    maxy = last(axes(img,ax[2]))
    extent = (minx, maxx, miny, maxy)

    return WCSGrid(wcs(img), extent, ax, coords)
end



# Recipe for a WCSGrid with lines, optional ticks (on by default),
# and optional grid labels (off by defaut).
# The AstroImageMat plotrecipe uses this recipe for grid lines if `grid=true`.
@recipe function f(wcsg::WCSGrid, gridspec=wcsgridspec(wcsg))
    label --> ""
    xs, ys = wcsgridlines(gridspec)

    if haskey(plotattributes, :foreground_color_grid) 
        color --> plotattributes[:foreground_color_grid]
    elseif haskey(plotattributes, :foreground_color) 
        color --> plotattributes[:foreground_color]
    else
        color --> :black
    end
    if haskey(plotattributes, :foreground_color_text) 
        textcolor = plotattributes[:foreground_color_text]
    else
        textcolor = plotattributes[:color]
    end
    annotate = haskey(plotattributes, :gridlabels) && plotattributes[:gridlabels]

    xguide --> ctype_label(wcsg.w.ctype[wcsg.ax[1]], wcsg.w.radesys)
    yguide --> ctype_label(wcsg.w.ctype[wcsg.ax[2]], wcsg.w.radesys)

    xlims --> wcsg.extent[1], wcsg.extent[2]
    ylims --> wcsg.extent[3], wcsg.extent[4]

    grid := false
    tickdirection := :none

    xticks --> wcsticks(wcsg, 1, gridspec)
    yticks --> wcsticks(wcsg, 2, gridspec)

    @series xs, ys

    # We can optionally annotate the grid with their coordinates.
    # These come after the grid lines so they appear overtop.
    if annotate
        @series begin
            # TODO: why is this reverse necessary?
            rotations = reverse(rad2deg.(gridspec.annotations1θ))
            ticklabels = wcslabels(wcsg.w, 1, gridspec.annotations1w)
            seriestype := :line
            linewidth := 0
            # TODO: we need to use requires to load in Plots for the necessary text control. Future versions of RecipesBase might fix this.
            series_annotations := [
                Main.Plots.text(" $l", :right, :bottom, textcolor, 8, rotation=(-95 <= r <= 95) ? r : r+180)
                for (l, r) in zip(ticklabels, rotations)
            ]
            gridspec.annotations1x, gridspec.annotations1y
        end
        @series begin
            rotations  = rad2deg.(gridspec.annotations2θ)
            ticklabels = wcslabels(wcsg.w, 2, gridspec.annotations2w)
            seriestype := :line
            linewidth := 0
            series_annotations := [
                Main.Plots.text(" $l", :right, :bottom, textcolor, 8, rotation=(-95 <= r <= 95) ? r : r+180)
                for (l, r) in zip(ticklabels, rotations)
            ]
            gridspec.annotations2x, gridspec.annotations2y
        end

    end

    return
end

# Helper: true if all elements in vector are equal to each other.
allequal(itr) = all(==(first(itr)), itr)

# This function is responsible for actually laying out grid lines for a WCSGrid,
# ensuring they don't exceed the plot bounds, finding where they intersect the axes,
# and picking tick locations at the appropriate intersections with the left and 
# bottom axes.
function wcsgridspec(wsg::WCSGrid)
    # Most of the complexity of this function is making sure everything
    # generalizes to N different, possiby skewed axes, where a change in
    # the opposite coordinate or even an unplotted coordinate affects
    # the grid.
    
    # x and y denote pixel coordinates (along `ax`), u and v are world coordinates roughly along same.
    ax = collect(wsg.ax)
    coordsx = convert(Vector{Float64}, collect(wsg.coords))
    minx, maxx, miny, maxy = wsg.extent
    # @show wsg.extent

    # Find the extent of this slice in world coordinates
    posxy = repeat(coordsx, 1, 4)
    posxy[ax,1] .= (minx,miny)
    posxy[ax,2] .= (minx,maxy)
    posxy[ax,3] .= (maxx,miny)
    posxy[ax,4] .= (maxx,maxy)
    posuv = pix_to_world(wsg.w, posxy)
    (minu, maxu), (minv, maxv) = extrema(posuv, dims=2)[[ax[1],ax[2]],:]


    # In general, grid can be curved when plotted back against the image,
    # so we will need to sample multiple points along the grid.
    # TODO: find a good heuristic for this based on the curvature.
    N_points = 50
    urange = range(minu, maxu, length=N_points)
    vrange = range(minv, maxv, length=N_points)

    # Find nice grid spacings using PlotUtils.optimize_ticks
    # These heuristics can probably be improved
    # TODO: this does not handle coordinates that wrap around
    Q=[(1.0,1.0), (3.0, 0.8), (2.0, 0.7), (5.0, 0.5)] 
    k_min = 3
    k_ideal = 5
    k_max = 10

    tickpos2x = Float64[]
    tickpos2w = Float64[]
    gridlinesxy2 = NTuple{2,Vector{Float64}}[]
    # Not all grid lines will intersect the x & y axes nicely.
    # If we don't get enough valid tick marks (at least 2) loop again
    # requesting more locations up to three times.
    local tickposv
    j = 3
    while length(tickpos2x) < 2 && j > 0
        k_min += 2
        k_ideal += 2
        k_max += 2
        j -= 1

        tickposv = optimize_ticks(6minv, 6maxv; Q, k_min, k_ideal, k_max)[1]./6
        # tickposv = [10:60:360;]
        # tickposv = [-13.834999999999999, -13.83, -13.825000000000001, -13.82, -13.815, -13.81]

        empty!(tickpos2x)
        empty!(tickpos2w)
        empty!(gridlinesxy2)
        for tickv in tickposv
            # Make sure we handle unplotted slices correctly.
            griduv = repeat(posuv[:,1], 1, N_points)
            griduv[ax[1],:] .= urange
            griduv[ax[2],:] .= tickv
            posxy = world_to_pix(wsg.w, griduv)

            # Now that we have the grid in pixel coordinates, 
            # if we find out where the grid intersects the axes we can put
            # the labels in the correct spot
            
            # We can use these masks to determine where, and in what direction
            # the gridlines leave the plot extent
            in_horz_ax = minx .<=  posxy[ax[1],:] .<= maxx
            in_vert_ax = miny .<=  posxy[ax[2],:] .<= maxy
            in_axes = in_horz_ax .& in_vert_ax
            if count(in_axes) < 2
                continue
            elseif all(in_axes)
                point_entered = [
                    posxy[ax[1],begin]
                    posxy[ax[2],begin]
                ]
                point_exitted = [
                    posxy[ax[1],end]
                    posxy[ax[2],end]
                ]
            elseif allequal(posxy[ax[1],findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    posxy[ax[1],max(begin,findfirst(in_axes)-1)]
                    # posxy[ax[2],max(begin,findfirst(in_axes)-1)]
                    miny
                ]
                point_exitted = [
                    posxy[ax[1],min(end,findlast(in_axes)+1)]
                    # posxy[ax[2],min(end,findlast(in_axes)+1)]
                    maxy
                ]
            # Vertical grid lines
            elseif allequal(posxy[ax[2],findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    minx #posxy[ax[1],max(begin,findfirst(in_axes)-1)]
                    posxy[ax[2],max(begin,findfirst(in_axes)-1)]
                ]
                point_exitted = [
                    maxx #posxy[ax[1],min(end,findlast(in_axes)+1)]
                    posxy[ax[2],min(end,findlast(in_axes)+1)]
                ]
            else
                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findfirst(in_axes)
                x1 = posxy[ax[1],i]
                y1 = posxy[ax[2],i]
                x2 = posxy[ax[1],i+1]
                y2 = posxy[ax[2],i+1]
                if x2-x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m1 = (y2-y1)/(x2-x1)
                b1 = y1-m1*x1
                # If the line enters via the vertical axes...
                if findfirst(in_vert_ax) <= findfirst(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                    x = clamp(x,minx,maxx)
                    y = m1*x+b1
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b1)/m1 : (miny-b1)/m1
                    x = clamp(x,minx,maxx)
                    y = m1*x+b1
                end
            
                # From here, do a linear fit to find the intersection with the axis.
                point_entered = [
                    x
                    y
                ]


                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findlast(in_axes)
                x1 = posxy[ax[1],i-1]
                y1 = posxy[ax[2],i-1]
                x2 = posxy[ax[1],i]
                y2 = posxy[ax[2],i]
                if x2-x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m2 = (y2-y1)/(x2-x1)
                b2 = y2-m2*x2
                if findlast(in_vert_ax) > findlast(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                    x = clamp(x,minx,maxx)
                    y = m2*x+b2
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b2)/m2 : (miny-b2)/m2
                    x = clamp(x,minx,maxx)
                    y = m2*x+b2
                end
            
                # From here, do a linear fit to find the intersection with the axis.
                point_exitted = [
                    x 
                    y
                ]
            end


            if point_entered[1] == minx
                push!(tickpos2x, point_entered[2])
                push!(tickpos2w, tickv)
            end
            if point_exitted[1] == minx
                push!(tickpos2x, point_exitted[2])
                push!(tickpos2w, tickv)
            end
            # @show point_entered minx maxx miny maxy


            posxy_neat = [point_entered  posxy[[ax[1],ax[2]],in_axes] point_exitted]
            # posxy_neat = posxy
            # TODO: do unplotted other axes also need a fit?

            gridlinexy = (
                posxy_neat[1,:],
                posxy_neat[2,:]
            )
            push!(gridlinesxy2, gridlinexy)
        end
    end

    # Then do the opposite coordinate
    k_min = 3
    k_ideal = 5
    k_max = 10
    tickpos1x = Float64[]
    tickpos1w = Float64[]
    gridlinesxy1 = NTuple{2,Vector{Float64}}[]
    # Not all grid lines will intersect the x & y axes nicely.
    # If we don't get enough valid tick marks (at least 2) loop again
    # requesting more locations up to three times.
    local tickposu
    j = 3
    while length(tickpos1x) < 2 && j > 0
        k_min += 2
        k_ideal += 2
        k_max += 2
        j -= 1

        tickposu = optimize_ticks(6minu, 6maxu; Q, k_min, k_ideal, k_max)[1]./6

        # tickposu = [274.7, 274.705, 274.71, 274.715, 274.71999999999997, 274.72499999999997, 274.72999999999996]
        # tickposu = [10:60:360;]

        empty!(tickpos1x)
        empty!(tickpos1w)
        empty!(gridlinesxy1)
        for ticku in tickposu
            # Make sure we handle unplotted slices correctly.
            griduv = repeat(posuv[:,1], 1, N_points)
            griduv[ax[1],:] .= ticku
            griduv[ax[2],:] .= vrange
            posxy = world_to_pix(wsg.w, griduv)

            # Now that we have the grid in pixel coordinates, 
            # if we find out where the grid intersects the axes we can put
            # the labels in the correct spot

            # We can use these masks to determine where, and in what direction
            # the gridlines leave the plot extent
            in_horz_ax = minx .<=  posxy[ax[1],:] .<= maxx
            in_vert_ax = miny .<=  posxy[ax[2],:] .<= maxy
            in_axes = in_horz_ax .& in_vert_ax


            if count(in_axes) < 2
                continue
            elseif all(in_axes)
                point_entered = [
                    posxy[ax[1],begin]
                    posxy[ax[2],begin]
                ]
                point_exitted = [
                    posxy[ax[1],end]
                    posxy[ax[2],end]
                ]
            # Horizontal grid lines
            elseif allequal(posxy[ax[1],findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    posxy[ax[1],findfirst(in_axes)]
                    miny
                ]
                point_exitted = [
                    posxy[ax[1],findlast(in_axes)]
                    maxy
                ]
                # push!(tickpos1x, posxy[ax[1],findfirst(in_axes)])
                # push!(tickpos1w, ticku)
            # Vertical grid lines
            elseif allequal(posxy[ax[2],findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    minx
                    posxy[ax[2],findfirst(in_axes)]
                ]
                point_exitted = [
                    maxx
                    posxy[ax[2],findfirst(in_axes)]
                ]
            else
                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findfirst(in_axes)
                x1 = posxy[ax[1],i]
                y1 = posxy[ax[2],i]
                x2 = posxy[ax[1],i+1]
                y2 = posxy[ax[2],i+1]
                if x2-x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m1 = (y2-y1)/(x2-x1)
                b1 = y1-m1*x1
                # If the line enters via the vertical axes...
                if findfirst(in_vert_ax) < findfirst(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                    x = clamp(x,minx,maxx)
                    y = m1*x+b1
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b1)/m1 : (miny-b1)/m1
                    x = clamp(x,minx,maxx)
                    y = m1*x+b1
                end
            
                # From here, do a linear fit to find the intersection with the axis.
                point_entered = [
                    x
                    y
                ]

                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findlast(in_axes)
                x1 = posxy[ax[1],i-1]
                y1 = posxy[ax[2],i-1]
                x2 = posxy[ax[1],i]
                y2 = posxy[ax[2],i]
                if x2-x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m2 = (y2-y1)/(x2-x1)
                b2 = y2-m2*x2
                if findlast(in_vert_ax) > findlast(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                    x = clamp(x,minx,maxx)
                    y = m2*x+b2
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b2)/m2 : (miny-b2)/m2
                    x = clamp(x,minx,maxx)
                    y = m2*x+b2
                end
            
                # From here, do a linear fit to find the intersection with the axis.
                point_exitted = [
                    x 
                    y
                ]
            end

            posxy_neat = [point_entered  posxy[[ax[1],ax[2]],in_axes] point_exitted]
            # TODO: do unplotted other axes also need a fit?

            if point_entered[2] == miny
                push!(tickpos1x, point_entered[ax[1]])
                push!(tickpos1w, ticku)
            end
            if point_exitted[2] == miny
                push!(tickpos1x, point_exitted[ax[1]])
                push!(tickpos1w, ticku)
            end

            gridlinexy = (
                posxy_neat[1,:],
                posxy_neat[2,:]
            )
            push!(gridlinesxy1, gridlinexy)
        end
    end
    # @show tickpos1x

    # Grid annotations are simpler:
    annotations1w = Float64[]
    annotations1x = Float64[]
    annotations1y = Float64[]
    annotations1θ = Float64[]
    for ticku in tickposu
        # Make sure we handle unplotted slices correctly.
        griduv = posuv[:,1]
        griduv[ax[1]] = ticku
        griduv[ax[2]] = mean(vrange)
        posxy = world_to_pix(wsg.w, griduv)
        if !(minx < posxy[1] < maxx) ||
            !(miny < posxy[2] < maxy)
            continue
        end
        push!(annotations1w, ticku)
        push!(annotations1x, posxy[ax[1]])
        push!(annotations1y, posxy[ax[2]])

        # Now find slope (TODO: stepsize)
        # griduv[ax[2]] -= 1
        griduv[ax[2]] += 0.1step(vrange)
        posxy2 = world_to_pix(wsg.w, griduv)
        θ = atan(
            posxy2[ax[2]] - posxy[ax[2]],
            posxy2[ax[1]] - posxy[ax[1]],
        )
        push!(annotations1θ, θ)
    end
    annotations2w = Float64[]
    annotations2x = Float64[]
    annotations2y = Float64[]
    annotations2θ = Float64[]
    for tickv in tickposv
        # Make sure we handle unplotted slices correctly.
        griduv = posuv[:,1]
        griduv[ax[1]] = mean(urange)
        griduv[ax[2]] = tickv
        posxy = world_to_pix(wsg.w, griduv)
        if !(minx < posxy[1] < maxx) ||
            !(miny < posxy[2] < maxy)
            continue
        end
        push!(annotations2w, tickv)
        push!(annotations2x, posxy[ax[1]])
        push!(annotations2y, posxy[ax[2]])

        griduv[ax[1]] += 0.1step(urange)
        posxy2 = world_to_pix(wsg.w, griduv)
        θ = atan(
            posxy2[ax[2]] - posxy[ax[2]],
            posxy2[ax[1]] - posxy[ax[1]],
        )
        push!(annotations2θ, θ)
    end

    return (;
        gridlinesxy1,
        gridlinesxy2,
        tickpos1x,
        tickpos1w,
        tickpos2x,
        tickpos2w,

        annotations1w,
        annotations1x,
        annotations1y,
        annotations1θ,

        annotations2w,
        annotations2x,
        annotations2y,
        annotations2θ,
    )
end

# From a WCSGrid, return just the grid lines as a single pair of x & y coordinates
# suitable for plotting.
function wcsgridlines(wcsg::WCSGrid)
    return wcsgridlines(wcsgridspec(wcsg))
end
function wcsgridlines(gridspec::NamedTuple)
    # Unroll grid lines into a single series separated by NaNs
    xs1 = mapreduce(vcat, gridspec.gridlinesxy1, init=Float64[]) do gridline
        return vcat(gridline[1], NaN)
    end
    ys1 = mapreduce(vcat, gridspec.gridlinesxy1, init=Float64[]) do gridline
        return vcat(gridline[2], NaN)
    end
    xs2 = mapreduce(vcat, gridspec.gridlinesxy2, init=Float64[]) do gridline
        return vcat(gridline[1], NaN)
    end
    ys2 = mapreduce(vcat, gridspec.gridlinesxy2, init=Float64[]) do gridline
        return vcat(gridline[2], NaN)
    end

    xs = vcat(xs1, NaN, xs2)
    ys = vcat(ys1, NaN, ys2)
    return xs, ys
end



function wcsvecticks(w,coords,ax,minx,maxx)
    # x and y denote pixel coordinates (along `ax`), u and v are world coordinates roughly along same.
    coordsx = convert(Vector{Float64}, collect(coords))

    # Find the extent of this slice in world coordinates
    posxy = repeat(coordsx, 1, 2)
    posxy[ax,1] = minx
    posxy[ax,2] = maxx
    posuv = pix_to_world(w, posxy)
    minu, maxu = extrema(posuv[ax,:])

    # Find nice grid spacings using PlotUtils.optimize_ticks
    # These heuristics can probably be improved
    # TODO: this does not handle coordinates that wrap around
    Q=[(1.0,1.0), (3.0, 0.8), (2.0, 0.7), (5.0, 0.5)] 
    k_min = 3
    k_ideal = 5
    k_max = 10

    tickpos2x = Float64[]
    tickpos2w = Float64[]
    tickposv = optimize_ticks(6minv, 6maxv; Q, k_min, k_ideal, k_max)[1]./6
    griduv = posuv[:,1]
    griduv[ax,:] .= urange
    posxy = world_to_pix(wsg.w, griduv)

end