module UpSetPlot

using DataFrames
using CairoMakie
using Combinatorics

export upset_plot, to_dataframe

const my25colors = [
    :mediumblue, :brown3, :forestgreen, :mediumorchid3, :gold,
    :dodgerblue, :coral, :palegreen, :violet, :khaki,
    :aqua, :orangered, :lime, :fuchsia, :yellow,
    :royalblue, :firebrick, :lightseagreen, :purple, :darkgoldenrod,
    :darkturquoise, :orange, :darkcyan, :lightgrey, :grey
]

"""
    upset_plot(
        sets::Vector{T},
        set_names::Vector{String};
        fig_size::Tuple{Int64, Int64} = (1000, 1000),
        colors::Vector{Symbol} = my25colors,
        orientation::Symbol = :vertical,
        cumul::Bool = false,
        intersection_lists::Bool = false
    ) where T<:Set

Return the UpSet plot (https://en.wikipedia.org/wiki/UpSet_plot) computed from `sets`.

Arguments:
- `sets`: the vector of `Set`s to intersect.
- `set_names`: a `Vector{String}` storing the name of the sets to intersect.

Keyword arguments:
- `fig_size`:  the size of the UpSet plot. Default to `(1000, 1000)`
- `colors`:    the colors used for each set. Default to `my25colors`, a vector of named colors defined as a `const`.
- `orientation`: the orientation of the UpSet plot; one of `:horizontal`, `:h`, `:vertical`, or `:v`.
- `cumul`: default to `false`. If `true`, the UpSet plot includes an additional plot displaying the cumulative intersection size for each intersection degree.
- `intersection_lists`: default to `false`. If true, `upset_plot` additionally returns a `Dict` whose keys are concatenated set names and values are lists of elements specific to the intersection of sets found in the concatenated set names.
"""
function upset_plot(
        sets::Vector{T},
        set_names::Vector{String};
        fig_size::Tuple{Int64, Int64}=(1000, 1000),
        colors::Vector{Symbol}=my25colors,
        orientation::Symbol=:vertical,
        cumul::Bool = false,
        intersection_lists::Bool = false
) where T<:Set

    # Check lengths
    length(sets) == length(set_names) || error("Sets and and set names are not the same length.")

    # Delete `missing`s
    sets_copy = collect.(skipmissing.(sets))
    # Keep nonempty sets
    idxs_empty_sets = findall(isempty, sets_copy)
    idxs_nonempty_sets = setdiff(eachindex(sets_copy), idxs_empty_sets)
    sets_copy = sets_copy[idxs_nonempty_sets]
    # Inform of deletion of empty sets
    for idx in idxs_empty_sets
        @info "$(set_names[idx]) is empty and was deleted."
    end
    n_sets = length(sets_copy)
    # Delete names of empty sets
    setnames_copy = set_names[idxs_nonempty_sets]

    # Check all elements are of the same type
    #!allequal(eltype.(sets_copy)) && error("Sets should have elements of the same type.")

    # Unique elements in `sets`
    unique_elts = reduce(∪, sets_copy) |> collect |> sort

    # Get set membership for each element
    membership = Matrix{Bool}(undef, length(unique_elts), n_sets)
    for i in eachindex(sets_copy)
        s = sets_copy[i]
        membership[:, i] = [in(elt, s) for elt in unique_elts]
    end

    #= Unique combinations of indices of sets.
    `combinations` is from Combinatorics. If the dependency on Combinatorics is an issue, we
    can implement `combinations` ourselves using `Iterators.product` and `filter`. This is
    ok up to 10 sets, which gives 1023 combinations, but it will be too slow for more sets.
    =#
    combins = combinations(eachindex(sets_copy))
    # Delete the first combination as it is empty
    combins = collect(combins)[2:end]
    n_combins = length(combins)

    # Counts for each combination
    # Intersection lists if `intersection_lists`
    combin2count = Dict{Vector{Int64}, Int64}()
    if intersection_lists
        combin2list = Dict{String, Vector{String}}()
        for combin in combins
            not_combin = setdiff(eachindex(sets_copy), combin)
            idxs = findall(
                r -> all(!iszero, r[combin]) && all(iszero, r[not_combin]),
                eachrow(membership)
            )
            combin2count[combin] = length(idxs)
            combin_set_names = join(setnames_copy[combin], "_")
            combin2list[combin_set_names] = unique_elts[idxs]
        end
    else
        for combin in combins
            not_combin = setdiff(eachindex(sets_copy), combin)
            combin2count[combin] = count(
                r -> all(!iszero, r[combin]) && all(iszero, r[not_combin]),
                eachrow(membership)
            )
        end
    end

    # Counts for intersections of 1, 2, 3... sets.
    intersect_counts = Int64[]
    len_combins = length.(combins)
    for i in 1:n_sets
        counts_i = 0
        idxs = findall(==(i), len_combins)
        for idx in idxs
            counts_i += combin2count[combins[idx]]
        end
        push!(intersect_counts, counts_i)
    end

    # UpSet plot
    fig = Figure(size=fig_size)

    if orientation in [:horizontal, :h]
        # Top left
        top_left = Axis(
            fig[1, 1];
            xticks = (eachindex(sets_copy), setnames_copy),
            xticklabelrotation = π/4,
            ylabel = "Set size"
        )
        set_sizes = length.(sets_copy)
        barplot!(
            top_left,
            eachindex(sets_copy),
            set_sizes;
            color = eachindex(sets_copy),
            colormap = colors[eachindex(sets_copy)]
        )
        top_left.xreversed=true
        hidespines!(top_left)

        # Top right
        if cumul
            top_right = Axis(
                fig[1, 2];
                xlabel = "Cumulative intersection size",
                ylabel = "Intersection degree",
                yticks = 1:n_sets,
                ytickalign = 1,
                yticklabelpad = 0
            )
            barplot!(
                top_right,
                1:n_sets,
                intersect_counts;
                color = :lightgrey,
                strokecolor = :grey,
                strokewidth = 1,
                direction = :x
            )
            hidespines!(top_right)
        end

        # Bottom left
        bottom_left = Axis(
            fig[2, 1];
            xticks = (eachindex(sets_copy), setnames_copy),
            xaxisposition = :top
        )
        for (i, combin) in enumerate(reverse(combins))
            min_x = minimum(combin)
            max_x = maximum(combin)
            lines!(
                bottom_left,
                [n_sets - min_x + 1, n_sets - max_x + 1],
                [i, i];
                color=:grey
            )
            # Plot the sets in the current combination as large dots
            for c in combin
                clr = colors[c]
                scatter!(
                    bottom_left,
                    n_sets - c + 1,
                    i;
                    markersize=Int(round(fig_size[1]/50)),
                    color=clr
                )
            end
        end
        ylims!(bottom_left, 0, n_combins + 1)
        hidedecorations!(bottom_left)
        hidespines!(bottom_left)

        # Bottom right
        bottom_right = Axis(
            fig[2, 2];
            xlabel = "Intersection size"
        )
        combin_counts = map(c -> get(combin2count, c, 0), combins)
        barplot!(
            bottom_right,
            n_combins:-1:1,
            combin_counts;
            strokecolor = :grey,
            strokewidth = 1,
            color = :lightgrey,
            direction = :x
        )
        ylims!(bottom_right, 0, n_combins + 1)
        hideydecorations!(bottom_right)
        hidespines!(bottom_right)

        # Arrange the four plots
        linkxaxes!(top_left, bottom_left)
        linkyaxes!(bottom_left, bottom_right)
        rowsize!(fig.layout, 1, Relative(1/4))
        rowsize!(fig.layout, 2, Relative(3/4))
        colsize!(fig.layout, 1, Relative(1/3))
        colsize!(fig.layout, 2, Relative(2/3))

    elseif orientation in [:vertical, :v]
        # Top left
        if cumul
            top_left = Axis(
                fig[1, 1];
                xlabel = "Intersection degree",
                xticks = 1:n_sets,
                ylabel = "Cumulative intersection size"
            )
            barplot!(
                top_left,
                1:n_sets,
                intersect_counts;
                color = :lightgrey,
                strokecolor = :grey,
                strokewidth = 1
            )
            hidespines!(top_left)
        end

        # Top right
        top_right = Axis(
            fig[1, 2];
            ylabel = "Intersection size"
        )
        combin_counts = map(c -> get(combin2count, c, 0), combins)
        barplot!(
            top_right,
            1:n_combins,
            combin_counts;
            strokecolor = :grey,
            strokewidth = 1,
            color = :lightgrey
        )
        xlims!(top_right, 0, n_combins + 1)
        hidexdecorations!(top_right)
        hidespines!(top_right)

        # Bottom left
        bottom_left = Axis(
            fig[2, 1];
            xlabel = "Set size",
            xreversed = true,
            yaxisposition = :right,
            yticks = (eachindex(sets_copy), setnames_copy),
            yreversed = true
        )
        set_sizes = length.(sets_copy)
        barplot!(
            bottom_left,
            eachindex(sets_copy),
            set_sizes;
            color = eachindex(sets_copy),
            colormap = colors[eachindex(sets_copy)],
            direction = :x
        )
        hidespines!(bottom_left)

        # Bottom right
        bottom_right = Axis(
            fig[2, 2];
            xticks = (eachindex(sets_copy), setnames_copy),
            xaxisposition = :top
        )
        for (i, combin) in enumerate(combins)
            min_y = minimum(combin)
            max_y = maximum(combin)
            lines!(
                bottom_right,
                [i, i],
                [n_sets - min_y + 1, n_sets - max_y + 1];
                color=:grey
            )
            # Plot the sets in the current combination as large dots
            for c in combin
                clr = colors[c]
                scatter!(
                    bottom_right,
                    i,
                    n_sets - c + 1;
                    markersize=Int(round(fig_size[1]/50)),
                    color=clr
                )
            end
        end
        xlims!(bottom_right, 0, n_combins + 1)
        hidedecorations!(bottom_right)
        hidespines!(bottom_right)

        # Arrange the four plots
        linkxaxes!(top_right, bottom_right)
        linkyaxes!(bottom_left, bottom_right)
        colsize!(fig.layout, 1, Relative(1/5))
        colsize!(fig.layout, 2, Relative(4/5))
        rowsize!(fig.layout, 1, Relative(3/4))
        rowsize!(fig.layout, 2, Relative(1/4))

    else
        error("`orientation` is not one of :horizontal, :h, :vertical, or :v.")
    end

    intersection_lists ? (return (fig, combin2list)) : (return fig)

end


"""
    upset_plot(
            df::DataFrame;
            set_names::Vector{String} = setdiff(names(df), ["id"]),
            fig_size::Tuple{Int64, Int64} = (1000, 1000),
            colors::Vector{Symbol} = my25colors,
            orientation::Symbol = :vertical,
            cumul::Bool = false,
            intersection_lists::Bool = false
    )
Return the UpSet plot (https://en.wikipedia.org/wiki/UpSet_plot) computed from sets stored in `df`'s columns.

The sets can be encoded in two different ways:
- `df`'s columns whose name is in `set_names` include the set elements; `missing`s are not considered set elements and deleted.
- One column, named `:id`, includes all possible elements, and the columns whose name is in `set_names` include booleans to encode set membership.

Columns whose name is in `set_names` are excluded if they are empty or contain only `missing`s.

Keyword arguments:
- `set_names`: a `Vector{String}` storing the name of the sets to intersect. Default to all column names in `df` except `"id"`.
- `fig_size`:  the size of the UpSet plot.
- `colors`:    the colors used for each set. `my25colors` is a vector of named colors defined as a `const`.
- `orientation`: the orientation of the UpSet plot; one of `:horizontal`, `:h`, `:vertical`, or `:v`.
- `cumul`: default to `false`. If `true`, the UpSet plot includes an additional plot displaying the cumulative intersection size for each intersection degree.
- `intersection_lists`: default to `false`. If `true`, `upset_plot` additionally returns a `Dict` whose keys are concatenated set names and values are vectors of elements specific to the intersection of sets found in the concatenated set names.

# EXAMPLE
```julia-repl
julia> set_names = ["Set1", "Set2", "Set3", "Set4", "Set5", "Set6"]
julia> df1 = DataFrame(
    Set1 = ["ID01", "ID02", "ID03", "ID07", "ID08", "ID09", "ID10", "ID04", "ID05", "ID06"],
    Set2 = ["ID01", "ID02", "ID03", "ID04", "ID05", "ID11", "ID12", "ID13", "ID14", "ID15"],
    Set3 = ["ID01", "ID02", "ID03", "ID07", "ID13", missing, missing, missing, missing, missing],
    Set4 = ["ID16", "ID17", "ID18", "ID19", "ID14", "ID02", "ID03", missing, missing, missing],
    Set5 = fill(missing, 10),
    Set6 = ["ID01", "ID02", "ID03", "ID04", "ID05", "ID11", "ID12", "ID13", "ID16", missing],
    Col_x = ["x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10"]
)
julia> df2 = DataFrame(
    id = ["ID01", "ID02", "ID03", "ID04", "ID05", "ID06", "ID07", "ID08", "ID09", "ID10", "ID11", "ID12", "ID13", "ID14", "ID15", "ID16", "ID17", "ID18", "ID19"],
    Set1 = [true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false],
    Set2 = [true, true, true, true, true, false, false, false, false, false, true, true, true, true, true, false, false, false, false],
    Set3 = [true, true, true, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false],
    Set4 = [false, true, true, false, false, false, false, false, false, false, false, false, false, true, false, true, true, true, true],
    Set5 = fill(false, 19),
    Set6 = [true, true, true, true, true, false, false, false, false, false, true, true, true, false, false, true, false, false, false]
)
julia> fig1, lists1 = upset_plot(df1; set_names=set_names, intersection_lists=true);
julia> fig2, lists2 = upset_plot(df2; intersection_lists=true);
julia> lists_1 == lists_2
true
julia> lists1["Set1"] == ["ID06", "ID08", "ID09", "ID10"]
true
julia> lists2["Set1_Set2_Set6"] == ["ID04", "ID05"]
true
```
"""
function upset_plot(
        df::DataFrame;
        set_names::Vector{String} = setdiff(names(df), ["id"]),
        fig_size::Tuple{Int64, Int64} = (1000, 1000),
        colors::Vector{Symbol} = my25colors,
        orientation::Symbol = :vertical,
        cumul::Bool = false,
        intersection_lists::Bool = false
)
    elt_types = eltype.(skipmissing.(eachcol(df[:, set_names]))) |> unique
    if length(elt_types) == 1
        T = elt_types[1]
    elseif length(elt_types) == 2
        # Columns with only `missing`s will give `Union{}`
        in(Union{}, elt_types) && (elt_types = setdiff(elt_types, [Union{}]))
        T = elt_types[1]
    else
        error("Columns should have elements of the same type.")
    end

    # Test if set membership is encoded via booleans or lists of set elements
    bool_encoding = (T == Bool)

    #=
    If `bool_encoding == true`, it is expected that the dataframe has a column
    named `"id"`, which includes all possible set elements. Each column in
    `set_names` includes true/false to record set membership.
    If `bool_encoding == false`, it is expected that the columns in `set_names`
    include set elements and, possibly, `missing`s.
    =#
    if bool_encoding
        # Check the presence of column "id"
        in("id", names(df)) || error("Column \"id\" is missing.")
        sets = Set.([df.id[df[:, set_name]] for set_name in set_names])
    else
        sets = Set.([collect(skipmissing(df[:, set_name])) for set_name in set_names])
    end

    return upset_plot(
        sets,
        set_names;
        fig_size = fig_size,
        colors = colors,
        orientation = orientation,
        cumul = cumul,
        intersection_lists = intersection_lists
        )
end

"""
    to_dataframe(
        lists::Dict{String, Vector{T}}
    ) where T

Return the non empty values of `lists` as a dataframe whose column names are `lists`'s keys.

The columns of the dataframe are sorted by size, excluding `missing`s.
"""
function to_dataframe(
        lists::Dict{String, Vector{T}}
) where T
    # Get the length of the longest list
    max_len = maximum(length.(values(lists)))

    # Construct the dataframe
    df = DataFrame()
    for k in keys(lists)
        if !isempty(lists[k])
            list = convert(Vector{Union{T, Missing}}, lists[k])
            n_missing = max_len - length(list)
            append!(list, fill(missing, n_missing))
            df = hcat(df, DataFrame(k => list))
        end
    end

    # Sort columns by length, excluding `missing`s
    col_len = [count(!ismissing, c) for c in eachcol(df)]
    p = sortperm(col_len; rev=true)
    df = df[:, names(df)[p]]

    return df
end

end
