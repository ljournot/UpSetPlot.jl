# UpSetPlot

[![Build Status](https://github.com/ljournot/UpSetPlot.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ljournot/UpSetPlot.jl/actions/workflows/CI.yml?query=branch%3Amain)

## About
UpSet plots (https://en.wikipedia.org/wiki/UpSet_plot) are a data visualization method for showing set data with more than three intersecting sets. UpSet plots tend to perform better than Venn diagrams for larger numbers of sets and when it is desirable to also show contextual information about the set intersections.

![IMAGE](https://github.com/ljournot/UpSetPlot.jl/blob/main/UpSet_examples.png)

## Installation
Install UpSetPlot.jl by running the following commands in the Julia REPL:
```julia-repl
julia> using Pkg

julia> Pkg.add(url="https://github.com/ljournot/UpSetPlots.jl")
```
Alternatively, in the Julia REPL type `]`, then
```
(@v1.12) pkg> add https://github.com/ljournot/UpSetPlots.jl
```

## Usage
The main function is `upset_plot`, which returns the UpSet plot computed from:
- Sets stored in a `Vector{Set}`.
```
upset_plot(
        sets::Vector{T},
        set_names::Vector{String};
        fig_size::Tuple{Int64, Int64} = (1000, 1000),
        colors::Vector{Symbol} = my25colors, # a vector of named colors
        intersection_lists::Bool = false
    ) where T<:Set
```
- Sets stored in a dataframe's columns.
```
upset_plot(
    df::DataFrame;
    set_names::Vector{String} = setdiff(names(df), ["id"]),
    fig_size::Tuple{Int64, Int64} = (1000, 1000),
    colors::Vector{Symbol} = my25colors,
    intersection_lists::Bool = false
)
```
In the latter case, the sets can be encoded in two different ways:
- `df`'s columns whose name is in `set_names` include the set elements; `missing`s are not considered set elements and deleted.
- One column, named `:id`, includes all possible elements, and the columns whose name is in `set_names` include booleans to encode set membership.

Columns not in `set_names` are not further considered.
Columns whose name is in `set_names` are excluded if they are empty or contain only `missing`s.

If `intersection_lists` is `true`, `upset_plot` additionally returns a `Dict` whose keys are concatenated set names and values are vectors of elements specific to the intersection of sets found in the concatenated set names.
The `Dict` storing the intersection-specific elements may be converted to a dataframe using the `to_dataframe` function..

## Example
```julia-repl
julia> using UpSetPlot
julia> using DataFrames
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
julia> fig1, lists1 = upset_plot(df1; set_names=set_names, fig_size=(500, 500), intersection_lists=true);
julia> fig2, lists2 = upset_plot(df2; fig_size=(500, 500), intersection_lists=true);
julia> lists_1 == lists_2
true
julia> lists1["Set1"] == ["ID06", "ID08", "ID09", "ID10"]
true
julia> lists2["Set1_Set2_Set6"] == ["ID04", "ID05"]
true

julia> to_dataframe(lists1)
```
![IMAGE](https://github.com/ljournot/UpSetPlot.jl/blob/main/to_dataframe.png)

```julia-repl
julia> display(fig1)
```
![IMAGE](https://github.com/ljournot/UpSetPlot.jl/blob/main/fig1.png)