using UpSetPlot
using DataFrames
using Test

set_names = ["Set1", "Set2", "Set3", "Set4", "Set5", "Set6"]
df1 = DataFrame(
    Set1 = ["ID01", "ID02", "ID03", "ID07", "ID08", "ID09", "ID10", "ID04", "ID05", "ID06"],
    Set2 = ["ID01", "ID02", "ID03", "ID04", "ID05", "ID11", "ID12", "ID13", "ID14", "ID15"],
    Set3 = ["ID01", "ID02", "ID03", "ID07", "ID13", missing, missing, missing, missing, missing],
    Set4 = ["ID16", "ID17", "ID18", "ID19", "ID14", "ID02", "ID03", missing, missing, missing],
    Set5 = fill(missing, 10),
    Set6 = ["ID01", "ID02", "ID03", "ID04", "ID05", "ID11", "ID12", "ID13", "ID16", missing],
    Col_x = ["x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10"]
)
df2 = DataFrame(
    id = ["ID01", "ID02", "ID03", "ID04", "ID05", "ID06", "ID07", "ID08", "ID09", "ID10", "ID11", "ID12", "ID13", "ID14", "ID15", "ID16", "ID17", "ID18", "ID19"],
    Set1 = [true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false],
    Set2 = [true, true, true, true, true, false, false, false, false, false, true, true, true, true, true, false, false, false, false],
    Set3 = [true, true, true, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false, false],
    Set4 = [false, true, true, false, false, false, false, false, false, false, false, false, false, true, false, true, true, true, true],
    Set5 = fill(false, 19),
    Set6 = [true, true, true, true, true, false, false, false, false, false, true, true, true, false, false, true, false, false, false]
)

@testset "UpSetPlot.jl" begin
    fig1, lists1 = upset_plot(df1; set_names=set_names, fig_size=(500, 500), intersection_lists=true)
    fig2, lists2 = upset_plot(df2; fig_size=(500, 500), intersection_lists=true)

    @test lists1 == lists2
    @test lists1["Set1"] == ["ID06", "ID08", "ID09", "ID10"]
    @test lists2["Set1_Set2_Set6"] == ["ID04", "ID05"]

    df_out = to_dataframe(lists1)
    @test df_out == DataFrame(
        Set1 = ["ID06", "ID08", "ID09", "ID10"],
        Set4 = ["ID17", "ID18", "ID19", missing],
        Set1_Set2_Set3_Set4_Set6 = ["ID02", "ID03", missing, missing],
        Set1_Set2_Set6 = ["ID04", "ID05", missing, missing],
        Set2_Set6 = ["ID11", "ID12", missing, missing   ],
        Set1_Set3 = ["ID07", missing, missing, missing],
        Set2_Set4 = ["ID14", missing, missing, missing],
        Set4_Set6 = ["ID16", missing, missing, missing],
        Set2 = ["ID15", missing, missing, missing],
        Set2_Set3_Set6 = ["ID13", missing, missing, missing],
        Set1_Set2_Set3_Set6 = ["ID01", missing, missing, missing]
    )
end
